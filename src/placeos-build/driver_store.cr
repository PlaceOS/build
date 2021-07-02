require "./executable"

module PlaceOS::Build
  abstract class DriverStore
    abstract def query(
      entrypoint : String? = nil,
      digest : String? = nil,
      commit : String? = nil,
      crystal_version : SemanticVersion | String? = nil
    ) : Enumerable(Executable)

    def exists?(executable : Executable) : Bool
      File.exists?(path(executable))
    end

    # If the driver already exists
    abstract def link(source : Executable, destination : Executable) : Nil

    abstract def write(filename : String, io : IO) : Nil

    abstract def read(filename : String, & : IO ->)

    # Allow looser guarantees for metadata lookups
    def info?(entrypoint : String, commit : String) : String?
      query(entrypoint: entrypoint, commit: commit).first?.try do |executable|
        info(executable)
      end
    end

    abstract def path(executable : Executable) : String
    abstract def info_path(executable : Executable) : String

    # Query for metadata for an exact driver executable
    abstract def info(driver : Executable) : Executable::Info

    # Fetch a `Executable::Info` from the cache
    def fetch_info(driver : Executable) : Executable::Info?
      read(driver.info_filename) do |io|
        Executable::Info.from_json(io)
      end
    rescue e : File::NotFoundError
    end

    # Write the `Executable::Info` to the cache
    def cache_info(driver : Executable, info : Executable::Info)
      io = IO::Memory.new
      info.to_json(io)
      io.rewind
      write(driver.info_filename, io)
    end
  end
end

require "./driver_store/*"
