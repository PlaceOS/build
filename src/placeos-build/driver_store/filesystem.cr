require "../driver_store"

module PlaceOS::Build
  class Filesystem < DriverStore
    protected getter binary_store : String

    def initialize(@binary_store : String = BINARY_STORE_PATH)
      Dir.mkdir_p binary_store
    end

    def info_path(executable : Executable) : String
      File.join(binary_store, executable.info_filename)
    end

    def path(executable : Executable) : String
      File.join(binary_store, executable.filename)
    end

    def query(
      entrypoint : String? = nil,
      digest : String? = nil,
      commit : String? = nil,
      crystal_version : SemanticVersion | String? = nil
    ) : Enumerable(Executable)
      Log.trace { {
        message:         "query",
        entrypoint:      entrypoint,
        digest:          digest,
        commit:          commit,
        crystal_version: crystal_version,
      } }

      glob = File.join(binary_store, Executable.glob(entrypoint, digest, commit, crystal_version))
      Dir.glob(glob, follow_symlinks: true)
        .reject(&.ends_with?(Executable::INFO_EXT))
        .map(&->Executable.new(String))
    end

    # Query for metadata for an exact driver executable
    def info(driver : Executable) : Executable::Info
      Log.debug { "extracting info for #{driver}" }

      # Check the cache
      if existing = fetch_info(driver)
        return existing
      end

      # Extract the info from the driver if not found in the cache
      driver.info(binary_store).tap do |info|
        cache_info(driver, info)
      end
    end

    def link(source : Executable, destination : Executable) : Nil
      File.symlink(path(source), path(destination))
      File.symlink(info_path(source), info_path(destination))
    end

    def read(filename : String, & : IO ->)
      File.open(File.join(binary_store, filename)) do |file_io|
        yield file_io
      end
    end

    def write(filename : String, io : IO) : Nil
      File.open(File.join(binary_store, filename), mode: "w+", perm: File::Permissions.new(0o744)) do |file_io|
        IO.copy io, file_io
      end
    end
  end
end
