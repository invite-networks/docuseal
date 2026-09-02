# frozen_string_literal: true

class DashboardController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  before_action :maybe_render_landing

  skip_authorization_check

  def index
    if cookies.permanent[:dashboard_view] == 'submissions'
      SubmissionsDashboardController.dispatch(:index, request, response)
    else
      TemplatesDashboardController.dispatch(:index, request, response)
    end
  end

  private

  def maybe_render_landing
    return if signed_in?

    render 'pages/landing'
  end
end
