require "./filesystem"
require "./s3/client"
require "./s3/signed"
require "./s3/unsigned"

module PlaceOS::Build
  class S3 < DriverStore
    Log = ::Log.for(self)

    alias Credentials = Read | ReadWrite
    record Read, aws_s3_bucket : String, aws_region : String
    record ReadWrite, aws_s3_bucket : String, aws_region : String, aws_key : String, aws_secret : String

    # Generate credentials for s3 clients
    #
    def self.credentials(
      aws_s3_bucket : String?,
      aws_region : String?,
      aws_key : String?,
      aws_secret : String?
    ) : Credentials?
      case {aws_s3_bucket, aws_region, aws_key, aws_secret}
      when {String, String, String, String}
        ReadWrite.new(aws_s3_bucket, aws_region, aws_key, aws_secret)
      when {String, String, _, _}
        Read.new(aws_s3_bucket, aws_region)
      else
        nil
      end
    end

    # Generate a new s3 client
    #
    def self.client_from_credentials(credentials : Credentials) : Client
      case credentials
      in Read
        Log.debug { "creating an unsigned s3 client" }
        Unsigned.new(credentials.aws_s3_bucket, credentials.aws_region)
      in ReadWrite
        Log.debug { "creating a signed s3 client" }
        Signed.new(credentials.aws_s3_bucket, credentials.aws_region, credentials.aws_key, credentials.aws_secret)
      end
    end

    private getter filesystem : Filesystem
    private getter client : Client

    def initialize(@filesystem, @client)
    end

    def query(
      entrypoint : String? = nil,
      commit : String? = nil,
      digest : String? = nil,
      crystal_version : SemanticVersion | String? = nil
    ) : Enumerable(Model::Executable)
      ::Log.with_context(
        entrypoint: entrypoint,
        digest: digest,
        commit: commit,
        crystal_version: crystal_version.to_s
      ) do
        if entrypoint && digest && commit && crystal_version
          exact = Model::Executable.new(entrypoint, digest, commit, crystal_version)
        end

        # Query for an exact match on the filesystem
        filesystem_results = filesystem.query(entrypoint, digest, commit, crystal_version)
        if exact.try &.in? filesystem_results
          Log.trace { "exact match found in filesystem cache" }
          return filesystem_results
        end

        # Otherwise, query S3

        # Strip everything after the first '*'.
        # S3 only supports prefix matching.
        prefix = Model::Executable.glob(entrypoint, digest, commit, crystal_version).split('*').first

        query_binary(prefix).to_a.tap do |results|
          Log.trace { {message: "s3 query", prefix: prefix, results: results.map(&.to_s)} }
        end
      end
    end

    def exists?(executable : Model::Executable) : Bool
      filesystem.exists?(executable) || !query_binary(executable.filename).empty?
    end

    def link(source : Model::Executable, destination : Model::Executable) : Nil
      filesystem.link(source, destination)
      client.copy(source.filename, destination.filename)
    end

    def info(driver : Model::Executable) : Model::Executable::Info
      # Check filesystem for info first
      return filesystem.info(driver) if File.exists?(info_path(driver)) || File.exists?(filesystem.path(driver))

      File.open(info_path(driver), mode: "w+") do |file_io|
        unless info = fetch_info(driver)
          # Fetch the driver from S3
          read(driver.filename) do |s3_io|
            filesystem.write(driver.filename, s3_io)
          end

          info = filesystem.info(driver)
        end

        info.to_json(file_io)

        info
      end
    end

    def info_path(executable : Model::Executable) : String
      filesystem.info_path(executable)
    end

    def path(executable : Model::Executable) : String
      local_path = filesystem.path(executable)
      unless File.exists?(local_path)
        read(executable.filename) do |s3_io|
          filesystem.write(executable.filename, s3_io)
        end
      end
      local_path
    end

    def read(filename : String, & : IO ->)
      filesystem.read(filename) do |file_io|
        yield file_io
      end
    rescue e : File::NotFoundError
      raise e unless e.file.ends_with? filename

      Log.trace { "reading #{filename} from S3" }
      client.read(filename) do |s3_io|
        yield s3_io
      end
    end

    # Simultaneously write S3 and the filesystem store
    def write(filename : String, io : IO) : Nil
      Log.trace { "writing #{filename} to S3" }

      # FIXME: Is there a better way to do this?
      filesystem.write(filename, io)

      if client.can_write? && is_elf?(io)
        io.rewind
        client.write(filename, io)
      end
    end

    protected def query_binary(key)
      client
        .list(key)
        .map { |object| Model::Executable.new(Path[object.key].basename) }
    end

    # Helpers
    ###########################################################################

    private ELF_HEADER = Bytes[
      0x7f,
      'E'.bytes.first,
      'L'.bytes.first,
      'F'.bytes.first,
      read_only: true,
    ]

    # Check if `io` is an ELF binary.
    private def is_elf?(io) : Bool
      io.rewind # Reset to start of IO

      slice = Bytes.new(size: 4)
      io.read_fully(slice)
      slice == ELF_HEADER
    rescue
      false
    end
  end
end
