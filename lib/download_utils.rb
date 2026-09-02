# frozen_string_literal: true

module DownloadUtils
  LOCALHOSTS = Set[
    '0.0.0.0',
    '127.0.0.1',
    '127.0.1.1',
    'localhost',
    'localhost.localdomain',
    '::1',
    '[::1]',
    'ip6-localhost',
    'ip6-loopback',
    '127.0.0.0',
    '127.255.255.255',
    '::',
    '0:0:0:0:0:0:0:1',
    '[0:0:0:0:0:0:0:1]',
    '0000:0000:0000:0000:0000:0000:0000:0001',
    '[0000:0000:0000:0000:0000:0000:0000:0001]',
    '::0',
    '0::0',
    '::ffff:127.0.0.1',
    '[::ffff:127.0.0.1]',
    '::ffff:7f00:1',
    '[::ffff:7f00:1]',
    'local',
    'localhost.local',
    'ip6-localnet',
    'ip6-allnodes',
    'ip6-allrouters'
  ].freeze

  # Loopback, private, link-local, CGNAT, multicast, documentation, and other
  # non-public ranges. Requests must never reach any of these.
  BLOCKED_IP_RANGES = %w[
    0.0.0.0/8
    10.0.0.0/8
    100.64.0.0/10
    127.0.0.0/8
    169.254.0.0/16
    172.16.0.0/12
    192.0.0.0/24
    192.0.2.0/24
    192.88.99.0/24
    192.168.0.0/16
    198.18.0.0/15
    198.51.100.0/24
    203.0.113.0/24
    224.0.0.0/4
    240.0.0.0/4
    ::/128
    ::1/128
    64:ff9b::/96
    100::/64
    2001::/32
    2001:db8::/32
    fc00::/7
    fe80::/10
    ff00::/8
  ].map { |cidr| IPAddr.new(cidr) }.freeze

  UnableToDownload = Class.new(StandardError)

  module_function

  # URL validation is on by default. Callers must opt out explicitly with
  # `validate: false`; the previous default only validated in multitenant mode.
  def call(url, validate: true)
    uri = begin
      URI(url)
    rescue URI::Error
      Addressable::URI.parse(url).normalize
    end

    validate_uri!(uri) if validate

    resp = conn(validate:).get(uri)

    raise UnableToDownload, "Error loading: #{uri}" if resp.status >= 400

    resp
  end

  def validate_uri!(uri)
    raise UnableToDownload, "Error loading: #{uri}. Only HTTPS is allowed." if uri.scheme != 'https' ||
                                                                               [443, nil].exclude?(uri.port)

    host = uri.host.to_s.delete_prefix('[').delete_suffix(']')

    raise UnableToDownload, "Error loading: #{uri}. Can't download from localhost." if host.blank? ||
                                                                                       host.in?(LOCALHOSTS)

    addresses = resolve_addresses(host)

    raise UnableToDownload, "Error loading: #{uri}. Unable to resolve host." if addresses.empty?

    return unless addresses.any? { |address| blocked_address?(address) }

    raise UnableToDownload, "Error loading: #{uri}. Can't download from a private network address."
  end

  def resolve_addresses(host)
    literal = begin
      IPAddr.new(host)
    rescue IPAddr::Error
      nil
    end

    return [literal] if literal

    Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map { |info| IPAddr.new(info.ip_address) }.uniq
  rescue SocketError
    []
  end

  def blocked_address?(address)
    address = address.native if address.ipv4_mapped?

    BLOCKED_IP_RANGES.any? { |range| range.include?(address) }
  end

  def conn(validate: true)
    Faraday.new do |faraday|
      faraday.response :follow_redirects, callback: lambda { |_, new_env|
        validate_uri!(new_env[:url]) if validate
      }
    end
  end
end
