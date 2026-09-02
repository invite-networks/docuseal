# frozen_string_literal: true

RSpec.describe 'API authentication' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }

  it 'authenticates with the X-Auth-Token header' do
    get '/api/templates', headers: { 'x-auth-token': author.access_token.token }

    expect(response).to have_http_status(:ok)
  end

  it 'rejects requests without a token even when a browser session exists' do
    sign_in(author)

    get '/api/templates'

    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not let a browser session perform state changes on the JSON API' do
    sign_in(author)

    expect do
      post '/api/submissions', params: { template_id: template.id, submitters: [{ email: 'a@example.com' }] }.to_json,
                               headers: { 'Content-Type' => 'text/plain' }
    end.not_to change(Submission, :count)

    expect(response).to have_http_status(:unauthorized)
  end
end
