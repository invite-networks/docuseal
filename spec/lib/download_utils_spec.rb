# frozen_string_literal: true

RSpec.describe DownloadUtils do
  describe '.validate_uri!' do
    def validate(url)
      described_class.validate_uri!(URI(url))
    end

    it 'rejects plain HTTP' do
      expect { validate('http://example.com/file.pdf') }
        .to raise_error(DownloadUtils::UnableToDownload, /Only HTTPS/)
    end

    it 'rejects localhost aliases' do
      expect { validate('https://localhost/file.pdf') }
        .to raise_error(DownloadUtils::UnableToDownload, /localhost/)
    end

    it 'rejects literal private, loopback, link-local, and CGNAT addresses' do
      %w[https://10.1.2.3/ https://172.16.5.5/ https://192.168.1.1/ https://169.254.169.254/
         https://100.64.0.1/ https://127.0.0.2/ https://[fd00::1]/ https://[fe80::1]/ https://[::ffff:10.0.0.1]/]
        .each do |url|
        expect { validate(url) }.to raise_error(DownloadUtils::UnableToDownload, /private network/), url
      end
    end

    it 'rejects hostnames that resolve to a private address' do
      allow(described_class).to receive(:resolve_addresses).with('internal.example.com')
                                                            .and_return([IPAddr.new('10.0.0.8')])

      expect { validate('https://internal.example.com/file.pdf') }
        .to raise_error(DownloadUtils::UnableToDownload, /private network/)
    end

    it 'rejects hostnames that resolve to both public and private addresses' do
      allow(described_class).to receive(:resolve_addresses).with('rebind.example.com')
                                                            .and_return([IPAddr.new('93.184.216.34'),
                                                                         IPAddr.new('127.0.0.1')])

      expect { validate('https://rebind.example.com/file.pdf') }
        .to raise_error(DownloadUtils::UnableToDownload, /private network/)
    end

    it 'rejects hostnames that do not resolve' do
      allow(described_class).to receive(:resolve_addresses).with('missing.example.com').and_return([])

      expect { validate('https://missing.example.com/file.pdf') }
        .to raise_error(DownloadUtils::UnableToDownload, /resolve/)
    end

    it 'allows hostnames that resolve to public addresses' do
      allow(described_class).to receive(:resolve_addresses).with('cdn.example.com')
                                                            .and_return([IPAddr.new('93.184.216.34')])

      expect { validate('https://cdn.example.com/file.pdf') }.not_to raise_error
    end
  end

  describe '.call' do
    it 'validates by default' do
      expect { described_class.call('http://example.com/file.pdf') }
        .to raise_error(DownloadUtils::UnableToDownload)
    end
  end
end
