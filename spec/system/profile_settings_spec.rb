# frozen_string_literal: true

RSpec.describe 'Profile Settings' do
  let(:user) { create(:user, account: create(:account), title: 'Engineer', company: 'Example Corporation') }

  before do
    sign_in(user)
    visit settings_profile_index_path
  end

  it 'shows Entra-managed identity and no local password controls' do
    expect(page).to have_content('Profile')
    expect(page).to have_field('user[email]', with: user.email, disabled: true)
    expect(page).to have_field('user[first_name]', with: user.first_name, disabled: true)
    expect(page).to have_field('user[last_name]', with: user.last_name, disabled: true)
    expect(page).to have_no_field('user[title]')
    expect(page).to have_no_field('user[company]')
    expect(page).to have_content('Managed by Microsoft Entra ID')
    expect(page).to have_no_button('Update')
    expect(page).to have_no_content('Change Password')
    expect(page).to have_no_field('user[password]')
  end

  it 'shows a reconnect action when Microsoft authorization is invalid' do
    EncryptedUserConfig.create!(
      user:,
      key: Microsoft365::TokenStore::KEY,
      value: { 'reauthorization_required_at' => Time.current.iso8601 }
    )

    visit settings_profile_index_path

    expect(page).to have_link('Reconnect Microsoft 365',
                              href: microsoft_auth_path(return_to: settings_profile_index_path))
  end

  it 'creates a typed signature from the user name' do
    click_link 'Update Signature'
    find('label', text: 'Type', exact_text: true).click

    expect(page).to have_field('Type your signature', with: user.full_name)
    expect(page).to have_css('[aria-label="Typed signature preview"]', text: user.full_name)

    fill_in 'Type your signature', with: 'Example User'
    expect(page).to have_css('[aria-label="Typed signature preview"]', text: 'Example User')

    click_button 'Save'

    expect(page).to have_content('Signature has been saved')
    expect(UserConfigs.load_signature(user.reload)).to be_present
  end

  it 'creates typed initials derived from the user name' do
    click_link 'Update Initials'
    find('label', text: 'Type', exact_text: true).click

    expect(page).to have_field('Type your initials', with: user.initials)
    expect(page).to have_css('[aria-label="Typed initials preview"]', text: user.initials)

    fill_in 'Type your initials', with: 'AA'
    click_button 'Save'

    expect(page).to have_content('Initials have been saved')
    expect(UserConfigs.load_initials(user.reload)).to be_present
  end
end
