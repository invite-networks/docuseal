# frozen_string_literal: true

RSpec.describe 'Web submissions' do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account:) }
  let!(:template) { create(:template, account:, author: user, except_field_types: %w[phone payment]) }

  before do
    sign_in(user)
  end

  it 'creates a submission with its own description' do
    post template_submissions_path(template), params: {
      send_email: '0',
      submission: {
        '1' => {
          description: 'NDA for Customer X',
          submitters: [
            {
              uuid: template.submitters.first['uuid'],
              name: 'Customer Contact',
              email: 'contact@customer.example'
            }
          ]
        }
      }
    }

    expect(response).to redirect_to(template_path(template))
    expect(Submission.last.description).to eq('NDA for Customer X')
    expect(Submission.last.submitters.first.email).to eq('contact@customer.example')
  end
end
