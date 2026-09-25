require 'redmine'

Redmine::Plugin.register :redmine_bsystem_integration do
  name 'BSYSTEM Integration'
  author 'BSYSTEM'
  description 'Native Related Objects integration between Redmine and BSYSTEM Integration Core (Stage 1).'
  version '0.0.1'
  url 'https://github.com/ekucher/redmine_bsystem_integration'
  author_url 'https://github.com/ekucher'

  requires_redmine version_or_higher: '5.0.0'
end
