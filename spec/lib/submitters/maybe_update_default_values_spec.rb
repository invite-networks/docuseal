# frozen_string_literal: true

RSpec.describe Submitters::MaybeUpdateDefaultValues do
  let!(:account) { create(:account) }
  let!(:author) { create(:user, account:) }
  let!(:template) { create(:template, account:, author:, only_field_types: []) }
  let!(:submission) { create(:submission, template:, created_by_user: author) }
  let!(:submitter) do
    create(
      :submitter,
      submission:,
      account:,
      uuid: template.submitters.first.fetch('uuid'),
      name: 'E. User',
      email: 'user@example.com'
    )
  end
  let(:fields) do
    %w[name email title company].map do |type|
      {
        'uuid' => "#{type}-field",
        'submitter_uuid' => submitter.uuid,
        'name' => type.titleize,
        'type' => type,
        'required' => true,
        'areas' => []
      }
    end
  end

  before do
    submission.update!(template_fields: fields)
  end

  it 'prefills identity fields from the recipient and matching Microsoft user' do
    create(
      :user,
      account:,
      email: 'user@example.com',
      first_name: 'Example',
      last_name: 'User',
      title: 'Engineer',
      company: 'Example Corporation'
    )

    described_class.call(submitter, nil)

    expect(submitter.reload.values).to include(
      'name-field' => 'Example User',
      'email-field' => 'user@example.com',
      'title-field' => 'Engineer',
      'company-field' => 'Example Corporation'
    )
  end

  it 'prefills the known name and email for an external recipient' do
    submitter.update!(name: 'Customer Contact', email: 'contact@customer.example')

    described_class.call(submitter, nil)

    expect(submitter.reload.values).to eq(
      'name-field' => 'Customer Contact',
      'email-field' => 'contact@customer.example'
    )
  end

  it 'does not overwrite values already entered by the signer' do
    submitter.update!(values: { 'email-field' => 'edited@example.com', 'title-field' => 'Edited Title' })
    create(:user, account:, email: submitter.email, title: 'Engineer', company: 'Example Corporation')

    described_class.call(submitter, nil)

    expect(submitter.reload.values).to include(
      'email-field' => 'edited@example.com',
      'title-field' => 'Edited Title'
    )
  end
end
