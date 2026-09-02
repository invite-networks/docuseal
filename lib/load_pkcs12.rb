# frozen_string_literal: true

# Parses uploaded PKCS12 bundles. OpenSSL 3 ships without the RC2 and 3DES
# ciphers that older exports use; instead of activating the legacy provider for
# the whole process via OPENSSL_CONF, it is loaded on demand only when a bundle
# fails to parse with the default provider.
module LoadPkcs12
  MUTEX = Mutex.new

  module_function

  def call(der, password)
    OpenSSL::PKCS12.new(der, password.to_s)
  rescue OpenSSL::PKCS12::PKCS12Error
    raise unless load_legacy_provider

    OpenSSL::PKCS12.new(der, password.to_s)
  end

  def load_legacy_provider
    MUTEX.synchronize do
      return false if @legacy_provider_loaded

      OpenSSL::Provider.load('legacy')

      @legacy_provider_loaded = true
    end
  rescue OpenSSL::Provider::ProviderError
    false
  end
end
