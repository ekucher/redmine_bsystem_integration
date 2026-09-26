# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  resources :issues do
    resources :bsystem_relationships, only: %i[index create destroy], controller: 'bsystem_relationships'
  end
end
