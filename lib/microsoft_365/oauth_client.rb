# frozen_string_literal: true

module Microsoft365
  class OauthClient
    class << self
      def exchange_code(code:, code_verifier:, redirect_uri:)
        request_token(
          grant_type: 'authorization_code',
          code:,
          code_verifier:,
          redirect_uri:
        )
      end

      def refresh(refresh_token)
        request_token(
          grant_type: 'refresh_token',
          refresh_token:
        )
      end

      private

      def request_token(params)
        Config.ensure_configured!

        response = Faraday.post(Config.token_endpoint) do |request|
          request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
          request.body = URI.encode_www_form(
            params.merge(
              client_id: Config.client_id,
              client_secret: Config.client_secret,
              scope: Config.scopes
            )
          )
        end

        payload = JSON.parse(response.body)

        return payload if response.success? && payload['access_token'].present?

        message = payload['error_description'].presence || payload['error'].presence || "HTTP #{response.status}"
        raise AuthenticationError, "Microsoft token request failed: #{message.to_s.lines.first.to_s.strip}"
      rescue Faraday::Error, JSON::ParserError => e
        raise AuthenticationError, "Microsoft token request failed: #{e.message}"
      end
    end
  end
end
