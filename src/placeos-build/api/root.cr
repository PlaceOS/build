require "../error"
require "../api"
require "./application"

require "placeos-models/version"

module PlaceOS::Build::Api
  # Routes trigger builds and query the resulting artefacts.
  class Root < Application
    include ::OpenAPI::Generator::Controller
    include ::OpenAPI::Generator::Helpers::ActionController

    base "/api/build/v1"

    get("/", :root, annotations: @[OpenAPI(<<-YAML
        summary: Service healthcheck
      YAML
    )]) do
      head code: :ok
    end

    get("/version", :version, annotations: @[OpenAPI(<<-YAML
        summary: Service version
      YAML
    )]) do
      render status_code: :ok, json: Root.version
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
