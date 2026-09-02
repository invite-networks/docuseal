# frozen_string_literal: true

class RevealAccessTokenController < ApplicationController
  RECENT_AUTH_TTL = 5.minutes

  def show
    authorize!(:manage, current_user.access_token)

    @token = current_user.access_token.token if recently_authenticated_with_microsoft?
  end

  private

  def recently_authenticated_with_microsoft?
    authenticated_at = session[MicrosoftAuthController::RECENT_AUTH_SESSION_KEY]

    authenticated_at.present? && Time.zone.at(authenticated_at.to_i) >= RECENT_AUTH_TTL.ago
  end
end
