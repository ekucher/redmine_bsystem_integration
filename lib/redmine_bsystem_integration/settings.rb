# frozen_string_literal: true

module RedmineBsystemIntegration
  # Reads BSYSTEM Integration Core connectivity configuration.
  #
  # SECRET HANDLING: the service bearer token is a CREDENTIAL (per the
  # BSYSTEM security classification) and is intentionally read only from
  # process environment variables, never from a Redmine plugin Settings
  # row (which is stored in plaintext in Redmine's own database and is
  # visible, unmasked, to any Redmine administrator via Settings > Plugins).
  # This mirrors the platform-wide rule: never commit secrets, keep `.env`
  # ignored, use placeholders in `.env.example`.
  #
  # There is no existing config-loading convention in this repo (it was a
  # bootstrap skeleton), so this is the minimal mechanism introduced here:
  # plain environment variables, documented in docs/COMPATIBILITY.md and in
  # this plugin's `.env.example`-equivalent (see README).
  module Settings
    DEFAULT_OPEN_TIMEOUT_SECONDS = 3
    DEFAULT_READ_TIMEOUT_SECONDS = 5

    BASE_URL_ENV = 'BSYSTEM_CORE_BASE_URL'
    SERVICE_TOKEN_ENV = 'BSYSTEM_CORE_SERVICE_TOKEN'
    OPEN_TIMEOUT_ENV = 'BSYSTEM_CORE_OPEN_TIMEOUT'
    READ_TIMEOUT_ENV = 'BSYSTEM_CORE_READ_TIMEOUT'

    module_function

    # e.g. "https://integration-core.internal.example.com" (no trailing slash)
    def core_base_url
      ENV.fetch(BASE_URL_ENV, '').to_s.strip.sub(%r{/+\z}, '')
    end

    # SVC-redmine's bearer token. Never hardcode, never log this value.
    def service_token
      ENV.fetch(SERVICE_TOKEN_ENV, '').to_s.strip
    end

    def open_timeout
      Integer(ENV.fetch(OPEN_TIMEOUT_ENV, DEFAULT_OPEN_TIMEOUT_SECONDS))
    rescue ArgumentError, TypeError
      DEFAULT_OPEN_TIMEOUT_SECONDS
    end

    def read_timeout
      Integer(ENV.fetch(READ_TIMEOUT_ENV, DEFAULT_READ_TIMEOUT_SECONDS))
    rescue ArgumentError, TypeError
      DEFAULT_READ_TIMEOUT_SECONDS
    end

    def configured?
      !core_base_url.empty? && !service_token.empty?
    end
  end
end
