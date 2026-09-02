# frozen_string_literal: true

RSpec.describe Microsoft365::TokenStore do
  let(:user) { create(:user) }

  it 'stores and returns a fresh delegated access token' do
    described_class.save!(user, token_response)

    expect(described_class.access_token_for(user)).to eq('access-token')

    config = user.encrypted_configs.find_by!(key: described_class::KEY)
    expect(config.value).to include('refresh_token' => 'refresh-token', 'access_token' => 'access-token')
  end

  it 'rotates a refresh token when the access token expires' do
    described_class.save!(user, token_response.merge('expires_in' => 0))
    allow(Microsoft365::OauthClient).to receive(:refresh).with('refresh-token').and_return(
      token_response.merge('access_token' => 'new-access-token', 'refresh_token' => 'new-refresh-token')
    )

    expect(described_class.access_token_for(user)).to eq('new-access-token')
    expect(user.encrypted_configs.find_by!(key: described_class::KEY).value['refresh_token']).to eq('new-refresh-token')
  end

  it 'marks the connection for reauthorization when refresh fails' do
    described_class.save!(user, token_response.merge('expires_in' => 0))
    allow(Microsoft365::OauthClient).to receive(:refresh)
      .and_raise(Microsoft365::AuthenticationError, 'refresh revoked')

    expect { described_class.access_token_for(user) }
      .to raise_error(Microsoft365::ReauthorizationRequired)
    expect(described_class.reauthorization_required?(user)).to be(true)
  end

  def token_response
    {
      'access_token' => 'access-token',
      'refresh_token' => 'refresh-token',
      'expires_in' => 3600,
      'scope' => Microsoft365::Config.scopes,
      'token_type' => 'Bearer'
    }
  end
end
