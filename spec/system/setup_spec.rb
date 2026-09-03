# frozen_string_literal: true

RSpec.describe 'App Setup' do
  let(:form_data) do
    {
      company_name: 'Example Company',
      app_url: 'https://example.com'
    }
  end

  before do
    visit setup_index_path
  end

  it 'shows the setup page' do
    expect(page).to have_content('Initial Setup')

    ['Company name', 'App URL'].each do |field|
      expect(page).to have_field(field)
    end

    expect(page).to have_no_field('First name')
    expect(page).to have_no_field('Last name')
    expect(page).to have_no_field('Email')
  end

  context 'when valid information' do
    it 'setups the app' do
      fill_setup_form(form_data)

      expect do
        click_button 'Submit'
        page.driver.wait_for_network_idle
      end.to change(Account, :count).by(1).and change(EncryptedConfig, :count).by(2)

      expect(User.count).to eq(0)

      account = Account.last
      encrypted_config_app_url = EncryptedConfig.find_by(account:,
                                                         key: EncryptedConfig::APP_URL_KEY)
      encrypted_config_esign_certs = EncryptedConfig.find_by(account:,
                                                             key: EncryptedConfig::ESIGN_CERTS_KEY)

      expect(account.timezone).to eq('UTC')
      expect(account.locale).to eq('en-US')
      expect(account.name).to eq(form_data[:company_name])
      expect(encrypted_config_app_url.value).to eq(form_data[:app_url])
      expect(encrypted_config_esign_certs.value).to be_present
    end
  end

  context 'when invalid information' do
    it 'does not setup the app if the URL is invalid' do
      fill_setup_form(form_data.merge(app_url: 'not-a-url'))

      expect do
        click_button 'Submit'
      end.not_to(change(Account, :count))

      expect(page).to have_content('should be a valid URL')
    end
  end

  context 'when the app is already setup' do
    let!(:user) { create(:user, account: create(:account)) }

    it 'redirects to the dashboard page' do
      sign_in(user)
      visit setup_index_path

      expect(page).to have_link('Create', href: new_template_path)
    end
  end

  context 'when the account exists but no user has signed in' do
    let(:account) { create(:account) }

    it 'redirects setup to Microsoft sign-in' do
      account
      visit setup_index_path

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_link('Sign in with Microsoft', href: microsoft_auth_path)
    end
  end

  private

  def fill_setup_form(form_data)
    fill_in 'Company name', with: form_data[:company_name]
    fill_in 'App URL', with: form_data[:app_url]
  end
end
