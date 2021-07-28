module PlaceOS::Build
  module Compilation
    alias Result = Success | Failure | NotFound

    record NotFound do
      def success?
        false
      end
    end

    struct Success
      include JSON::Serializable

      def success?
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
      include JSON::Serializable

      def success?
        false
      end
    end
  end
end
