require "action-controller"
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

    # Filters
    ###########################################################################

    before_action :set_request_id

    # This makes it simple to match client requests with server side logs.
    # When building microservices this ID should be propagated to upstream services.
    def set_request_id
      request_id = request.headers["X-Request-ID"]? || UUID.random.to_s
      ::Log.context.set(
        client_ip: client_ip,
        request_id: request_id
      )
      response.headers["X-Request-ID"] = request_id
    end

    # Error Handlers
    ###########################################################################

    struct CommonError
      include JSON::Serializable

      getter error : String?
      getter backtrace : Array(String)?

      def initialize(error, backtrace = true)
        @error = error.message
        @backtrace = backtrace ? error.backtrace : nil
      end
    end

    class ::ActionController::Error < Exception
      class NotFound < ActionController::Error
      end

      class Failure < ActionController::Error
      end
    end

    # 404 if resource not present
    @[AC::Route::Exception(AC::Error::NotFound, status_code: HTTP::Status::NOT_FOUND)]
    def resource_not_found(error) : CommonError
      Log.debug(exception: error) { error.message }
      CommonError.new(error, false)
    end

    @[AC::Route::Exception(AC::Error::Failure, status_code: HTTP::Status::UNPROCESSABLE_ENTITY)]
    def unprocessable(error) : CommonError
      Log.debug(exception: error) { error.message }
      CommonError.new(error, false)
    end
  end
end
