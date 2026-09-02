# frozen_string_literal: true

module Microsoft365
  class GraphMailDelivery
    attr_reader :settings

    def initialize(settings = nil)
      @settings = settings || {}
    end

    def deliver!(message)
      Config.ensure_configured!

      user = sender_for(message)
      message.from = user.friendly_name
      access_token = TokenStore.access_token_for(user)

      response = Faraday.post(Config.send_mail_endpoint) do |request|
        request.headers['Authorization'] = "Bearer #{access_token}"
        request.headers['Content-Type'] = 'text/plain'
        request.body = Base64.strict_encode64(message.encoded)
      end

      return message if response.status == 202

      TokenStore.mark_reauthorization_required!(user, graph_error(response)) if response.status.in?([401, 403])

      error = "Microsoft Graph rejected email delivery with HTTP #{response.status}: #{graph_error(response)}"
      raise DeliveryError, error
    rescue Faraday::Error => e
      raise DeliveryError, "Microsoft Graph email delivery failed: #{e.message}"
    end

    private

    def sender_for(message)
      metadata = message.instance_variable_get(:@message_metadata) || {}
      user = User.active.find_by(id: metadata['from_user_id'])

      raise DeliveryError, 'Email does not have an active Microsoft 365 sender.' unless user

      user
    end

    def graph_error(response)
      JSON.parse(response.body).dig('error', 'message').presence || 'Unknown error'
    rescue JSON::ParserError
      'Unknown error'
    end
  end
end
