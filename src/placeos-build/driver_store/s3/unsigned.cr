require "./client"

module PlaceOS::Build
  class S3 < DriverStore
    class Unsigned < Client
      private getter client : HTTP::Client

      getter? can_write : Bool = false

      def self.url(bucket : String, region : String?)
        # NOTE: There is no `Tuple(*T).compact`
        hostname = [bucket, "s3", region].compact.join('.')
        URI.parse "https://#{hostname}.amazonaws.com"
      end

      def initialize(bucket : String, region : String?)
        @client = HTTP::Client.new self.class.url(bucket, region)
      end

      def read(key : String, & : IO ->)
        client.get("/#{key}") do |response|
          raise File::NotFoundError.new("Not present in S3", file: key) unless response.success?
          Compress::LZ4::Reader.open(response.body_io) do |lz4|
            yield lz4
          end
        end
      end

      def list(prefix = nil, max_keys = nil) : Iterator(Object)
        ObjectPaginator.new(client, prefix, max_keys)
      end

      class ObjectPaginator
        include Iterator(Object)

        @objects : Iterator(Object)
        @last : ListObjectsV2

        private getter params : Hash(String, String) = {} of String => String
        private getter client : HTTP::Client

        def initialize(@client, prefix : String? = nil, max_keys : Int32? = nil)
          prefix = prefix.presence
          params["prefix"] = prefix if prefix
          params["max_keys"] = max_keys.to_s if max_keys
          response = next_response
          @last = response
          @objects = response.contents.each
        end

        def next
          next_object = @objects.next
          return next_object unless next_object == stop
          return stop unless @last.truncated?

          params["continuation-token"] = @last.next_token
          response = next_response
          @last = response
          @objects = response.contents.each
          @objects.next
        end

        private def next_response
          query_string = params.join('&') { |k, v| "#{k}=#{URI.encode_path(v)}" }
          response = client.get("/?#{query_string}", headers: HTTP::Headers{"Accept" => "application/xml"})
          ListObjectsV2.from_response(response)
        end
      end

      def copy(source : String, destination : String) : Nil
        raise Error::UnsignedWrite.new
      end

      def write(key : String, io : IO) : Nil
        raise Error::UnsignedWrite.new
      end
    end
  end
end
