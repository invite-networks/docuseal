# frozen_string_literal: true

RSpec.describe Microsoft365::UserLinker do
  let!(:account) { create(:account) }
  let(:claims) do
    {
      'tid' => 'tenant-id',
      'oid' => 'object-id',
      'email' => 'user@example.com',
      'given_name' => 'Example',
      'family_name' => 'User'
    }
  end
  let(:profile) do
    {
      'givenName' => 'Example',
      'surname' => 'User',
      'mail' => 'user@example.com',
      'userPrincipalName' => 'user@example.com',
      'jobTitle' => 'Engineer',
      'companyName' => 'Example Corporation'
    }
  end

  it 'links an existing user by normalized email once' do
    user = create(:user, account:, email: 'User@Example.com')

    result = described_class.call(claims)

    expect(result).to eq(user)
    expect(result.reload).to have_attributes(
      microsoft_tenant_id: 'tenant-id',
      microsoft_object_id: 'object-id',
      first_name: 'Example',
      last_name: 'User',
      role: User::USER_ROLE
    )
  end

  it 'provisions an assigned tenant user on first login' do
    expect do
      described_class.call(claims)
    end.to change(User, :count).by(1)

    expect(User.last).to have_attributes(
      account:,
      email: 'user@example.com',
      microsoft_tenant_id: 'tenant-id',
      microsoft_object_id: 'object-id',
      role: User::USER_ROLE
    )
  end

  it 'synchronizes a recognized Entra App role at every login' do
    user = create(:user, account:, email: 'user@example.com', role: User::USER_ROLE)

    result = described_class.call(claims.merge('roles' => ['Auditor']))

    expect(result).to eq(user)
    expect(result.reload.role).to eq(User::AUDITOR_ROLE)
  end

  it 'synchronizes Entra identity attributes at every login' do
    user = create(
      :user,
      account:,
      email: 'old-user@example.com',
      first_name: 'Old',
      last_name: 'Name',
      microsoft_tenant_id: claims.fetch('tid'),
      microsoft_object_id: claims.fetch('oid')
    )

    result = described_class.call(claims, profile:)

    expect(result).to eq(user)
    expect(result.reload).to have_attributes(
      email: 'user@example.com',
      first_name: 'Example',
      last_name: 'User',
      title: 'Engineer',
      company: 'Example Corporation'
    )
  end

  it 'clears Microsoft-managed title and company values that were removed in Entra' do
    create(
      :user,
      account:,
      email: 'user@example.com',
      title: 'Old Title',
      company: 'Old Company',
      microsoft_tenant_id: claims.fetch('tid'),
      microsoft_object_id: claims.fetch('oid')
    )

    result = described_class.call(claims, profile: profile.merge('jobTitle' => nil, 'companyName' => nil))

    expect(result.reload).to have_attributes(title: nil, company: nil)
  end

  it 'gives admin precedence when more than one App role is assigned' do
    result = described_class.call(claims.merge('roles' => %w[user auditor admin]))

    expect(result.role).to eq(User::ADMIN_ROLE)
  end

  it 'defaults unknown App roles to user' do
    result = described_class.call(claims.merge('roles' => ['DocumentApprover']))

    expect(result.role).to eq(User::USER_ROLE)
  end

  it 'does not relink an email that is already bound to another identity' do
    create(:user,
           account:,
           email: 'user@example.com',
           microsoft_tenant_id: 'tenant-id',
           microsoft_object_id: 'different-object-id')

    expect { described_class.call(claims) }
      .to raise_error(Microsoft365::AuthenticationError, /already linked/)
  end
end
