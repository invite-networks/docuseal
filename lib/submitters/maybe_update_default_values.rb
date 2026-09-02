# frozen_string_literal: true

module Submitters
  module MaybeUpdateDefaultValues
    module_function

    def call(submitter, current_user)
      authenticated_user = current_user if current_user&.email&.casecmp?(submitter.email.to_s)
      profile_user = authenticated_user || find_profile_user(submitter)

      fields = submitter.submission.template_fields || submitter.submission.template.fields

      fields.each do |field|
        next if field['submitter_uuid'] != submitter.uuid

        default_value = get_default_value_for_field(field, profile_user, submitter, authenticated_user:)

        submitter.values[field['uuid']] ||= default_value if default_value.present?
      end

      submitter.save!
    end

    def get_default_value_for_field(field, user, submitter, authenticated_user: nil)
      return user&.full_name.presence || submitter.name.presence if field['type'] == 'name'
      return submitter.email.presence if field['type'] == 'email'
      return user&.title if field['type'] == 'title'
      return user&.company if field['type'] == 'company'
      return if authenticated_user.blank?

      field_name = field['name'].to_s.downcase

      if field_name.in?(['full name', 'legal name'])
        authenticated_user.full_name
      elsif field_name == 'first name'
        authenticated_user.first_name
      elsif field_name == 'last name'
        authenticated_user.last_name
      elsif field['type'] == 'initials' && (initials = UserConfigs.load_initials(authenticated_user))
        attachment = ActiveStorage::Attachment.find_or_create_by!(
          blob_id: initials.blob_id,
          name: 'attachments',
          record: submitter
        )

        attachment.uuid
      end
    end

    def find_profile_user(submitter)
      return if submitter.email.blank?

      User.active.find_by('account_id = ? AND LOWER(email) = ?', submitter.account_id, submitter.email.downcase)
    end
  end
end
