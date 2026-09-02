# frozen_string_literal: true

RSpec.describe 'User role management' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account:, role: User::ADMIN_ROLE) }
  let(:user) { create(:user, account:, role: User::USER_ROLE) }

  it 'allows admins to view account users' do
    sign_in(admin)

    get settings_users_path

    expect(response).to have_http_status(:ok)
  end

  it 'blocks standard users from account user administration' do
    sign_in(user)

    get settings_users_path

    expect(response).to redirect_to(root_path)
  end

  it 'ignores role changes submitted through the local user form' do
    sign_in(admin)

    patch user_path(user), params: { user: { first_name: 'Updated', role: User::AUDITOR_ROLE } }

    expect(user.reload).to have_attributes(first_name: 'Updated', role: User::USER_ROLE)
  end
end
