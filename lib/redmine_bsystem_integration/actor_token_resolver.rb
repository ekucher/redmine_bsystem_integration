# frozen_string_literal: true

module RedmineBsystemIntegration
  # Resolves the trusted end-user bearer token sent as X-On-Behalf-Of to
  # Integration Core.
  #
  # SECURITY (load-bearing): this resolver reads ONLY from the Rack session
  # that Redmine's own server-side authentication established for the
  # current request. It must NEVER read from `params`, from any client-
  # supplied request header, or from anything else the browser controls.
  # Integration Core independently re-verifies whatever token is sent here
  # (local JWT signature check or a live authentik UserInfo call) before
  # trusting it, so a wrong/stale value here fails closed at Core rather
  # than silently impersonating someone — but this plugin must still never
  # give the caller a way to choose whose identity is asserted.
  #
  # KNOWN GAP (explicitly not invented here, per the audit and this
  # project's stop-conditions around identity mapping): populating
  # `session[SESSION_KEY]` requires Redmine's own login flow to be wired to
  # authentik (e.g. an OmniAuth/OpenID-Connect strategy that stashes the
  # resulting end-user access token in the session at login time). That
  # wiring does not exist yet in this repository and is an owner/production
  # identity decision, not something this plugin should fabricate. Until it
  # exists, this resolver correctly returns nil for every user, and callers
  # must treat nil as "on-behalf-of identity unavailable" and refuse to
  # perform mutating Core calls rather than omitting the header or
  # forging a value.
  module ActorTokenResolver
    SESSION_KEY = :bsystem_authentik_access_token

    module_function

    def resolve(session:, user:)
      return nil if user.nil? || !user.logged?
      return nil if session.nil?

      token = session[SESSION_KEY]
      token.respond_to?(:empty?) && !token.empty? ? token : nil
    end
  end
end
