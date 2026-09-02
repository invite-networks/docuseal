# frozen_string_literal: true

RSpec.describe 'API Settings' do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account:) }

  before do
    sign_in(user)
    visit settings_api_index_path
  end

  it 'shows verify signed PDF page' do
    expect(page).to have_content('API')
    token = user.access_token.token
    expect(page).to have_field('X-Auth-Token', with: token.sub(token[5..], '*' * token[5..].size))
  end

  it 'uses Microsoft verification instead of a local password' do
    find('#api_key').click

    within('.modal') do
      expect(page).to have_link('Continue with Microsoft')
      expect(page).to have_no_field('Password')
    end
  end
end
