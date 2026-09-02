# frozen_string_literal: true

class AddTitleAndCompanyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :title, :string
    add_column :users, :company, :string
  end
end
