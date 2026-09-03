# frozen_string_literal: true

RSpec.describe SubmitterMailer do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, template:, created_by_user: user) }
  let(:submitter) do
    create(:submitter, submission:, uuid: template.submitters.first['uuid'], completed_at: Time.current)
  end

  before do
    create(:encrypted_config, key: EncryptedConfig::ESIGN_CERTS_KEY,
                              value: GenerateCertificate.call.transform_values(&:to_pem))

    submitter
    Submissions.maybe_update_completed_at(submission)
    Submissions::EnsureResultGenerated.call(submitter)
    Submissions::EnsureAuditGenerated.call(submission.reload)
    submitter.reload
  end

  describe '#completed_email' do
    it 'attaches the signed document and audit log' do
      mail = described_class.completed_email(submitter, user)

      expect(mail.attachments.map(&:content_type)).to all(start_with('application/pdf'))
      expect(mail.attachments.size).to eq(2)
    end

    it 'skips attachments when the template disables them' do
      template.update!(preferences: { 'completed_notification_email_attach_documents' => false,
                                      'completed_notification_email_attach_audit' => false })

      mail = described_class.completed_email(submitter, user)

      expect(mail.attachments).to be_empty
    end
  end

  describe '#documents_copy_email' do
    it 'attaches the signed document and audit log' do
      mail = described_class.documents_copy_email(submitter, sig: true)

      expect(mail.attachments.size).to eq(2)
      expect(mail.attachments.map(&:filename)).to all(end_with('.pdf'))
    end
  end
end
