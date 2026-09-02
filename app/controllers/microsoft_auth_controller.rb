# frozen_string_literal: true

class MicrosoftAuthController < ApplicationController
  AUTH_SESSION_KEY = 'microsoft_oauth'
  RECENT_AUTH_SESSION_KEY = 'microsoft_authenticated_at'
  AUTH_SESSION_TTL = 10.minutes

  skip_before_action :maybe_redirect_to_setup, only: %i[callback frontchannel_logout]
  skip_before_action :authenticate_user!
  skip_authorization_check

  def new
    Microsoft365::Config.ensure_configured!

    auth_session = build_auth_session
    session[AUTH_SESSION_KEY] = auth_session

    redirect_to authorization_url(auth_session), allow_other_host: true
  rescue Microsoft365::ConfigurationError => e
    redirect_to new_user_session_path, alert: e.message
  end

  def callback
    auth_session = session.delete(AUTH_SESSION_KEY)
    validate_callback!(auth_session)

    token_response = Microsoft365::OauthClient.exchange_code(
      code: params.require(:code),
      code_verifier: auth_session.fetch('code_verifier'),
      redirect_uri: auth_session.fetch('redirect_uri')
    )
    claims = Microsoft365::IdTokenValidator.call(
      token_response.fetch('id_token'),
      nonce: auth_session.fetch('nonce')
    )
    profile = Microsoft365::GraphProfileClient.fetch(token_response.fetch('access_token'))
    user = Microsoft365::UserLinker.call(claims, profile:)
    Microsoft365::TokenStore.save!(user, token_response)

    sign_in(user)
    session[RECENT_AUTH_SESSION_KEY] = Time.current.to_i
    redirect_to auth_session['return_to'].presence || root_path, notice: 'Signed in with Microsoft successfully.'
  rescue Microsoft365::Error, ActionController::ParameterMissing, KeyError, ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Microsoft sign-in failed: #{e.class}: #{e.message}")
    redirect_to new_user_session_path, alert: e.message
  end

  def frontchannel_logout
    sign_out(:user)
    head :ok
  end

  def signed_out
    redirect_to new_user_session_path, notice: 'Signed out successfully.'
  end

  private

  def build_auth_session
    code_verifier = SecureRandom.urlsafe_base64(64, false)

    {
      'state' => SecureRandom.urlsafe_base64(32, false),
      'nonce' => SecureRandom.urlsafe_base64(32, false),
      'code_verifier' => code_verifier,
      'code_challenge' => Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false),
      'redirect_uri' => microsoft_auth_callback_url,
      'return_to' => safe_return_to,
      'prompt' => params[:prompt] == 'login' ? 'login' : nil,
      'created_at' => Time.current.to_i
    }
  end

  def authorization_url(auth_session)
    query = {
      client_id: Microsoft365::Config.client_id,
      response_type: 'code',
      redirect_uri: auth_session.fetch('redirect_uri'),
      response_mode: 'query',
      scope: Microsoft365::Config.scopes,
      state: auth_session.fetch('state'),
      nonce: auth_session.fetch('nonce'),
      code_challenge: auth_session.fetch('code_challenge'),
      code_challenge_method: 'S256',
      prompt: auth_session['prompt']
    }.compact

    "#{Microsoft365::Config.authorization_endpoint}?#{query.to_query}"
  end

  def validate_callback!(auth_session)
    if params[:error].present?
      message = params[:error_description].presence || params[:error]
      raise Microsoft365::AuthenticationError, "Microsoft sign-in was not completed: #{message}"
    end

    raise Microsoft365::AuthenticationError, 'Microsoft sign-in session is missing.' if auth_session.blank?
    if auth_session_expired?(auth_session)
      raise Microsoft365::AuthenticationError, 'Microsoft sign-in session has expired.'
    end

    expected_state = auth_session.fetch('state').to_s
    actual_state = params[:state].to_s
    state_matches = actual_state.bytesize == expected_state.bytesize &&
                    ActiveSupport::SecurityUtils.secure_compare(actual_state, expected_state)

    raise Microsoft365::AuthenticationError, 'Microsoft sign-in state is invalid.' unless state_matches
  end

  def auth_session_expired?(auth_session)
    Time.zone.at(auth_session.fetch('created_at').to_i) < AUTH_SESSION_TTL.ago
  end

  def safe_return_to
    value = params[:return_to].presence || params[:redir].presence
    return if value.blank?

    value if value.start_with?('/') && !value.start_with?('//')
  end
end
