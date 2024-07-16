require "../error"
require "../api"
require "./application"

require "placeos-models/version"

module PlaceOS::Build::Api
  # Routes trigger builds and query the resulting artefacts.
  class Root < Application
    base "/api/build/v1"

    # Service healthcheck
    @[AC::Route::GET("/")]
    def root : Nil
    end

    # Service version
    @[AC::Route::GET("/version")]
    def version : PlaceOS::Model::Version
      Root.version
    end

    class_getter version : PlaceOS::Model::Version do
      PlaceOS::Model::Version.new(
        service: APP_NAME,
        commit: BUILD_COMMIT,
        version: VERSION,
        build_time: BUILD_TIME,
      )
    end
  end
end
