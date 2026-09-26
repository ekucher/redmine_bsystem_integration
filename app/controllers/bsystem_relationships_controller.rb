# frozen_string_literal: true

# Thin controller over Integration Core's relationship endpoints, scoped to
# a single Redmine issue. This plugin adds no new permission and touches no
# native Redmine authorization model: every action re-checks the exact same
# `Issue#visible?` / `Issue#editable?` calls Redmine's own IssuesController
# already relies on elsewhere. If Redmine says the current user cannot see
# or edit the issue, this controller refuses the request the same way core
# Redmine would, before ever calling out to Core.
class BsystemRelationshipsController < ApplicationController
  before_action :find_issue
  before_action :authorize_view

  def index
    render_panel
  end

  def create
    return deny_edit unless can_edit?

    actor_token = resolve_actor_token
    if actor_token.nil?
      flash[:error] = l('redmine_bsystem_integration.actor_unavailable')
      return redirect_to(issue_path(@issue))
    end

    from_global_id = RedmineBsystemIntegration::GlobalId.for_issue(@issue)
    relation_type = params[:relation_type].to_s.strip
    to_global_id = params[:to_global_id].to_s.strip

    begin
      relationship = core_client.create_relationship(
        from_global_id: from_global_id,
        relation_type: relation_type,
        to_global_id: to_global_id,
        actor_token: actor_token
      )
      RedmineBsystemIntegration::RelationshipIdCache.remember(from_global_id, to_global_id, relation_type, relationship['id'])
      flash[:notice] = l('redmine_bsystem_integration.related_objects')
    rescue RedmineBsystemIntegration::CoreClient::Unavailable
      flash[:error] = l('redmine_bsystem_integration.core_unavailable')
    rescue RedmineBsystemIntegration::CoreClient::RequestError => e
      flash[:error] = e.message
    end

    redirect_to issue_path(@issue)
  end

  def destroy
    return deny_edit unless can_edit?

    actor_token = resolve_actor_token
    if actor_token.nil?
      flash[:error] = l('redmine_bsystem_integration.actor_unavailable')
      return redirect_to(issue_path(@issue))
    end

    begin
      # Deletes only the relationship edge identified by this numeric id.
      # This never deletes, updates, or otherwise mutates either endpoint
      # object (the issue itself, or whatever REQ-*/DOC-*/etc. it points
      # at) — only the edge between them.
      core_client.delete_relationship(id: params[:id], actor_token: actor_token)
      other_global_id = params[:other_global_id]
      relation_type = params[:relation_type]
      if other_global_id.present? && relation_type.present?
        RedmineBsystemIntegration::RelationshipIdCache.forget(
          RedmineBsystemIntegration::GlobalId.for_issue(@issue), other_global_id, relation_type
        )
      end
    rescue RedmineBsystemIntegration::CoreClient::Unavailable
      flash[:error] = l('redmine_bsystem_integration.core_unavailable')
    rescue RedmineBsystemIntegration::CoreClient::RequestError => e
      flash[:error] = e.message
    end

    redirect_to issue_path(@issue)
  end

  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Native Redmine authorization is the final authority: this plugin's own
  # controller adds no permission of its own, it only re-checks the same
  # visibility Redmine itself already enforces for viewing the issue.
  def authorize_view
    render_403 unless @issue.visible?(User.current)
  end

  def can_edit?
    @issue.editable?(User.current)
  end

  def deny_edit
    render_403
  end

  def resolve_actor_token
    RedmineBsystemIntegration::ActorTokenResolver.resolve(session: session, user: User.current)
  end

  def core_client
    @core_client ||= RedmineBsystemIntegration::CoreClient.new
  end

  def render_panel
    global_id = RedmineBsystemIntegration::GlobalId.for_issue(@issue)
    @panel = RedmineBsystemIntegration::RelationshipsPresenter.build(global_id: global_id)
    render partial: 'bsystem/relationships_panel', locals: { issue: @issue, panel: @panel }
  end
end
