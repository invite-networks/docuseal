# frozen_string_literal: true

RSpec.describe 'Team Settings' do
  let(:account) { create(:account) }
  let(:second_account) { create(:account) }
  let(:current_user) { create(:user, account:) }

  before do
    sign_in(current_user)
  end

  context 'when multiple users' do
    let!(:users) { create_list(:user, 2, account:) }
    let!(:other_user) { create(:user) }

    before do
      visit settings_users_path
    end

    it 'shows only active users' do
      within '.table' do
        users.each do |user|
          expect(page).to have_content(user.full_name)
          expect(page).to have_content(user.email)
          expect(page).to have_link('Edit', href: edit_user_path(user))
        end

        expect(page).to have_button('Remove')
        expect(page).to have_no_button('Unarchive')

        expect(page).to have_no_content(other_user.full_name)
        expect(page).to have_no_content(other_user.email)
      end
    end

    it 'delegates user provisioning to Microsoft Entra' do
      expect(page).to have_content('Access and roles are managed through the Microsoft Entra Enterprise Application.')
      expect(page).to have_no_link('New User')
    end

    it 'updates a user' do
      click_link 'Edit', href: edit_user_path(users.first)

      expect(page).to have_content('Managed by Microsoft Entra ID', count: 2)
      expect(page).to have_no_select('Role')

      fill_in 'First name', with: 'Example'
      fill_in 'Last name', with: 'Meier'
      expect do
        click_button 'Submit'
      end.not_to change(User, :count)

      user = users.first.reload

      expect(user.first_name).to eq('Example')
      expect(user.last_name).to eq('Meier')
    end

    it 'removes a user' do
      expect do
        accept_confirm('Are you sure?') do
          first(:button, 'Remove').click
        end
      end.to change { User.active.count }.by(-1)

      expect(page).to have_content('User has been removed')
    end
  end

  context 'when single user' do
    before do
      visit settings_users_path
    end

    it 'does not allow to remove the current user' do
      expect(page).to have_no_content('User has been removed')
    end
  end

  context 'when some users are archived' do
    let!(:users) { create_list(:user, 2, account:) }
    let!(:archived_users) { create_list(:user, 2, account:, archived_at: Time.current) }
    let!(:other_user) { create(:user) }

    it 'shows only active users' do
      visit settings_users_path

      within '.table' do
        users.each do |user|
          expect(page).to have_content(user.full_name)
          expect(page).to have_content(user.email)
        end

        archived_users.each do |user|
          expect(page).to have_no_content(user.full_name)
          expect(page).to have_no_content(user.email)
        end

        expect(page).to have_no_content(other_user.full_name)
        expect(page).to have_no_content(other_user.email)
      end

      expect(page).to have_link('View Archived', href: settings_archived_users_path)
    end

    it 'shows only archived users' do
      visit settings_archived_users_path

      within '.table' do
        archived_users.each do |user|
          expect(page).to have_content(user.full_name)
          expect(page).to have_content(user.email)
          expect(page).to have_no_link('Edit', href: edit_user_path(user))
        end

        users.each do |user|
          expect(page).to have_no_content(user.full_name)
          expect(page).to have_no_content(user.email)
          expect(page).to have_no_link('Edit', href: edit_user_path(user))
        end

        expect(page).to have_button('Unarchive')
        expect(page).to have_no_button('Remove')

        expect(page).to have_no_content(other_user.full_name)
        expect(page).to have_no_content(other_user.email)
      end

      expect(page).to have_content('Archived Users')
      expect(page).to have_link('View Active', href: settings_users_path)
    end
  end
end
