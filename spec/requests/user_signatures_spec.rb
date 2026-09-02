# frozen_string_literal: true

RSpec.describe 'User signatures and initials' do
  let(:user) { create(:user, account: create(:account), first_name: 'Example', last_name: 'User') }

  before do
    sign_in(user)
  end

  it 'stores typed signatures as PNG attachments' do
    put user_signature_path, params: { text: 'Example User' }

    attachment = UserConfigs.load_signature(user.reload)

    expect(response).to redirect_to(settings_profile_index_path)
    expect(attachment).to be_present
    expect(attachment.blob).to have_attributes(filename: ActiveStorage::Filename.new('signature.png'),
                                               content_type: 'image/png')
    expect(Vips::Image.new_from_buffer(attachment.blob.download, '').width).to be_positive
  end

  it 'stores typed initials as PNG attachments' do
    put user_initials_path, params: { text: 'AA' }

    attachment = UserConfigs.load_initials(user.reload)

    expect(response).to redirect_to(settings_profile_index_path)
    expect(attachment).to be_present
    expect(attachment.blob).to have_attributes(filename: ActiveStorage::Filename.new('initials.png'),
                                               content_type: 'image/png')
    expect(Vips::Image.new_from_buffer(attachment.blob.download, '').width).to be_positive
  end

  it 'preserves uploaded signature support' do
    file = fixture_file_upload(Rails.root.join('spec/fixtures/sample-image.png'), 'image/png')

    put user_signature_path, params: { file: }

    attachment = UserConfigs.load_signature(user.reload)

    expect(response).to redirect_to(settings_profile_index_path)
    expect(attachment.blob).to have_attributes(filename: ActiveStorage::Filename.new('sample-image.png'),
                                               content_type: 'image/png')
  end

  it 'rejects typed values longer than the configured limit' do
    put user_signature_path, params: { text: 'A' * 101 }

    expect(response).to redirect_to(settings_profile_index_path)
    expect(UserConfigs.load_signature(user.reload)).to be_nil
    expect(flash[:notice]).to eq('Unable to save signature.')
  end
end
