# frozen_string_literal: true

class SubmitterMailer < ApplicationMailer
  SIGN_TTL = 1.hour + 20.minutes

  NO_REPLY_REGEXP = /no-?reply@/i

  def invitation_email(submitter)
    @current_account = submitter.submission.account
    @submitter = submitter

    if submitter.preferences['email_message_uuid']
      @email_message = submitter.account.email_messages.find_by(uuid: submitter.preferences['email_message_uuid'])
    end

    template_submitters_index = @email_message.blank? ? build_submitter_preferences_index(@submitter) : {}

    @body = @email_message&.normalized_body.presence ||
            template_submitters_index.dig(@submitter.uuid, 'request_email_body').presence ||
            @submitter.template&.preferences&.dig('request_email_body').presence

    @subject = @email_message&.subject.presence ||
               template_submitters_index.dig(@submitter.uuid, 'request_email_subject').presence ||
               @submitter.template&.preferences&.dig('request_email_subject').presence

    @email_config = AccountConfigs.find_for_account(@current_account, AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY)
    @body ||= fetch_config_email_body(@email_config, @submitter)

    assign_message_metadata('submitter_invitation', @submitter)

    reply_to = build_submitter_reply_to(@submitter, email_config: @email_config)

    maybe_set_custom_domain(@submitter)

    I18n.with_locale(@current_account.locale) do
      subject = build_invite_subject(@subject, @email_config, submitter)

      mail(
        to: @submitter.friendly_name,
        from: from_address_for_submitter(submitter),
        subject:,
        reply_to:
      )
    end
  end

  def invitation_view_email(submitter)
    @current_account = submitter.submission.account
    @submitter = submitter

    if submitter.preferences['email_message_uuid']
      @email_message = submitter.account.email_messages.find_by(uuid: submitter.preferences['email_message_uuid'])
    end

    template_submitters_index = @email_message.blank? ? build_submitter_preferences_index(@submitter) : {}

    @body = @email_message&.normalized_body.presence ||
            @submitter.template&.preferences&.dig('invitation_view_email_body').presence ||
            template_submitters_index.dig(@submitter.uuid, 'request_email_body').presence

    @subject = @email_message&.subject.presence ||
               @submitter.template&.preferences&.dig('invitation_view_email_subject').presence ||
               template_submitters_index.dig(@submitter.uuid, 'request_email_subject').presence

    @email_config = AccountConfigs.find_for_account(@current_account, AccountConfig::SUBMITTER_VIEW_INVITATION_EMAIL_KEY)
    @body ||= fetch_config_email_body(@email_config, @submitter)

    assign_message_metadata('submitter_view_invitation', @submitter)

    reply_to = build_submitter_reply_to(@submitter, email_config: @email_config)

    maybe_set_custom_domain(@submitter)

    I18n.with_locale(@current_account.locale) do
      subject = build_invite_subject(@subject, @email_config, submitter)

      mail(
        to: @submitter.friendly_name,
        from: from_address_for_submitter(submitter),
        subject:,
        reply_to:
      )
    end
  end

  def completed_email(submitter, user, to: nil)
    @current_account = submitter.submission.account
    @submitter = submitter
    @submission = submitter.submission
    @user = user

    template_preferences = @submission.template&.preferences || {}

    @email_config = AccountConfigs.find_for_account(@current_account, AccountConfig::SUBMITTER_COMPLETED_EMAIL_KEY)

    @subject = template_preferences['completed_notification_email_subject'].presence
    @subject ||= @email_config.value['subject'] if @email_config

    @body = template_preferences['completed_notification_email_body'].presence
    @body ||= fetch_config_email_body(@email_config, @submitter)

    assign_message_metadata('submitter_completed', @submitter)

    I18n.with_locale(@current_account.locale) do
      subject =
        ReplaceEmailVariables.call(@subject.presence || I18n.t(:template_name_has_been_completed_by_submitters),
                                   submitter:)

      mail(from: from_address_for_submitter(submitter),
           to: to || normalize_user_email(user),
           subject:)
    end
  end

  def declined_email(submitter, user)
    @current_account = submitter.submission.account
    @submitter = submitter
    @submission = submitter.submission
    @user = user

    assign_message_metadata('submitter_declined', @submitter)

    I18n.with_locale(@current_account.locale) do
      mail(from: from_address_for_submitter(submitter),
           to: user.role == 'integration' ? user.friendly_name.sub(/\+\w+@/, '@') : user.friendly_name,
           reply_to: @submitter.friendly_name,
           subject: I18n.t(:name_declined_by_submitter,
                           name: (@submission.name || @submission.template&.name).to_s.truncate(20),
                           submitter: @submitter.name || @submitter.email || @submitter.phone))
    end
  end

  def documents_copy_email(submitter, to: nil, sig: false)
    @current_account = submitter.submission.account
    @submitter = submitter
    @sig = submitter.signed_id(expires_in: SIGN_TTL, purpose: :download_completed) if sig

    template_preferences = @submitter.template&.preferences || {}

    @email_config = AccountConfigs.find_for_account(@current_account, AccountConfig::SUBMITTER_DOCUMENTS_COPY_EMAIL_KEY)

    @subject = template_preferences['documents_copy_email_subject'].presence
    @subject ||= @email_config.value['subject'] if @email_config

    @body = template_preferences['documents_copy_email_body'].presence
    @body ||= fetch_config_email_body(@email_config, @submitter)

    assign_message_metadata('submitter_documents_copy', @submitter)
    reply_to = build_submitter_reply_to(submitter, email_config: @email_config, documents_copy_email: true)

    maybe_set_custom_domain(@submitter)

    I18n.with_locale(@current_account.locale) do
      subject =
        @subject.present? ? ReplaceEmailVariables.call(@subject, submitter:) : I18n.t(:your_document_copy)

      mail(from: from_address_for_submitter(submitter),
           to: to || @submitter.friendly_name,
           reply_to:,
           subject:)
    end
  end

  def otp_verification_email(submitter, locale: nil)
    @current_account = submitter.account
    @submitter = submitter
    @otp_code = EmailVerificationCodes.generate([submitter.email.downcase.strip, submitter.slug].join(':'))

    assign_message_metadata('otp_verification_email', submitter)
    from = from_address_for_submitter(submitter)

    I18n.with_locale(locale || submitter.account.locale) do
      mail(from:, to: submitter.email, subject: I18n.t('email_verification'))
    end
  end

  private

  def build_submitter_reply_to(submitter, email_config: nil, documents_copy_email: nil)
    reply_to = submitter.preferences['reply_to'].presence
    reply_to ||= submitter.template&.preferences&.dig('documents_copy_email_reply_to').presence if documents_copy_email
    reply_to ||= email_config.value['reply_to'].presence if email_config

    if reply_to.blank? && (submitter.submission.created_by_user || submitter.template.author)&.email != submitter.email
      reply_to = (submitter.submission.created_by_user || submitter.template.author)&.friendly_name&.sub(/\+\w+@/, '@')
    end

    return nil if reply_to.to_s.match?(NO_REPLY_REGEXP)

    reply_to
  end

  def normalize_user_email(user)
    user.role == 'integration' ? user.friendly_name.sub(/\+\w+@/, '@') : user.friendly_name
  end

  def build_invite_subject(subject, email_config, submitter)
    if email_config || subject
      ReplaceEmailVariables.call(subject || email_config.value['subject'], submitter:)
    elsif submitter.viewer?
      I18n.t(:you_are_invited_to_view_a_document)
    elsif submitter.with_signature_fields?
      I18n.t(:you_are_invited_to_sign_a_document)
    else
      I18n.t(:you_are_invited_to_submit_a_form)
    end
  end

  def build_submitter_preferences_index(submitter)
    submitter.template&.preferences&.dig('submitters').to_a.index_by { |e| e['uuid'] }
  end

  def from_address_for_submitter(submitter)
    user = submitter.submission.created_by_user || submitter.submission.template&.author
    raise Microsoft365::DeliveryError, 'Submission email does not have a Microsoft 365 sender.' unless user

    put_metadata('from_user_id' => user.id)
    user.friendly_name
  end

  def fetch_config_email_body(email_config, _submitter = nil)
    email_config ? email_config.value['body'].presence : nil
  end

  def maybe_set_custom_domain(submitter)
    if Docuseal.multitenant? && (config = AccountConfig.find_by(account_id: submitter.account_id, key: :custom_domain))
      @custom_domain = config.value
    end
  end
end
