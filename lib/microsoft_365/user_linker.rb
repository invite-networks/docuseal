# frozen_string_literal: true

module Microsoft365
  class UserLinker
    class << self
      def call(claims, profile: {})
        tenant_id = claims.fetch('tid')
        object_id = claims.fetch('oid')
        email = extract_email(claims, profile)

        User.transaction do
          user = User.lock.find_by(microsoft_tenant_id: tenant_id, microsoft_object_id: object_id)
          user ||= find_existing_user(email)
          user ||= build_user(email, claims, profile)

          if user.microsoft_object_id.present? &&
             [user.microsoft_tenant_id, user.microsoft_object_id] != [tenant_id, object_id]
            raise AuthenticationError, 'This DocuSeal user is already linked to another Microsoft account.'
          end

          user.assign_attributes(
            microsoft_tenant_id: tenant_id,
            microsoft_object_id: object_id,
            email:,
            first_name: profile['givenName'].presence || claims['given_name'].presence || user.first_name,
            last_name: profile['surname'].presence || claims['family_name'].presence || user.last_name,
            title: profile.key?('jobTitle') ? profile['jobTitle'].presence : user.title,
            company: profile.key?('companyName') ? profile['companyName'].presence : user.company,
            role: role_from_claims(claims)
          )
          user.archived_at = nil
          user.save!
          user
        end
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      private

      def extract_email(claims, profile)
        email = profile['mail'].presence || profile['userPrincipalName'].presence ||
                claims['email'].presence || claims['preferred_username'].presence
        email = email.to_s.downcase.strip

        unless email.match?(User::FULL_EMAIL_REGEXP)
          raise AuthenticationError, 'Microsoft did not provide a valid email address.'
        end

        email
      end

      def find_existing_user(email)
        User.lock.find_by('LOWER(email) = ?', email)
      end

      def build_user(email, claims, profile)
        account = Account.active.order(:id).first
        unless account
          raise AuthenticationError, 'Complete the initial application setup before signing in with Microsoft.'
        end

        account.users.new(
          email:,
          first_name: profile['givenName'].presence || claims['given_name'].presence || claims['name'].to_s.split.first,
          last_name: profile['surname'].presence || claims['family_name'].presence ||
                     claims['name'].to_s.split.drop(1).join(' ').presence,
          title: profile['jobTitle'].presence,
          company: profile['companyName'].presence,
          password: SecureRandom.base64(48),
          role: role_from_claims(claims)
        )
      end

      def role_from_claims(claims)
        assigned_roles = Array.wrap(claims['roles']).map { |role| role.to_s.downcase }

        [User::ADMIN_ROLE, User::AUDITOR_ROLE, User::USER_ROLE]
          .find { |role| assigned_roles.include?(role) } || User::USER_ROLE
      end
    end
  end
end
