Calcentral::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  config.eager_load = true

  # Show full error reports and enable caching
  config.consider_all_requests_local       = true

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # For rails_admin, to prevent live emails from going out from dev environment
  config.action_mailer.default_url_options = { :host => 'localhost:3000' }

  # Do not compress assets
  # Set this to true if you want to compress the assets.
  config.assets.compress = false

  # Don't fallback to assets pipeline if a precompiled asset is missed
  # config.assets.compile = false

  # Expands the lines which load the assets
  config.assets.debug = true

  # We need to leave this to false since otherwise it takes 25 seconds to compile
  # https://jira.media.berkeley.edu/jira/browse/CLC-1585
  config.sass.debug_info = false

  # source maps don't get output if this is true
  config.sass.line_comments = false

  # Turn off all page, action, fragment caching
  config.action_controller.perform_caching = false

  Cache::Config.setup_cache_store config

end
