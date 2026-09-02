# frozen_string_literal: true

class SessionsController < Devise::SessionsController
  around_action :with_browser_locale

  def create
    redirect_to microsoft_auth_path(redir: params[:redir])
  end

  def destroy
    sign_out(resource_name)

    return redirect_to microsoft_signed_out_path unless Microsoft365::Config.configured?

    query = {
      client_id: Microsoft365::Config.client_id,
      post_logout_redirect_uri: microsoft_signed_out_url
    }.to_query
    redirect_to "#{Microsoft365::Config.logout_endpoint}?#{query}", allow_other_host: true
  end

  private

  def set_flash_message(key, kind, options = {})
    return if key == :alert && kind == 'already_authenticated'

    super
  end
end
