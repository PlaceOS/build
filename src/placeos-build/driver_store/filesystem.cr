require "../driver_store"

module PlaceOS::Build
  class Filesystem < DriverStore
    protected getter binary_store : String

    def initialize(@binary_store : String = Path["./entries"].expand.to_s)
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
      Dir.glob(File.join(binary_store, Executable.glob(entrypoint, digest, commit, crystal_version)), follow_symlinks: true)
        .reject(&.ends_with?(Executable::INFO_EXT))
        .map { |filename| Executable.new(filename) }
    end

    # Query for metadata for an exact driver executable
    def info(driver : Executable) : Executable::Info
      # Return local value if found
      path = info_path(driver)
      return File.open(path) { |io| Executable::Info.from_json(io) } if File.exists? path

      # Check the cache
      info = fetch_info(driver)

      # Extract the info from the driver if not found in the cache
      unless info
        info = driver.info(binary_store)
        cache_info(driver, info)
      end

      info
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
