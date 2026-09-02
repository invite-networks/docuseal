# frozen_string_literal: true

class TemplateMailer < ApplicationMailer
  def otp_verification_email(template, email:)
    @current_account = template.account
    @template = template

    @otp_code = EmailVerificationCodes.generate([email.downcase.strip, template.slug].join(':'))

    assign_message_metadata('otp_verification_email', template)
    put_metadata('from_user_id' => template.author_id)

    mail(from: template.author.friendly_name, to: email, subject: I18n.t('email_verification'))
  end
end
