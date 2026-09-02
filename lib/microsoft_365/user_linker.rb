# frozen_string_literal: true

module Microsoft365
  class UserLinker
    class << self
      def call(claims, profile: {})
        tenant_id = claims.fetch('tid')
        object_id = claims.fetch('oid')
        email = extract_email(claims, profile)

        User.transaction do
          # Identity is matched on the immutable Entra object id only. Email
          # addresses can be reassigned to a different person, so they are never
          # used to attach a login to an existing local account.
          user = User.lock.find_by(microsoft_tenant_id: tenant_id, microsoft_object_id: object_id)
          user ||= build_user(email, claims, profile)

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
        ensure_email_available!(email, tenant_id, object_id)

        raise if (retries = (retries || 0) + 1) > 1

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

      def ensure_email_available!(email, tenant_id, object_id)
        # COALESCE keeps unlinked users (NULL identity columns) in the match.
        other = User.where('LOWER(email) = ?', email)
                    .where("COALESCE(microsoft_tenant_id, '') <> ? OR COALESCE(microsoft_object_id, '') <> ?",
                           tenant_id, object_id)

        return unless other.exists?

        raise AuthenticationError,
              'A DocuSeal user with this email address is already linked to a different Microsoft account.'
      end

      def build_user(email, claims, profile)
        ensure_email_available!(email, claims.fetch('tid'), claims.fetch('oid'))

        target_account.users.new(
          email:,
          first_name: profile['givenName'].presence || claims['given_name'].presence || claims['name'].to_s.split.first,
          last_name: profile['surname'].presence || claims['family_name'].presence ||
                     claims['name'].to_s.split.drop(1).join(' ').presence,
          title: profile['jobTitle'].presence,
          company: profile['companyName'].presence,
          role: role_from_claims(claims)
        )
      end

      # This deployment is single-tenant: exactly one primary account may exist.
      # Linked testing accounts are excluded. Anything else is a misconfiguration
      # and provisioning stops instead of guessing by row order.
      def target_account
        accounts = Account.active.where.missing(:linked_account_account).limit(2).to_a

        if accounts.empty?
          raise AuthenticationError, 'Complete the initial application setup before signing in with Microsoft.'
        end

        if accounts.size > 1
          raise AuthenticationError,
                'More than one active account exists. Contact an administrator to complete sign-in.'
        end

        accounts.first
      end

      def role_from_claims(claims)
        assigned_roles = Array.wrap(claims['roles']).map { |role| role.to_s.downcase }

        [User::ADMIN_ROLE, User::AUDITOR_ROLE, User::USER_ROLE]
          .find { |role| assigned_roles.include?(role) } || User::USER_ROLE
      end
    end
  end
end
