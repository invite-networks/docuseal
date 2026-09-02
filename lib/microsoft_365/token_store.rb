# frozen_string_literal: true

module Microsoft365
  class TokenStore
    KEY = 'microsoft_365_oauth'
    EXPIRY_SKEW = 5.minutes

    class << self
      def save!(user, token_response)
        config = user.encrypted_configs.find_or_initialize_by(key: KEY)
        current_value = config.value || {}
        if token_response['refresh_token'].blank? && current_value['refresh_token'].blank?
          raise AuthenticationError, 'Microsoft did not issue an offline refresh token.'
        end

        config.value = current_value.merge(token_attributes(token_response)).except('reauthorization_required_at',
                                                                                    'last_error')
        config.save!
        config
      end

      def access_token_for(user)
        config = user.encrypted_configs.find_by(key: KEY)
        raise ReauthorizationRequired, 'Sign in with Microsoft again to send email.' unless config

        config.with_lock do
          value = config.reload.value
          return value['access_token'] if token_fresh?(value)

          refreshed = OauthClient.refresh(value['refresh_token'])
          config.value = value.merge(token_attributes(refreshed)).except('reauthorization_required_at', 'last_error')
          config.save!
          config.value.fetch('access_token')
        end
      rescue AuthenticationError => e
        mark_reauthorization_required!(user, e.message)
        raise ReauthorizationRequired, 'Sign in with Microsoft again to send email.'
      end

      def connected?(user)
        value_for(user).present? && value_for(user)['reauthorization_required_at'].blank?
      end

      def reauthorization_required?(user)
        value_for(user)&.dig('reauthorization_required_at').present?
      end

      def mark_reauthorization_required!(user, message)
        config = user.encrypted_configs.find_by(key: KEY)
        return unless config

        config.with_lock do
          config.value = config.reload.value.merge(
            'reauthorization_required_at' => Time.current.iso8601,
            'last_error' => message
          )
          config.save!
        end
      end

      private

      def value_for(user)
        user.encrypted_configs.find_by(key: KEY)&.value
      end

      def token_fresh?(value)
        value['access_token'].present? && Time.zone.parse(value['expires_at'].to_s) > EXPIRY_SKEW.from_now
      rescue ArgumentError, TypeError
        false
      end

      def token_attributes(token_response)
        expires_in = token_response.fetch('expires_in', 3600).to_i

        {
          'access_token' => token_response.fetch('access_token'),
          'refresh_token' => token_response['refresh_token'],
          'expires_at' => expires_in.seconds.from_now.iso8601,
          'scope' => token_response['scope'].presence || Config.scopes,
          'token_type' => token_response['token_type'].presence || 'Bearer'
        }.compact
      end
    end
  end
end
