require "action-controller"
require "openapi-generator"
require "openapi-generator/providers/action-controller"
require "openapi-generator/helpers/action-controller"
require "uuid"

module PlaceOS::Build::Api
  abstract class Application < ActionController::Base
    macro inherited
      Log = ::Log.for({{ @type }})
    end

    # Headers
    ###########################################################################

    getter username : String? { request.headers["X-Git-Username"]?.presence }
    getter password : String? { request.headers["X-Git-Password"]?.presence }

    # Parameters
    ###########################################################################

    getter repository_uri : String do
      param url : String, "URL for a git repository"
    end

    getter branch : String do
      param branch : String = "master", "Branch to return commits for"
    end

    getter commit : String do
      param commit : String = "HEAD", "Commit to checkout"
    end

    getter repository_path : String? do
      param repository_path : String? = nil, "Local path to a repository if `build` is configured to support builds referencing a path"
    end

    # Filters
    ###########################################################################

    before_action :set_request_id

    # This makes it simple to match client requests with server side logs.
    # When building microservices this ID should be propagated to upstream services.
    def set_request_id
      request_id = request.headers["X-Request-ID"]? || UUID.random.to_s
      Log.context.set(
        client_ip: client_ip,
        request_id: request_id
      )
      response.headers["X-Request-ID"] = request_id
    end
  end
end
