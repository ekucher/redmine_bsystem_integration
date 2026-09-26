# frozen_string_literal: true

module RedmineBsystemIntegration
  # Renders the Related Objects panel into the issue "show" page.
  #
  # Hook name choice (UNVERIFIED against a live Redmine instance — standard
  # Redmine 5.x convention only): `view_issues_show_details_bottom` is the
  # view hook Redmine's own built-in "Related issues" block renders through
  # on issues/show.html.erb, near the bottom of the issue detail area, after
  # attributes/description/attachments. This is the closest documented match
  # for "a panel in the issue show page" and mirrors the placement of the
  # native related-issues UI it sits alongside. Confirm against the actual
  # deployed Redmine/theme before relying on it in production.
  class Hooks < Redmine::Hook::ViewListener
    def view_issues_show_details_bottom(context = {})
      issue = context[:issue]
      controller = context[:controller]
      return '' if issue.nil? || controller.nil?

      # Redmine's own native authorization is the only gate here: if the
      # current user cannot see this issue, nothing from this plugin is
      # shown or fetched. This mirrors, and never weakens or bypasses, the
      # check Redmine's IssuesController already performed to reach this
      # point.
      return '' unless issue.visible?(User.current)

      global_id = RedmineBsystemIntegration::GlobalId.for_issue(issue)
      panel = RedmineBsystemIntegration::RelationshipsPresenter.build(global_id: global_id)

      controller.send(
        :render_to_string,
        partial: 'bsystem/relationships_panel',
        locals: { issue: issue, panel: panel }
      )
    end
  end
end
