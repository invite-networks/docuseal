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

  it 'never attaches a login to an existing local user by email match' do
    create(:user, account:, email: 'User@Example.com')

    expect { described_class.call(claims) }
      .to raise_error(Microsoft365::AuthenticationError, /already linked to a different Microsoft account/)
    expect(User.count).to eq(1)
  end

  it 'refuses to provision when more than one primary account exists' do
    create(:account)

    expect { described_class.call(claims) }
      .to raise_error(Microsoft365::AuthenticationError, /More than one active account/)
  end

  it 'refuses to provision before setup has created an account' do
    Account.update_all(archived_at: Time.current)

    expect { described_class.call(claims) }
      .to raise_error(Microsoft365::AuthenticationError, /initial application setup/)
  end

  it 'provisions an assigned tenant admin on first login' do
    expect do
      described_class.call(claims.merge('roles' => ['Admin']))
    end.to change(User, :count).by(1)

    expect(User.last).to have_attributes(
      account:,
      email: 'user@example.com',
      microsoft_tenant_id: 'tenant-id',
      microsoft_object_id: 'object-id',
      role: User::ADMIN_ROLE
    )
  end

  it 'requires the DocuSeal Admin App Role for the first login' do
    expect { described_class.call(claims) }
      .to raise_error(Microsoft365::AuthenticationError, /first Microsoft user.*Admin App Role/)

    expect(User.count).to eq(0)
  end

  it 'synchronizes a recognized Entra App role at every login' do
    user = create(:user, account:, email: 'user@example.com', role: User::USER_ROLE,
                         microsoft_tenant_id: 'tenant-id', microsoft_object_id: 'object-id')

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
    create(
      :user,
      account:,
      email: 'admin@example.com',
      microsoft_tenant_id: 'tenant-id',
      microsoft_object_id: 'admin-object-id'
    )

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

  it 'does not clear a suspended (archived) account on login' do
    # Deprovisioning is handled in Entra ID; DocuSeal only mirrors the identity.
    user = create(:user, account:, email: 'user@example.com', archived_at: 1.day.ago,
                         microsoft_tenant_id: 'tenant-id', microsoft_object_id: 'object-id')

    expect(described_class.call(claims)).to eq(user)
  end
end
