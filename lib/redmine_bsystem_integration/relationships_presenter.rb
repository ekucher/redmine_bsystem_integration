# frozen_string_literal: true

module RedmineBsystemIntegration
  # Builds the view-ready state for the Related Objects panel, translating
  # CoreClient outcomes (ok / unconfigured / degraded / error) into a single
  # small struct the partial can render without knowing anything about HTTP.
  module RelationshipsPresenter
    Result = Struct.new(:status, :global_id, :relationships, :message, keyword_init: true)

    module_function

    def build(global_id:)
      unless Settings.configured?
        return Result.new(
          status: :unconfigured,
          global_id: global_id,
          relationships: [],
          message: ::I18n.t('redmine_bsystem_integration.core_unconfigured')
        )
      end

      relationships = CoreClient.new.list_relationships(global_id: global_id)
      Result.new(status: :ok, global_id: global_id, relationships: relationships, message: nil)
    rescue CoreClient::Unavailable
      Result.new(
        status: :degraded,
        global_id: global_id,
        relationships: [],
        message: ::I18n.t('redmine_bsystem_integration.core_unavailable')
      )
    rescue CoreClient::RequestError => e
      Result.new(status: :error, global_id: global_id, relationships: [], message: e.message)
    end
  end
end
