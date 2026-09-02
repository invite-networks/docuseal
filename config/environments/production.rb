# frozen_string_literal: true

require 'active_support/core_ext/integer/time'
require 'active_support/core_ext/string'

Rails.backtrace_cleaner.remove_silencers!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  config.public_file_server.headers = {
    'cache-control' => 'public, s-maxage=31536000, max-age=15552000',
    'Expires' => 1.year.from_now.to_fs(:rfc822)
  }

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.active_job.queue_adapter = :sidekiq

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = true

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service =
    if ENV['S3_ATTACHMENTS_BUCKET'].present?
      :aws_s3
    elsif ENV['GCS_BUCKET'].present?
      :google
    elsif ENV['AZURE_CONTAINER'].present?
      :azure
    else
      :disk
    end

  config.active_storage.resolve_model_to_route = :rails_storage_proxy if ENV['ACTIVE_STORAGE_PUBLIC'] != 'true'
  config.active_storage.service_urls_expire_in = ENV.fetch('PRESIGNED_URLS_EXPIRE_MINUTES', '240').to_i.minutes

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Transport security never fails open. FORCE_SSL must be set explicitly: a
  # hostname or "true" enables HTTPS enforcement, HSTS, and secure cookies;
  # "false" is an explicit opt out for deployments that terminate TLS elsewhere
  # and still need plain HTTP between the proxy and the app.
  if ENV['FORCE_SSL'].blank?
    raise 'FORCE_SSL must be set in production (a hostname or "true" to enforce HTTPS, "false" to opt out)'
  end

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = ENV['FORCE_SSL'] != 'false'

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ENV['FORCE_SSL'] != 'false'

  # Only answer requests addressed to the configured public hostname so a
  # misconfigured proxy cannot forward arbitrary Host headers into Rails.
  if ENV['HOST'].present?
    config.hosts = [ENV['HOST']]
    config.host_authorization = { exclude: ->(request) { request.path == '/up' } }
  end

  # Include generic and useful information about system operation, but avoid logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII).
  config.log_level = :info

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  config.cache_store = :memory_store

  config.action_mailer.perform_caching = false

  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :microsoft_graph

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  logger           = ActiveSupport::Logger.new($stdout)
  logger.formatter = config.log_formatter
  config.logger    = ActiveSupport::TaggedLogging.new(logger)

  # Encryption at rest uses its own root secret. It is never derived from
  # SECRET_KEY_BASE, so a leaked session key does not expose encrypted columns
  # (Microsoft Graph tokens, signing certificates). The three key parameters are
  # derived with HKDF using distinct info strings so they are independent of
  # each other as well.
  encryption_secret = ENV['ENCRYPTION_SECRET'].to_s

  if encryption_secret.blank?
    raise 'ENCRYPTION_SECRET must be set in production. Generate one with ' \
          '`ruby -rsecurerandom -e "puts SecureRandom.hex(64)"` and add it to docuseal.env or the environment.'
  end

  raise 'ENCRYPTION_SECRET must be different from SECRET_KEY_BASE' if encryption_secret == ENV['SECRET_KEY_BASE'].to_s

  derive_key = lambda do |info|
    OpenSSL::KDF.hkdf(encryption_secret, salt: 'docuseal-active-record-encryption', info:, length: 32,
                                         hash: 'SHA256').unpack1('H*')
  end

  config.active_record.encryption = {
    primary_key: derive_key.call('primary_key'),
    deterministic_key: derive_key.call('deterministic_key'),
    key_derivation_salt: derive_key.call('key_derivation_salt')
  }

  ActiveRecord::Encryption.configure(**config.active_record.encryption)

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  config.lograge.enabled = true
  config.lograge.base_controller_class = ['ActionController::API', 'ActionController::Base']

  config.lograge.formatter = ->(data) { data.except(:path, :location).to_json }

  config.lograge.custom_payload do |controller|
    params =
      begin
        controller.request.try(:params) || {}
      rescue StandardError
        {}
      end

    resource = controller.instance_variable_get(:@submitter) ||
               controller.instance_variable_get(:@submission) ||
               controller.instance_variable_get(:@template) ||
               controller.instance_variable_get(:@record)

    current_user = controller.instance_variable_get(:@current_user)

    os = DetectBrowserDevice.os(controller.request.user_agent) if ENV['MULTITENANT'] == 'true'

    {
      host: controller.request.host,
      fwd: controller.request.remote_ip,
      params: {
        id: params[:id],
        template_id: params[:template_id],
        submission_id: params[:submission_id],
        submitter_id: params[:submitter_id],
        sig: (params[:signed_key] || params[:signed_uuid] || params[:signed_id]).to_s.split('--').first,
        slug: (params[:slug] ||
               params[:submitter_slug] ||
               params[:submission_slug] ||
               params[:submit_form_slug] ||
               params[:template_slug]).to_s.first(5)
      }.compact_blank,
      **(os ? { os: } : {}),
      uid: current_user.try(:id),
      aid: current_user.try(:account_id),
      rid: resource.try(:id),
      raid: resource.try(:account_id)
    }
  end
end
