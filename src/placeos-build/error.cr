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
    getter body : String

    def initialize(@response : HTTP::Client::Response, message = "")
      @body = response.body_io?.try(&.gets_to_end) || response.body
      super(message)
    end

    def initialize(path : String, @response)
      if @response.is_a? HTTP::Client::Response
        @body = response.body_io?.try(&.gets_to_end) || response.body
      else
        @body = ""
      end
      super("request to #{path} failed")
    end

    def self.from_response(path : String, response : HTTP::Client::Response)
      new(path, response)
    end
  end
end
