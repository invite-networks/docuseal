# frozen_string_literal: true

class SendSubmitterInvitationEmailJob
  include Sidekiq::Job

  def perform(params = {})
    submitter = Submitter.find(params['submitter_id'])
    delivery_uuid = params['delivery_uuid'].presence || jid

    return if skip_delivery?(submitter, delivery_uuid)

    unless Accounts.can_send_invitation_emails?(submitter.account)
      Rollbar.warning("Skip email: #{submitter.account.id}") if defined?(Rollbar)

      return
    end

    mail =
      if submitter.viewer?
        SubmitterMailer.invitation_view_email(submitter)
      else
        SubmitterMailer.invitation_email(submitter)
      end

    mail.message['X-Message-Uuid'].value = delivery_uuid if delivery_uuid.present?

    Submitters::ValidateSending.call(submitter, mail)

    mail.deliver_now!

    SubmissionEvent.create!(submitter:, event_type: 'send_email')

    submitter.sent_at ||= Time.current
    submitter.save!
  end

  private

  def skip_delivery?(submitter, delivery_uuid)
    unavailable = [
      submitter.completed_at?,
      submitter.declined_at?,
      submitter.submission.archived_at?,
      submitter.submission.expired?,
      submitter.template&.archived_at?
    ]

    return true if unavailable.any?
    return true if submitter.submission.source == 'invite' &&
                   !Accounts.can_send_emails?(submitter.account, on_events: true)

    delivery_recorded?(submitter, delivery_uuid)
  end

  def delivery_recorded?(submitter, delivery_uuid)
    return false if delivery_uuid.blank?

    EmailEvent.exists?(emailable: submitter, event_type: :send, message_id: delivery_uuid)
  end
end
