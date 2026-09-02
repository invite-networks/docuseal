# frozen_string_literal: true

class AddMicrosoftIdentityToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :microsoft_tenant_id, :string
    add_column :users, :microsoft_object_id, :string

    add_index :users,
              %i[microsoft_tenant_id microsoft_object_id],
              unique: true,
              where: 'microsoft_tenant_id IS NOT NULL AND microsoft_object_id IS NOT NULL',
              name: 'index_users_on_microsoft_identity'
  end
end
