# frozen_string_literal: true

RSpec.describe Microsoft365::IdTokenValidator do
  let(:private_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:jwk) { JWT::JWK.new(private_key, kid: 'signing-key') }
  let(:nonce) { 'expected-nonce' }
  let(:claims) do
    {
      'aud' => 'client-id',
      'iss' => 'https://login.microsoftonline.com/tenant-id/v2.0',
      'tid' => 'tenant-id',
      'oid' => 'object-id',
      'nonce' => nonce,
      'email' => 'user@example.com',
      'iat' => Time.current.to_i,
      'exp' => 1.hour.from_now.to_i
    }
  end

  before do
    allow(Microsoft365::Config).to receive_messages(
      ensure_configured!: true,
      tenant_id: 'tenant-id',
      client_id: 'client-id',
      issuer: 'https://login.microsoftonline.com/tenant-id/v2.0',
      jwks_uri: 'https://login.microsoftonline.com/tenant-id/discovery/v2.0/keys'
    )
    stub_request(:get, Microsoft365::Config.jwks_uri)
      .to_return(status: 200, body: { keys: [jwk.export] }.to_json)
  end

  it 'validates the signature, audience, issuer, tenant, expiration, and nonce' do
    result = described_class.call(encoded_token, nonce:)

    expect(result).to include('tid' => 'tenant-id', 'oid' => 'object-id')
  end

  it 'rejects a token with the wrong nonce' do
    expect { described_class.call(encoded_token, nonce: 'different') }
      .to raise_error(Microsoft365::AuthenticationError, /nonce is invalid/)
  end

  def encoded_token
    JWT.encode(claims, private_key, 'RS256', kid: 'signing-key')
  end
end
