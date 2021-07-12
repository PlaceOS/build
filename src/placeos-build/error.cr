module PlaceOS::Build
  class Error < Exception
    def initialize(io : IO, **args)
      super(io.to_s, **args)
    end

    def initialize(message : String?, **args)
      super
    end

    class AlreadyCompiling < Error
    end

    class UnsignedWrite < Error
      def initialize(**args)
        @message = "Attempting to write a file to s3 via an unsigned client.\nEnsure the following environment variables are set... AWS_REGION, AWS_KEY, AWS_SECRET, AWS_BUCKET"
      end
    end
  end

  class ClientError < Error
    getter response : HTTP::Client::Response
    delegate status_code, to: response

    def initialize(@response : HTTP::Client::Response, message = "")
      super(message)
    end

    def initialize(path : String, @response)
      super("request to #{path} failed with\n#{response.body}")
    end

    def self.from_response(path : String, response : HTTP::Client::Response)
      new(path, response)
    end
  end
end
