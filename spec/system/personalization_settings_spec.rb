# frozen_string_literal: true

RSpec.describe 'Personalization Settings', :js do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account:) }

  before do
    sign_in(user)
    visit settings_personalization_path
  end

  it 'shows the notifications settings page' do
    expect(page).to have_content('Email Templates')
    expect(page).to have_content('Company Logo')
    expect(page).to have_content('Submission Form')
    expect(page).to have_button('Upload Logo')
    expect(page).to have_content('Favicon')
    expect(page).to have_button('Upload Favicon')
    expect(page).to have_no_content('Disabled')
  end

  it 'uploads and removes a company logo' do
    attach_file 'logo', Rails.root.join('spec/fixtures/sample-image.png')
    click_button 'Upload Logo'

    expect(page).to have_content('Logo has been uploaded')
    expect(page).to have_css("img[alt='#{account.name}']")
    expect(account.reload.logo).to be_attached

    accept_confirm do
      click_link 'Remove'
    end

    expect(page).to have_content('Company logo has been removed')
    expect(account.reload.logo).not_to be_attached
  end

  it 'uploads and removes a favicon' do
    attach_file 'favicon', Rails.root.join('spec/fixtures/sample-image.png')
    click_button 'Upload Favicon'

    expect(page).to have_content('Favicon has been uploaded')
    expect(account.reload.favicon).to be_attached
    expect(page).to have_css(%(link[rel="icon"][href="#{ActiveStorage::Blob.proxy_path(account.favicon.blob)}"]),
                             visible: :all)

    accept_confirm do
      click_link 'Remove', href: settings_personalization_favicon_path
    end

    expect(page).to have_content('Favicon has been removed')
    expect(page).to have_css('link[rel="icon"][href="/favicon.svg"]', visible: :all)
    expect(account.reload.favicon).not_to be_attached
  end
end
