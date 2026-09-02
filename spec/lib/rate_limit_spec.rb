# frozen_string_literal: true

RSpec.describe RateLimit do
  it 'is enabled by default outside multitenant mode' do
    key = "spec-#{SecureRandom.hex(4)}"

    described_class.call(key, limit: 1, ttl: 1.minute)

    expect { described_class.call(key, limit: 1, ttl: 1.minute) }.to raise_error(RateLimit::LimitApproached)
  end

  it 'can be disabled explicitly' do
    key = "spec-#{SecureRandom.hex(4)}"

    3.times { expect(described_class.call(key, limit: 1, ttl: 1.minute, enabled: false)).to be(true) }
  end
end
