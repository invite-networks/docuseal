# frozen_string_literal: true

module RateLimit
  LimitApproached = Class.new(StandardError)

  STORE = ActiveSupport::Cache::MemoryStore.new

  module_function

  # Rate limiting is on by default. Callers must opt out explicitly with
  # `enabled: false`; the previous default only enabled limits in multitenant mode.
  def call(key, limit:, ttl:, enabled: true)
    return true unless enabled

    value = STORE.increment(key, 1, expires_in: ttl)

    raise LimitApproached if value > limit

    true
  end
end
