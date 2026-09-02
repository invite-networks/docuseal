# frozen_string_literal: true

RSpec.describe 'Role access' do
  let(:account) { create(:account) }

  context 'when signed in as a standard user' do
    let(:current_user) { create(:user, account:, role: User::USER_ROLE) }

    before do
      sign_in(current_user)
    end

    it 'shows profile settings without account administration' do
      visit settings_path

      expect(page).to have_link('Profile', href: settings_profile_index_path)
      expect(page).to have_no_link('Account', href: settings_account_path)
      expect(page).to have_no_link('Users', href: settings_users_path)
    end

    it 'blocks the team administration page' do
      visit settings_users_path

      expect(page).to have_current_path(root_path)
    end
  end

  context 'when signed in as an auditor' do
    let(:current_user) { create(:user, account:, role: User::AUDITOR_ROLE) }

    before do
      sign_in(current_user)
    end

    it 'shows profile settings without account administration' do
      visit settings_path

      expect(page).to have_link('Profile', href: settings_profile_index_path)
      expect(page).to have_no_link('Account', href: settings_account_path)
      expect(page).to have_no_link('Users', href: settings_users_path)
      expect(page).to have_no_link('API', href: settings_api_index_path)
    end

    it 'blocks the team administration page' do
      visit settings_users_path

      expect(page).to have_current_path(root_path)
    end
  end
end
