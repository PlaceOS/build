require "secrets-env"

module PlaceOS::Build
  APP_NAME     = "build"
  API_VERSION  = "v1"
  VERSION      = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
  BUILD_TIME   = {{ system("date -u").chomp.stringify }}
  BUILD_COMMIT = {{ env("PLACE_COMMIT") || "DEV" }}

  CRYSTAL_VERSION = {{ env("CRYSTAL_VERSION") || "1.1.1" }}

  TRACE      = !!ENV["PLACEOS_ENABLE_TRACE"]?.presence.try(&.in?("1", "true"))
  PRODUCTION = ENV["SG_ENV"]? == "production"

  #############################################################################

  SUPPORT_LOCAL_BUILDS = !!ENV["PLACEOS_BUILD_LOCAL"]?.presence.try(&.downcase.in?("1", "true"))

  # Whether the API supports path referencing in builds. Defaults to `false`
  class_getter? support_local_builds = SUPPORT_LOCAL_BUILDS

  # Keys in API responses
  #############################################################################

  DRIVER_HEADER_KEY  = "X-PLACEOS-DRIVER-KEY"
  DRIVER_HEADER_TIME = "X-PLACEOS-DRIVER-TIME"

  # S3 caching
  #############################################################################

  AWS_KEY       = ENV["AWS_KEY"]?.presence
  AWS_SECRET    = ENV["AWS_SECRET"]?.presence
  AWS_REGION    = ENV["AWS_REGION"]?.presence
  AWS_S3_BUCKET = ENV["AWS_S3_BUCKET"]?.presence

  #############################################################################

  REPOSITORY_STORE_PATH = ENV["PLACEOS_REPOSITORIES"]?.presence || Path["./repositories"].expand.to_s
  BINARY_STORE_PATH     = ENV["PLACEOS_DRIVER_BINARIES"]?.presence || Path["./bin/drivers"].expand.to_s

  class_getter? production : Bool { PRODUCTION }
  class_getter? trace : Bool { TRACE }
end
