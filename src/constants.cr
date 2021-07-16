require "secrets-env"

module PlaceOS::Build
  APP_NAME     = "build"
  API_VERSION  = "v1"
  VERSION      = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
  BUILD_TIME   = {{ system("date -u").chomp.stringify }}
  BUILD_COMMIT = {{ env("PLACE_COMMIT") || "DEV" }}

  CRYSTAL_VERSION   = {{ env("CRYSTAL_VERSION") || "latest" }}
  DRIVER_HEADER_KEY = "X-PLACEOS-DRIVER-KEY"

  # S3 caching
  #############################################################################

  AWS_REGION    = ENV["AWS_REGION"]?.presence
  AWS_KEY       = ENV["AWS_KEY"]?.presence
  AWS_SECRET    = ENV["AWS_SECRET"]?.presence
  AWS_S3_BUCKET = ENV["AWS_S3_BUCKET"]?.presence

  #############################################################################

  REPOS = ENV["ENGINE_REPOS"]? || Path["./repositories"].expand.to_s

  class_getter? production : Bool { ENV["SG_ENV"]? == "production" }
end
