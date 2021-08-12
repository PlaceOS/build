require "./executable"

module PlaceOS::Build
  module Compilation
    module Result
      abstract def success? : Bool
    end

    record NotFound do
      include Result

      def success? : Bool
        false
      end
    end

    struct Success
      include Result
      include JSON::Serializable

      def success? : Bool
        true
      end

      getter path : String

      @[JSON::Field(converter: Time::EpochMillisConverter)]
      getter compiled : Time

      def initialize(@path, compiled : Int | Time = Time.utc)
        @compiled = compiled.is_a?(Time) ? compiled : Time.unix_ms(compiled)
      end

      def to_http_headers : HTTP::Headers
        HTTP::Headers{
          DRIVER_HEADER_KEY  => Path[path].basename,
          DRIVER_HEADER_TIME => compiled.to_unix_ms.to_s,
        }
      end
    end

    record Failure, error : String do
      include Result
      include JSON::Serializable

      def success? : Bool
        false
      end
    end
  end
end
