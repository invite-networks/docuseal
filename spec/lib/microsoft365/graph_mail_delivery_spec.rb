# frozen_string_literal: true

RSpec.describe Microsoft365::GraphMailDelivery do
  let(:user) { create(:user, email: 'user@example.com', first_name: 'Example', last_name: 'User') }
  let(:message) do
    Mail.new(
      to: 'signer@example.com',
      from: 'old@example.com',
      subject: 'Please sign',
      body: 'Open the secure signing link.'
    ).tap do |mail|
      mail.instance_variable_set(:@message_metadata, { 'from_user_id' => user.id })
    end
  end

  before do
    allow(Microsoft365::Config).to receive(:ensure_configured!)
    allow(Microsoft365::TokenStore).to receive(:access_token_for).with(user).and_return('access-token')
  end

  it 'sends MIME mail as the responsible user through Microsoft Graph' do
    request_body = nil
    request = stub_request(:post, Microsoft365::Config.send_mail_endpoint)
              .with(headers: { 'Authorization' => 'Bearer access-token', 'Content-Type' => 'text/plain' }) do |value|
                request_body = value.body
                true
              end
              .to_return(status: 202)

    result = described_class.new.deliver!(message)

    expect(result.from).to eq(['user@example.com'])
    expect(request).to have_been_requested

    encoded_body = Base64.decode64(request_body)
    expect(encoded_body).to include('Subject: Please sign', 'Open the secure signing link.')
    expect(Mail.read_from_string(encoded_body).to).to eq(['signer@example.com'])
  end

  it 'implements the Mail delivery method contract' do
    stub_request(:post, Microsoft365::Config.send_mail_endpoint).to_return(status: 202)
    message.delivery_method(described_class)

    expect { message.deliver }.not_to raise_error
  end

  it 'requires an active responsible user' do
    message.instance_variable_set(:@message_metadata, {})

    expect { described_class.new.deliver!(message) }
      .to raise_error(Microsoft365::DeliveryError, /active Microsoft 365 sender/)
  end
end
