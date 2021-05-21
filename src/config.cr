# Application dependencies
require "action-controller"

# Application code
require "./logging"
require "./placeos-build"
require "./placeos-build/api/*"

# Server required after application controllers
require "action-controller/server"

# Add handlers that should run before your application
ActionController::Server.before(
  ActionController::ErrorHandler.new(PlaceOS::Build.production?, ["X-Request-ID"]),
  ActionController::LogHandler.new(ms: true)
)
