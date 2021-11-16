require "uri"
require "./client"
require "lz4"

module PlaceOS::Build
  class S3 < DriverStore
    class Signed < PlaceOS::Build::S3::Client
      private getter region, key, secret, bucket
      private getter s3 : Awscr::S3::Client { Awscr::S3::Client.new(region, key, secret) }
      private getter headers : Hash(String, String) = {} of String => String

      getter? can_write : Bool = true

      def initialize(@bucket : String, @region : String, @key : String, @secret : String)
      end

      def read(object : String, & : IO ->)
        s3.get_object(bucket, object, headers: headers) do |stream|
          Compress::LZ4::Reader.open(stream.body_io) do |lz4|
            yield lz4
          end
        end
      end

      def write(key : String, io : IO) : Nil
        uploader = Awscr::S3::FileUploader.new(s3)
        rewind_io = ->(e : Exception, _a : Int32, _t : Time::Span, _n : Time::Span) {
          Log.error(exception: e) { {key: key, message: "failed to write to S3"} }
          io.rewind
        }

        temp_name = Random.rand(UInt32)
        temporary_path = Path.new("#{Dir.tempdir}/#{temp_name}.xz")

        File.open(temporary_path, "w") do |output_file|
          Compress::LZ4::Writer.open(output_file) do |lz4|
            IO.copy(io, lz4)
          end
        end

        Retriable.retry times: 10, max_interval: 1.minute, on_retry: rewind_io do
          Log.debug { {key: key, message: "writing to S3"} }
          File.open(temporary_path, "r") do |file|
            uploader.upload(bucket, key, file, headers)
          end
        end

        File.delete(temporary_path)
      end

      def copy(source : String, destination : String) : Nil
        log_failure = ->(e : Exception, _a : Int32, _t : Time::Span, _n : Time::Span) {
          Log.error(exception: e) { {source: source, destination: destination, message: "failed to copy in to S3"} }
        }

        Retriable.retry times: 10, max_interval: 1.minute, on_retry: log_failure do
          s3.copy_object(bucket, source, destination)
        end
      end

      def list(prefix = nil, max_keys = nil) : Iterator(Awscr::S3::Object)
        ObjectPaginator.new s3.list_objects(bucket, prefix: prefix, max_keys: max_keys)
      end

      class ObjectPaginator
        include Iterator(Awscr::S3::Object)

        getter paginator

        @objects : Iterator(Object)?

        def initialize(@paginator : Awscr::S3::Paginator::ListObjectsV2)
          first = paginator.next
          @objects = first.contents.each unless first.is_a? Iterator::Stop
        end

        def next
          return Iterator.stop if (objects = @objects).nil?

          unless (object = objects.next).is_a? Iterator::Stop
            return object
          end

          if (next_response = paginator.next).is_a? Iterator::Stop
            return next_response
          end

          next_objects = next_response.contents.each
          @objects = next_objects
          next_objects.next
        end
      end
    end
  end
end
