# frozen_string_literal: true

module Microsoft365
  class IdTokenValidator
    CACHE_KEY = 'microsoft_365/jwks'

    class << self
      def call(id_token, nonce:)
        Config.ensure_configured!

        header = JWT.decode(id_token, nil, false).last
        raise AuthenticationError, 'Microsoft ID token algorithm is invalid.' unless header['alg'] == 'RS256'

        signing_key = find_signing_key(header.fetch('kid'))
        claims = JWT.decode(
          id_token,
          signing_key.public_key,
          true,
          algorithms: ['RS256'],
          aud: Config.client_id,
          verify_aud: true,
          iss: Config.issuer,
          verify_iss: true,
          verify_expiration: true,
          leeway: 60
        ).first

        validate_claims!(claims, nonce:)
        claims
      rescue JWT::DecodeError, KeyError => e
        raise AuthenticationError, "Microsoft ID token validation failed: #{e.message}"
      end

      private

      def validate_claims!(claims, nonce:)
        unless claims['tid'] == Config.tenant_id
          raise AuthenticationError, 'The Microsoft account belongs to a different tenant.'
        end

        raise AuthenticationError, 'Microsoft ID token is missing an object ID.' if claims['oid'].blank?

        token_nonce = claims['nonce'].to_s
        expected_nonce = nonce.to_s
        valid_nonce = token_nonce.bytesize == expected_nonce.bytesize &&
                      ActiveSupport::SecurityUtils.secure_compare(token_nonce, expected_nonce)

        raise AuthenticationError, 'Microsoft sign-in nonce is invalid.' unless valid_nonce
      end

      def find_signing_key(kid)
        key = jwks.find { |item| item[:kid] == kid }
        return key if key

        Rails.cache.delete(CACHE_KEY)
        key = jwks.find { |item| item[:kid] == kid }
        return key if key

        raise AuthenticationError, 'Microsoft ID token signing key was not found.'
      end

      def jwks
        value = Rails.cache.fetch(CACHE_KEY, expires_in: 6.hours) do
          response = Faraday.get(Config.jwks_uri)
          unless response.success?
            raise AuthenticationError, "Unable to load Microsoft signing keys: HTTP #{response.status}"
          end

          JSON.parse(response.body)
        end

        JWT::JWK::Set.new(value)
      rescue Faraday::Error, JSON::ParserError => e
        raise AuthenticationError, "Unable to load Microsoft signing keys: #{e.message}"
      end
    end
  end
end
