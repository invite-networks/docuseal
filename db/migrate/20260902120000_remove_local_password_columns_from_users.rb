# frozen_string_literal: true

# Authentication is delegated to Microsoft Entra ID. Local password, lockable,
# recoverable, and TOTP columns are no longer used by any code path.
class RemoveLocalPasswordColumnsFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, :reset_password_token, unique: true
    remove_index :users, :unlock_token, unique: true

    remove_column :users, :encrypted_password, :string, null: false, default: ''
    remove_column :users, :reset_password_token, :string
    remove_column :users, :reset_password_sent_at, :datetime
    remove_column :users, :failed_attempts, :integer, default: 0, null: false
    remove_column :users, :unlock_token, :string
    remove_column :users, :locked_at, :datetime
    remove_column :users, :otp_secret, :string
    remove_column :users, :otp_required_for_login, :boolean, default: false, null: false
    remove_column :users, :consumed_timestep, :integer
  end
end
