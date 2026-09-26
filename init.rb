require 'redmine'

require File.expand_path('lib/redmine_bsystem_integration/settings', __dir__)
require File.expand_path('lib/redmine_bsystem_integration/global_id', __dir__)
require File.expand_path('lib/redmine_bsystem_integration/actor_token_resolver', __dir__)
require File.expand_path('lib/redmine_bsystem_integration/relationship_id_cache', __dir__)
require File.expand_path('lib/redmine_bsystem_integration/core_client', __dir__)
require File.expand_path('lib/redmine_bsystem_integration/relationships_presenter', __dir__)
require File.expand_path('lib/redmine_bsystem_integration/hooks', __dir__)

Redmine::Plugin.register :redmine_bsystem_integration do
  name 'BSYSTEM Integration'
  author 'BSYSTEM'
  description 'Native Related Objects integration between Redmine and BSYSTEM Integration Core (Stage 1).'
  version '0.0.1'
  url 'https://github.com/ekucher/redmine_bsystem_integration'
  author_url 'https://github.com/ekucher'

  requires_redmine version_or_higher: '5.0.0'
end
