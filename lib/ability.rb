# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    grant_self_service_access(user)

    case user.role
    when User::ADMIN_ROLE
      grant_admin_access(user)
    when User::AUDITOR_ROLE
      grant_auditor_access(user)
    else
      grant_user_access(user)
    end
  end

  private

  def grant_self_service_access(user)
    can :manage, User, id: user.id
    can :manage, EncryptedUserConfig, user_id: user.id
    can :manage, UserConfig, user_id: user.id
  end

  def grant_admin_access(user)
    can %i[read create update], Template, Abilities::TemplateConditions.collection(user) do |template|
      Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
    end

    # Hash conditions let CanCan assign account_id when it builds a new Template,
    # so a record is scoped to the admin's account before it is authorized.
    can :create, Template, account_id: user.account_id

    can :destroy, Template, account_id: user.account_id
    can :manage, TemplateFolder, account_id: user.account_id
    can :manage, TemplateSharing, template: { account_id: user.account_id }
    can :manage, Submission, account_id: user.account_id
    can :manage, Submitter, account_id: user.account_id
    can :manage, User, account_id: user.account_id
    can :manage, EncryptedConfig, account_id: user.account_id
    can :manage, EncryptedUserConfig, user_id: user.id
    can :manage, AccountConfig, account_id: user.account_id
    can :manage, UserConfig, user_id: user.id
    can :manage, Account, id: user.account_id
    can :manage, AccessToken, user_id: user.id
    can :manage, McpToken, user_id: user.id
    can :manage, WebhookUrl, account_id: user.account_id

    can :manage, :users
    can :manage, :mcp
  end

  def grant_user_access(user)
    account_conditions = { account_id: user.account_id }
    owned_conditions = account_conditions.merge(author_id: user.id)
    submission_conditions = account_conditions.merge(created_by_user_id: user.id)

    can :create, Template
    can :manage, Template, owned_conditions
    can :read, TemplateFolder, account_conditions
    can :create, TemplateFolder
    can %i[update destroy], TemplateFolder, owned_conditions
    can :manage, TemplateSharing, template: owned_conditions
    can :create, Submission
    can :manage, Submission, submission_conditions
    can :manage, Submitter, submission: submission_conditions
    can :manage, AccessToken, user_id: user.id
  end

  def grant_auditor_access(user)
    completed_submissions = Submission.where(account_id: user.account_id).where.not(completed_at: nil)
    completed_submitters = Submitter.where(submission_id: completed_submissions.select(:id))

    can :read, Template, account_id: user.account_id
    can :read, TemplateFolder, account_id: user.account_id
    can :read, Submission, completed_submissions do |submission|
      submission.account_id == user.account_id && submission.completed_at?
    end
    can :read, Submitter, completed_submitters do |submitter|
      submitter.account_id == user.account_id && submitter.submission.completed_at?
    end
  end
end
