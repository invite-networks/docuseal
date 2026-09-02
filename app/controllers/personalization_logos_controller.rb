# frozen_string_literal: true

class PersonalizationLogosController < ApplicationController
  MAX_FILE_SIZE = 2.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  InvalidLogo = Class.new(StandardError)

  before_action :authorize_account

  def create
    file = params[:logo]

    validate_logo!(file)

    file.tempfile.rewind
    current_account.logo.attach(
      io: file.tempfile,
      filename: file.original_filename,
      content_type: detected_content_type(file),
      identify: false
    )

    redirect_to settings_personalization_path, notice: I18n.t('logo_has_been_uploaded')
  rescue InvalidLogo
    redirect_to settings_personalization_path,
                alert: I18n.t('invalid_company_logo',
                              default: 'Logo must be a PNG, JPEG, or WebP image up to 2 MB.')
  end

  def destroy
    current_account.logo.purge if current_account.logo.attached?

    redirect_to settings_personalization_path,
                notice: I18n.t('company_logo_has_been_removed', default: 'Company logo has been removed.')
  end

  private

  def authorize_account
    authorize!(:update, current_account)
  end

  def validate_logo!(file)
    raise InvalidLogo unless file.respond_to?(:tempfile)
    raise InvalidLogo if file.size <= 0 || file.size > MAX_FILE_SIZE
    raise InvalidLogo unless detected_content_type(file).in?(ALLOWED_CONTENT_TYPES)
  end

  def detected_content_type(file)
    @detected_content_type ||= Marcel::MimeType.for(
      file.tempfile,
      name: file.original_filename,
      declared_type: file.content_type
    )
  end
end
