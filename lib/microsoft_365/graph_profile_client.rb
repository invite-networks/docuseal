# frozen_string_literal: true

module Microsoft365
  class GraphProfileClient
    PROFILE_FIELDS = %w[givenName surname mail userPrincipalName jobTitle companyName].freeze

    class << self
      def fetch(access_token)
        response = Faraday.get(Config.profile_endpoint) do |request|
          request.headers['Authorization'] = "Bearer #{access_token}"
          request.params['$select'] = PROFILE_FIELDS.join(',')
        end
        payload = JSON.parse(response.body)

        return payload if response.success?

        message = payload.dig('error', 'message').presence || "HTTP #{response.status}"
        raise AuthenticationError, "Microsoft profile request failed: #{message.to_s.lines.first.to_s.strip}"
      rescue Faraday::Error, JSON::ParserError => e
        raise AuthenticationError, "Microsoft profile request failed: #{e.message}"
      end
    end
  end
end
