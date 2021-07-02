require "./client"

module PlaceOS::Build
  class S3 < DriverStore
    class Unsigned < Client
      private getter client : HTTP::Client

      def self.url(bucket : String, region : String?)
        hostname = [bucket, "s3", region].compact.join('.')
        "https://#{hostname}"
      end

      def initialize(bucket : String, region : String?)
        @client = HTTP::Client.new self.class.url(bucket, region)
      end

      def read(key : String, & : IO ->)
        client.get("/#{key}") do |response|
          unless response.success?
            raise File::NotFoundError.new("Not present in S3", file: key)
          end
          yield response.body_io
        end
      end

      def list(prefix = nil, max_keys = nil) : Iterator(Object)
        ObjectPaginator.new(client, prefix, max_keys)
      end

      class ObjectPaginator
        include Iterator(Object)

        @objects : Iterator(Object)
        @last : ListObjectsV2

        private getter params : Hash(String, String)
        private getter client : HTTP::Client

        def initialize(@client, prefix = nil, max_keys = nil)
          @params = {
            "prefix"   => prefix.to_s,
            "max_keys" => max_keys.to_s,
          }

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
          query_string = @params.join('&') { |k, v| "#{k}=#{URI.encode(string: v, space_to_plus: true)}" }
          ListObjectsV2.from_response(client.get("?#{query_string}"))
        end
      end

      def copy(source : String, destination : String) : Nil
        no_writes_error
      end

      def write(key : String, io : IO) : Nil
        no_writes_error
      end

      private def no_writes_error
        raise "Attempting to write a file to s3 via an unsigned client.\nEnsure the following environment variables are set... AWS_REGION, AWS_KEY, AWS_SECRET, AWS_BUCKET"
      end
    end
  end
end
