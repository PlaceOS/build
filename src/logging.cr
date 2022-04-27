require "placeos-log-backend"
require "placeos-log-backend/telemetry"
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

  builder = ::Log.builder
  builder.bind "*", Build.trace? ? Log::Severity::Trace : Log::Severity::Warn, log_backend
  builder.bind "raven", :warn, log_backend

  namespaces.each do |namespace|
    builder.bind namespace, log_level, log_backend

    # Bind raven's backend
    builder.bind namespace, :info, standard_sentry
    builder.bind namespace, :warn, comprehensive_sentry
  end

  ::Log.setup_from_env(
    default_level: log_level,
    builder: builder,
    backend: log_backend,
    log_level_env: "LOG_LEVEL",
  )

  # Configure Sentry
  Raven.configure &.async=(true)

  PlaceOS::LogBackend.register_severity_switch_signals(
    production: Build.production?,
    namespaces: namespaces,
    backend: log_backend,
  )

  PlaceOS::LogBackend.configure_opentelemetry(
    service_name: APP_NAME,
    service_version: VERSION,
  )
end
