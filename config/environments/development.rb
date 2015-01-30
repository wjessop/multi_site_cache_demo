require 'multi_site_cache'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log


  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
  config.cache_store = MultiSiteCache.new({
    :max_queue_size => 5000,
    :stores => {
      "sc-chi" => [:redis_store, "redis://localhost:5000/0/cache"],
      "rw-ash" => [:redis_store, "redis://localhost:5001/0/cache"]
    }
  })
  config.action_controller.perform_caching = true
end
