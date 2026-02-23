require "placeos-models/executable"

module PlaceOS::Build
  abstract class DriverStore
    def self.from_credentials(credentials : S3::Credentials?)
      # All driverstores are backed by filesystem.
      filesystem = Filesystem.new
      if credentials
        client = S3.client_from_credentials(credentials)
        S3.new(filesystem, client)
      else
        filesystem
      end
    end

    abstract def query(
      entrypoint : String? = nil,
      commit : String? = nil,
      digest : String? = nil,
      crystal_version : SemanticVersion | String? = nil,
    ) : Enumerable(Model::Executable)

    def exists?(executable : Model::Executable) : Bool
      File.exists?(path(executable))
    end

    # If the driver already exists
    abstract def link(source : Model::Executable, destination : Model::Executable) : Nil

    abstract def write(filename : String, io : IO) : Nil

    abstract def read(filename : String, & : IO ->)

    # Allow looser guarantees for metadata lookups
    def info?(entrypoint : String, commit : String) : Model::Executable::Info?
      query(entrypoint, commit: commit).first?.try do |executable|
        info(executable)
      end
    end

    abstract def path(executable : Model::Executable) : String
    abstract def info_path(executable : Model::Executable) : String

    # Query for metadata for an exact driver executable
    abstract def info(driver : Model::Executable) : Model::Executable::Info

    # Fetch a `Model::Executable::Info` from the cache
    def fetch_info(driver : Model::Executable) : Model::Executable::Info?
      read(driver.info_filename) do |io|
        json = io.gets_to_end
        raise File::NotFoundError.new("info not present", file: driver.info_filename) unless json.presence
        Model::Executable::Info.from_json(json)
      end
    rescue File::NotFoundError
      Log.debug { "info not in store for #{driver}" }
      nil
    end

    # Write the `Model::Executable::Info` to the cache
    def cache_info(driver : Model::Executable, info : Model::Executable::Info)
      Log.trace { "caching info for #{driver.entrypoint}" }
      write(driver.info_filename, IO::Memory.new(info.to_json))
    end
  end
end

require "./driver_store/*"
