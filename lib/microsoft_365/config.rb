# frozen_string_literal: true

module Microsoft365
  module Config
    SCOPES = %w[openid profile email offline_access User.Read Mail.Send].freeze
    LOGIN_HOST = 'https://login.microsoftonline.com'
    GRAPH_HOST = 'https://graph.microsoft.com'

    module_function

    def configured?
      tenant_id.present? && client_id.present? && client_secret.present?
    end

    def tenant_id
      ENV['MICROSOFT_TENANT_ID'].to_s
    end

    def client_id
      ENV['MICROSOFT_CLIENT_ID'].to_s
    end

    def client_secret
      ENV['MICROSOFT_CLIENT_SECRET'].to_s
    end

    def scopes
      SCOPES.join(' ')
    end

    def authorization_endpoint
      "#{LOGIN_HOST}/#{tenant_id}/oauth2/v2.0/authorize"
    end

    def token_endpoint
      "#{LOGIN_HOST}/#{tenant_id}/oauth2/v2.0/token"
    end

    def logout_endpoint
      "#{LOGIN_HOST}/#{tenant_id}/oauth2/v2.0/logout"
    end

    def issuer
      "#{LOGIN_HOST}/#{tenant_id}/v2.0"
    end

    def jwks_uri
      "#{LOGIN_HOST}/#{tenant_id}/discovery/v2.0/keys"
    end

    def send_mail_endpoint
      "#{GRAPH_HOST}/v1.0/me/sendMail"
    end

    def profile_endpoint
      "#{GRAPH_HOST}/v1.0/me"
    end

    def ensure_configured!
      return if configured?

      raise ConfigurationError,
            'Microsoft 365 is not configured. Set MICROSOFT_TENANT_ID, MICROSOFT_CLIENT_ID, and ' \
            'MICROSOFT_CLIENT_SECRET.'
    end
  end

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class AuthenticationError < Error; end
  class ReauthorizationRequired < Error; end
  class DeliveryError < Error; end
end
