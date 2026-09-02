# frozen_string_literal: true

module Abilities
  module TemplateConditions
    module_function

    def collection(user)
      Template.where(account_id: user.account_id)
    end

    # A template without an account is never authorized. Controllers assign the
    # account before authorization (CanCan applies `account_id` from the hash
    # conditions on the admin `create` rule when building a new record).
    def entity(template, user:, ability: nil)
      return false if template.account_id.blank?
      return true if template.account_id == user.account_id
      return false unless user.account.linked_account_account
      return false if template.template_sharings.to_a.blank?

      account_ids = [user.account_id, TemplateSharing::ALL_ID]

      template.template_sharings.to_a.any? do |e|
        e.account_id.in?(account_ids) && (ability.nil? || e.ability == 'manage' || e.ability == ability)
      end
    end
  end
end
