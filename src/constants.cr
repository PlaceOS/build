require "secrets-env"

module PlaceOS::Build
  APP_NAME     = "build"
  API_VERSION  = "v1"
  VERSION      = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
  BUILD_TIME   = {{ system("date -u").chomp.stringify }}
  BUILD_COMMIT = {{ env("PLACE_COMMIT") || "DEV" }}

  # S3 caching
  #############################################################################

  AWS_REGION     = ENV["AWS_REGION"]?
  AWS_KEY        = ENV["AWS_KEY"]?
  AWS_SECRET     = ENV["AWS_SECRET"]?
  AWS_S3_OBJECT  = ENV["AWS_S3_OBJECT"]?
  AWS_S3_BUCKET  = ENV["AWS_S3_BUCKET"]?
  AWS_KMS_KEY_ID = ENV["AWS_KMS_KEY_ID"]?

  #############################################################################

  REPOS = ENV["ENGINE_REPOS"]? || Path["./repositories"].expand.to_s

  # REDIS_URL = ENV["REDIS_URL"]? || "redis://localhost:6379"

  class_getter? production { ENV["SG_ENV"]? == "production" }
end
