# frozen_string_literal: true

RSpec.describe SendSubmitterInvitationEmailJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, account:, template:, created_by_user: user) }
  let(:submitter) { create(:submitter, submission:, uuid: template.submitters.first.fetch('uuid')) }
  let(:delivery_uuid) { SecureRandom.uuid }

  before do
    allow(Accounts).to receive_messages(can_send_emails?: true, can_send_invitation_emails?: true)
  end

  it 'uses a stable message ID for retry-safe delivery' do
    described_class.new.perform('submitter_id' => submitter.id, 'delivery_uuid' => delivery_uuid)

    expect(ActionMailer::Base.deliveries.last['X-Message-Uuid'].value).to eq(delivery_uuid)
    expect(submitter.reload.sent_at).to be_present
  end

  it 'does not resend a delivery already accepted by the mail provider' do
    create(:email_event,
           account: submitter.account,
           emailable: submitter,
           event_type: 'send',
           message_id: delivery_uuid)

    expect do
      described_class.new.perform('submitter_id' => submitter.id, 'delivery_uuid' => delivery_uuid)
    end.not_to change(ActionMailer::Base.deliveries, :count)
  end
end
