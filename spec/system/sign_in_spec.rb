# frozen_string_literal: true

RSpec.describe 'Sign In' do
  before do
    create(:user)

    allow(Microsoft365::Config).to receive_messages(
      configured?: true,
      tenant_id: 'tenant-id',
      client_id: 'client-id',
      client_secret: 'client-secret'
    )

    visit new_user_session_path
  end

  it 'only offers Microsoft sign-in' do
    expect(page).to have_link('Sign in with Microsoft')
    expect(page).to have_no_field('Email')
    expect(page).to have_no_field('Password')
  end
end
