require "placeos-log-backend"
require "raven"
require "raven/integrations/action-controller"

require "./constants"

module PlaceOS::Build::Logging
  ::Log.progname = APP_NAME

  standard_sentry = Raven::LogBackend.new
  comprehensive_sentry = Raven::LogBackend.new(capture_all: true)

  # Logging configuration
  log_backend = PlaceOS::LogBackend.log_backend
  log_level = Build.production? ? Log::Severity::Info : Log::Severity::Debug
  log_level = Log::Severity::Trace if Build.trace?
  namespaces = ["action-controller.*", "place_os.*"]

  ::Log.setup do |config|
    config.bind "*", Build.trace? ? Log::Severity::Trace : Log::Severity::Warn, log_backend

    namespaces.each do |namespace|
      config.bind namespace, log_level, log_backend

      # Bind raven's backend
      config.bind namespace, :info, standard_sentry
      config.bind namespace, :warn, comprehensive_sentry
    end
  end

  # Configure Sentry
  Raven.configure &.async=(true)

  PlaceOS::LogBackend.register_severity_switch_signals(
    production: Build.production?,
    namespaces: namespaces,
    backend: log_backend,
  )
end
