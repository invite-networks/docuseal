# frozen_string_literal: true

RSpec.describe 'Personalization favicons' do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account:) }

  before do
    sign_in(user)
  end

  it 'uploads an image as the account favicon and serves it in the page head' do
    file = fixture_file_upload(Rails.root.join('spec/fixtures/sample-image.png'), 'image/png')

    post settings_personalization_favicon_path, params: { favicon: file }

    expect(response).to redirect_to(settings_personalization_path)
    expect(account.reload.favicon).to be_attached
    expect(account.favicon.content_type).to eq('image/png')

    get settings_personalization_path

    favicon_path = ActiveStorage::Blob.proxy_path(account.favicon.blob)

    expect(response.body).to include(%(<link rel="icon" type="image/png" href="#{favicon_path}">))
    expect(response.body).not_to include('/favicon-32x32.png')
  end

  it 'rejects files that are not supported images' do
    file = fixture_file_upload(Rails.root.join('spec/fixtures/sample-document.pdf'), 'application/pdf')

    post settings_personalization_favicon_path, params: { favicon: file }

    expect(response).to redirect_to(settings_personalization_path)
    expect(flash[:alert]).to eq('Favicon must be a PNG, ICO, or SVG image up to 1 MB.')
    expect(account.reload.favicon).not_to be_attached
  end

  it 'prevents standard users from changing the favicon' do
    user.update!(role: User::USER_ROLE)
    file = fixture_file_upload(Rails.root.join('spec/fixtures/sample-image.png'), 'image/png')

    post settings_personalization_favicon_path, params: { favicon: file }

    expect(response).to redirect_to(root_path)
    expect(account.reload.favicon).not_to be_attached
  end

  it 'removes the account favicon and restores the default icons' do
    account.favicon.attach(
      io: Rails.root.join('spec/fixtures/sample-image.png').open,
      filename: 'favicon.png',
      content_type: 'image/png'
    )

    delete settings_personalization_favicon_path

    expect(response).to redirect_to(settings_personalization_path)
    expect(account.reload.favicon).not_to be_attached

    get settings_personalization_path

    expect(response.body).to include('/favicon-32x32.png')
  end
end
