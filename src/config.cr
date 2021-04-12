# Application dependencies
require "action-controller"
require "log_helper"
require "placeos-log-backend"

# Application code
require "./placeos-build"
require "./placeos-build/api/*"

# Server required after application controllers
require "action-controller/server"

# Add handlers that should run before your application
ActionController::Server.before(
  ActionController::ErrorHandler.new(PlaceOS::Build.production?, ["X-Request-ID"]),
  ActionController::LogHandler.new(ms: true)
)

# Configure logging
log_level = PlaceOS::Build.production? ? Log::Severity::Info : Log::Severity::Debug
::Log.setup "*", log_level, PlaceOS::LogBackend.log_backend
