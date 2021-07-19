module PlaceOS::Build
  module Compilation
    alias Result = Success | Failure | NotFound

    record NotFound

    struct Success
      include JSON::Serializable

      getter path : String

      @[JSON::Field(converter: Time::EpochMillisConverter)]
      getter compiled : Time

      def initialize(@path, compiled = Time.utc)
        @compiled = compiled.is_a?(Time) ? compiled : Time.unix_ms(compiled)
      end

      def to_http_headers
        {
          DRIVER_HEADER_KEY  => Path[path].basename,
          DRIVER_HEADER_TIME => compiled.total_milliseconds,
        }
      end
    end

    record Failure, error : String do
      include JSON::Serializable
    end
  end
end
