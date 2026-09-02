# frozen_string_literal: true

class ProfileController < ApplicationController
  before_action do
    authorize!(:manage, current_user)
  end

  def index; end
end
