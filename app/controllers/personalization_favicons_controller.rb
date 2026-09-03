# frozen_string_literal: true

class PersonalizationFaviconsController < ApplicationController
  MAX_FILE_SIZE = 1.megabyte
  ALLOWED_CONTENT_TYPES = %w[image/png image/x-icon image/vnd.microsoft.icon image/svg+xml].freeze

  InvalidFavicon = Class.new(StandardError)

  before_action :authorize_account

  def create
    file = params[:favicon]

    validate_favicon!(file)

    file.tempfile.rewind
    current_account.favicon.attach(
      io: file.tempfile,
      filename: file.original_filename,
      content_type: detected_content_type(file),
      identify: false
    )

    redirect_to settings_personalization_path, notice: I18n.t('favicon_has_been_uploaded')
  rescue InvalidFavicon
    redirect_to settings_personalization_path, alert: I18n.t('invalid_favicon')
  end

  def destroy
    current_account.favicon.purge if current_account.favicon.attached?

    redirect_to settings_personalization_path, notice: I18n.t('favicon_has_been_removed')
  end

  private

  def authorize_account
    authorize!(:update, current_account)
  end

  def validate_favicon!(file)
    raise InvalidFavicon unless file.respond_to?(:tempfile)
    raise InvalidFavicon if file.size <= 0 || file.size > MAX_FILE_SIZE
    raise InvalidFavicon unless detected_content_type(file).in?(ALLOWED_CONTENT_TYPES)
  end

  def detected_content_type(file)
    @detected_content_type ||= Marcel::MimeType.for(
      file.tempfile,
      name: file.original_filename,
      declared_type: file.content_type
    )
  end
end
