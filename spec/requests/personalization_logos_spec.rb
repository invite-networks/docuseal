# frozen_string_literal: true

RSpec.describe 'Personalization logos' do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account:) }

  before do
    sign_in(user)
  end

  it 'uploads an image as the account logo' do
    file = fixture_file_upload(Rails.root.join('spec/fixtures/sample-image.png'), 'image/png')

    post settings_personalization_logo_path, params: { logo: file }

    expect(response).to redirect_to(settings_personalization_path)
    expect(account.reload.logo).to be_attached
    expect(account.logo.content_type).to eq('image/png')
  end

  it 'rejects files that are not supported images' do
    file = fixture_file_upload(Rails.root.join('spec/fixtures/sample-document.pdf'), 'application/pdf')

    post settings_personalization_logo_path, params: { logo: file }

    expect(response).to redirect_to(settings_personalization_path)
    expect(flash[:alert]).to eq('Logo must be a PNG, JPEG, or WebP image up to 2 MB.')
    expect(account.reload.logo).not_to be_attached
  end

  it 'prevents standard users from changing the logo' do
    user.update!(role: User::USER_ROLE)
    file = fixture_file_upload(Rails.root.join('spec/fixtures/sample-image.png'), 'image/png')

    post settings_personalization_logo_path, params: { logo: file }

    expect(response).to redirect_to(root_path)
    expect(account.reload.logo).not_to be_attached
  end

  it 'removes the account logo' do
    account.logo.attach(
      io: Rails.root.join('spec/fixtures/sample-image.png').open,
      filename: 'logo.png',
      content_type: 'image/png'
    )

    delete settings_personalization_logo_path

    expect(response).to redirect_to(settings_personalization_path)
    expect(account.reload.logo).not_to be_attached
  end
end
