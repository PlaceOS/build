require "./logging"

# Application dependencies
require "action-controller"

# Application code
require "./placeos-build"
require "./placeos-build/api/*"

# Server required after application controllers
require "action-controller/server"

module PlaceOS::Build
  filters = ["bearer_token", "secret", "password"]

  # Add handlers that should run before your application
  ActionController::Server.before(
    ActionController::ErrorHandler.new(production?, ["X-Request-ID"]),
    Raven::ActionController::ErrorHandler.new,
    ActionController::LogHandler.new(filters, ms: true)
  )
end
