# frozen_string_literal: true

module UserConfigs
  module CreateSignatureAttachment
    MAX_TEXT_LENGTHS = {
      'initials' => 20,
      'signature' => 100
    }.freeze

    class InvalidInput < StandardError; end

    module_function

    def call(user:, name:, file: nil, text: nil)
      blob = text.present? ? create_typed_blob(name, text) : create_uploaded_blob(file)

      ActiveStorage::Attachment.create!(blob:, name:, record: user)
    end

    def create_typed_blob(name, text)
      text = text.to_s.strip
      max_length = MAX_TEXT_LENGTHS.fetch(name)

      raise InvalidInput if text.blank? || text.length > max_length

      data, = Submitters::GenerateFontImage.call(text, font: name)

      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(data),
        filename: "#{name}.png",
        content_type: 'image/png'
      )
    end

    def create_uploaded_blob(file)
      raise InvalidInput if file.blank?

      extension = File.extname(file.original_filename).delete_prefix('.').downcase

      if Submitters::DANGEROUS_EXTENSIONS.include?(extension)
        raise Submitters::MaliciousFileExtension, "File type '.#{extension}' is not allowed."
      end

      ActiveStorage::Blob.create_and_upload!(io: file.open,
                                             filename: file.original_filename,
                                             content_type: file.content_type)
    end
  end
end
