# frozen_string_literal: true

RSpec.describe Ability do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:admin) { create(:user, account:, role: User::ADMIN_ROLE) }
  let(:user) { create(:user, account:, role: User::USER_ROLE) }
  let(:other_user) { create(:user, account:, role: User::USER_ROLE) }
  let(:auditor) { create(:user, account:, role: User::AUDITOR_ROLE) }
  let(:external_user) { create(:user, account: other_account, role: User::ADMIN_ROLE) }

  let(:own_template) { create(:template, account:, author: user, attachment_count: 0) }
  let(:other_template) { create(:template, account:, author: other_user, attachment_count: 0) }
  let(:external_template) { create(:template, account: other_account, author: external_user, attachment_count: 0) }

  let(:own_pending) { create(:submission, template: own_template, created_by_user: user) }
  let(:own_completed) do
    create(:submission, template: own_template, created_by_user: user, completed_at: Time.current)
  end
  let(:other_pending) { create(:submission, template: other_template, created_by_user: other_user) }
  let(:other_completed) do
    create(:submission, template: other_template, created_by_user: other_user, completed_at: Time.current)
  end
  let(:external_completed) do
    create(:submission, template: external_template, created_by_user: external_user, completed_at: Time.current)
  end

  describe 'admin access' do
    subject(:ability) { described_class.new(admin) }

    it 'manages account content and settings but not another account' do
      expect(ability.can?(:update, other_template)).to be(true)
      expect(ability.can?(:destroy, other_template)).to be(true)
      expect(ability.can?(:manage, other_completed)).to be(true)
      expect(ability.can?(:manage, other_user)).to be(true)
      expect(ability.can?(:manage, account)).to be(true)
      expect(ability.can?(:manage, :users)).to be(true)
      expect(ability.can?(:read, external_template)).to be(false)
      expect(ability.can?(:read, external_completed)).to be(false)
    end
  end

  describe 'user access' do
    subject(:ability) { described_class.new(user) }

    it 'manages only owned templates and submissions' do
      expect(ability.can?(:create, Template)).to be(true)
      expect(ability.can?(:manage, own_template)).to be(true)
      expect(ability.can?(:read, other_template)).to be(false)
      expect(ability.can?(:manage, own_pending)).to be(true)
      expect(ability.can?(:manage, own_completed)).to be(true)
      expect(ability.can?(:read, other_completed)).to be(false)
      expect(ability.can?(:manage, account)).to be(false)
      expect(ability.can?(:manage, :users)).to be(false)
    end

    it 'scopes database collections to owned records' do
      records = [own_template, other_template, external_template, own_pending, own_completed,
                 other_pending, other_completed, external_completed]
      records.each(&:id)

      expect(Template.accessible_by(ability).ids).to contain_exactly(own_template.id)
      expect(Submission.accessible_by(ability).ids).to contain_exactly(own_pending.id, own_completed.id)
    end
  end

  describe 'auditor access' do
    subject(:ability) { described_class.new(auditor) }

    it 'reads completed account submissions without mutation access' do
      expect(ability.can?(:read, other_completed)).to be(true)
      expect(ability.can?(:read, other_pending)).to be(false)
      expect(ability.can?(:update, other_completed)).to be(false)
      expect(ability.can?(:create, Submission)).to be(false)
      expect(ability.can?(:manage, account)).to be(false)
      expect(ability.can?(:manage, :users)).to be(false)
    end

    it 'scopes database collections to completed records in the account' do
      records = [own_pending, own_completed, other_pending, other_completed, external_completed]
      records.each(&:id)

      expect(Submission.accessible_by(ability).ids).to contain_exactly(own_completed.id, other_completed.id)
    end

    it 'reads submitters only when their account submission is completed' do
      completed_submitter = create(:submitter, submission: other_completed, uuid: SecureRandom.uuid)
      pending_submitter = create(:submitter, submission: other_pending, uuid: SecureRandom.uuid)
      external_submitter = create(:submitter, submission: external_completed, uuid: SecureRandom.uuid)

      expect(ability.can?(:read, completed_submitter)).to be(true)
      expect(ability.can?(:read, pending_submitter)).to be(false)
      expect(ability.can?(:read, external_submitter)).to be(false)
      expect(Submitter.accessible_by(ability).ids).to contain_exactly(completed_submitter.id)
    end
  end
end
