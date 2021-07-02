require "./filesystem"
require "./s3/*"

module PlaceOS::Build
  class S3 < DriverStore
    private getter filesystem : Filesystem
    private getter client : Client

    def initialize(@filesystem, @client)
    end

    def query(
      entrypoint : String? = nil,
      digest : String? = nil,
      commit : String? = nil,
      crystal_version : SemanticVersion | String? = nil
    ) : Enumerable(Executable)
      if entrypoint && digest && commit && crystal_version
        exact = Executable.new(entrypoint, digest, commit, crystal_version)
      end

      # First query for an exact match on the filesystem
      filesystem_results = filesystem.query(entrypoint, digest, commit, crystal_version)
      return filesystem_results if exact.try &.in? filesystem_results

      # Otherwise query S3

      glob = Executable.glob(entrypoint, digest, commit, crystal_version)
      first_glob = glob.index('*')
      prefix = first_glob.nil? ? glob : glob[0...first_glob]
      query_binary(prefix).to_a
    end

    def exists?(executable : Executable) : Bool
      filesystem.exists?(executable) || !query_binary(executable.filename).empty?
    end

    def link(source : Executable, destination : Executable) : Nil
      filesystem.link(source, destination)
    end

    def read(filename : String, & : IO ->)
      filesystem.read(filename) do |file_io|
        yield file_io
      end
    rescue e : File::NotFoundError
      raise e unless e.file == filename

      client.read(filename) do |s3_io|
        yield s3_io
      end
    end

    def info(driver : Executable) : Executable::Info
      # Check filesystem for info first
      return filesystem.info(driver) if File.exists? info_path(driver)

      # Check S3
      begin
        memory_io = IO::Memory.new
        File.open(info_path(driver), mode: "w+") do |file_io|
          read(driver.info_filename) do |s3_io|
            IO.copy(s3_io, IO::MultiWriter.new(memory_io, file_io))
          end
        end

        Executable::Info.from_json(memory_io)
      rescue File::NotFoundError
        # Extract the metadata
        filesystem.info(driver).tap do
          # Write it to S3
          File.open(info_path(driver)) do |file_io|
            write(driver.info_filename, file_io)
          end
        end
      end
    end

    def info_path(driver : Executable) : String
      filesystem.info_path(driver)
    end

    def path(driver : Executable) : String
      filesystem.path(driver)
    end

    # Simultaneously write S3 and the filesystem store
    def write(filename : String, io : IO) : Nil
      # FIXME: Is there a better way to do this?
      filesystem.write(filename, io)
      io.rewind
      client.write(filename, io)
    end

    protected def query_binary(key)
      client
        .list(key)
        .map { |object| Executable.new Path[object.key].basename }
    end
  end
end
