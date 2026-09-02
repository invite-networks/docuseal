# frozen_string_literal: true

RSpec.describe GenerateCertificate do
  it 'keeps distinguished name components structured when the name contains delimiters' do
    name = described_class.build_name('Acme/CN=Fake Authority', 'Acme/CN=Fake Authority Root CA')

    entries = name.to_a.map { |oid, value, _| [oid, value] }

    expect(entries).to eq([['C', 'AT'], ['O', 'Acme/CN=Fake Authority'], ['CN', 'Acme/CN=Fake Authority Root CA']])
  end
end
