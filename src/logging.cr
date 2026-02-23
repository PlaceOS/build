require "placeos-log-backend"
require "./constants"

module PlaceOS::Build::Logging
  ::Log.progname = APP_NAME

  # Logging configuration
  log_backend = PlaceOS::LogBackend.log_backend
  log_level = Build.production? ? Log::Severity::Info : Log::Severity::Debug
  log_level = Log::Severity::Trace if Build.trace?
  namespaces = ["action-controller.*", "place_os.*"]

  builder = ::Log.builder
  builder.bind "*", Build.trace? ? Log::Severity::Trace : Log::Severity::Warn, log_backend

  namespaces.each do |namespace|
    builder.bind namespace, log_level, log_backend
  end

  ::Log.setup_from_env(
    default_level: log_level,
    builder: builder,
    backend: log_backend,
    log_level_env: "LOG_LEVEL",
  )

  PlaceOS::LogBackend.register_severity_switch_signals(
    production: Build.production?,
    namespaces: namespaces,
    backend: log_backend,
  )
end
