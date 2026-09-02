# frozen_string_literal: true

RSpec.describe 'Microsoft authentication' do
  let!(:user) { create(:user, email: 'user@example.com') }

  before do
    allow(Microsoft365::Config).to receive_messages(
      configured?: true,
      tenant_id: 'tenant-id',
      client_id: 'client-id',
      client_secret: 'client-secret',
      authorization_endpoint: 'https://login.microsoftonline.com/tenant-id/oauth2/v2.0/authorize',
      scopes: 'openid profile email offline_access User.Read Mail.Send'
    )
  end

  it 'starts an authorization code flow with PKCE' do
    get microsoft_auth_path

    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query)

    expect(uri.host).to eq('login.microsoftonline.com')
    expect(query).to include(
      'client_id' => 'client-id',
      'response_type' => 'code',
      'response_mode' => 'query',
      'code_challenge_method' => 'S256'
    )
    expect(query['scope']).to include('Mail.Send', 'User.Read', 'offline_access')
    expect(query['state']).to be_present
    expect(query['nonce']).to be_present
    expect(query['code_challenge']).to be_present
  end

  it 'supports explicit Microsoft verification for sensitive actions' do
    get microsoft_auth_path(prompt: 'login', return_to: settings_api_index_path)

    query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)

    expect(query['prompt']).to eq('login')
  end

  it 'redirects local password sign-in attempts to Microsoft' do
    post user_session_path, params: { user: { email: user.email, password: 'password' } }

    expect(response).to redirect_to(microsoft_auth_path)
  end

  it 'signs in and stores delegated tokens after a valid callback' do
    get microsoft_auth_path(return_to: settings_profile_index_path)
    query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)

    token_response = {
      'access_token' => 'access-token',
      'refresh_token' => 'refresh-token',
      'id_token' => 'id-token',
      'expires_in' => 3600
    }
    claims = { 'tid' => 'tenant-id', 'oid' => 'object-id', 'email' => user.email }
    profile = {
      'mail' => user.email,
      'jobTitle' => 'Engineer',
      'companyName' => 'Example Corporation'
    }

    allow(Microsoft365::OauthClient).to receive(:exchange_code).and_return(token_response)
    allow(Microsoft365::IdTokenValidator).to receive(:call).and_return(claims)
    allow(Microsoft365::GraphProfileClient).to receive(:fetch).with('access-token').and_return(profile)
    allow(Microsoft365::UserLinker).to receive(:call).with(claims, profile:).and_return(user)
    allow(Microsoft365::TokenStore).to receive(:save!).with(user, token_response)

    get microsoft_auth_callback_path(code: 'authorization-code', state: query.fetch('state'))

    expect(response).to redirect_to(settings_profile_index_path)
    expect(controller.current_user).to eq(user)

    get settings_reveal_access_token_path, headers: { 'Turbo-Frame' => 'modal' }

    expect(response.body).to include(user.access_token.token)
  end

  it 'rejects a callback with the wrong state' do
    get microsoft_auth_path

    get microsoft_auth_callback_path(code: 'authorization-code', state: 'invalid')

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to eq('Microsoft sign-in state is invalid.')
  end
end
