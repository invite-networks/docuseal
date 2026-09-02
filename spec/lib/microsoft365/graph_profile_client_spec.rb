# frozen_string_literal: true

RSpec.describe Microsoft365::GraphProfileClient do
  let(:endpoint) { 'https://graph.microsoft.com/v1.0/me' }

  before do
    allow(Microsoft365::Config).to receive(:profile_endpoint).and_return(endpoint)
  end

  it 'loads the Microsoft-managed user profile fields' do
    profile = {
      'givenName' => 'Example',
      'surname' => 'User',
      'mail' => 'user@example.com',
      'userPrincipalName' => 'user@example.com',
      'jobTitle' => 'Engineer',
      'companyName' => 'Example Corporation'
    }
    request = stub_request(:get, endpoint)
              .with(
                query: { '$select' => described_class::PROFILE_FIELDS.join(',') },
                headers: { 'Authorization' => 'Bearer access-token' }
              )
              .to_return(status: 200, body: profile.to_json)

    expect(described_class.fetch('access-token')).to eq(profile)
    expect(request).to have_been_requested.once
  end

  it 'raises an authentication error when Microsoft Graph rejects the request' do
    stub_request(:get, endpoint)
      .with(query: { '$select' => described_class::PROFILE_FIELDS.join(',') })
      .to_return(status: 403, body: { error: { message: 'Insufficient privileges.' } }.to_json)

    expect { described_class.fetch('access-token') }
      .to raise_error(Microsoft365::AuthenticationError, /Insufficient privileges/)
  end
end
