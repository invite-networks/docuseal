# frozen_string_literal: true

class AddDescriptionToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :description, :text
  end
end
