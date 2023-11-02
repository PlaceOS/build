require "../driver_store"

module PlaceOS::Build
  class Filesystem < DriverStore
    BINARY_STORE_PATH = ENV["PLACEOS_DRIVER_BINARIES"]?.presence || Path["./bin/drivers"].expand.to_s

    protected getter binary_store : String

    def initialize(@binary_store : String = BINARY_STORE_PATH)
      Dir.mkdir_p binary_store
    end

    def info_path(executable : Model::Executable) : String
      File.join(binary_store, executable.info_filename)
    end

    def path(executable : Model::Executable) : String
      File.join(binary_store, executable.filename)
    end

    def query(
      entrypoint : String? = nil,
      commit : String? = nil,
      digest : String? = nil,
      crystal_version : SemanticVersion | String? = nil
    ) : Enumerable(Model::Executable)
      Log.trace { {
        message:         "query",
        entrypoint:      entrypoint,
        digest:          digest,
        commit:          commit,
        crystal_version: crystal_version,
      } }

      # FIXME: commit should be normalized in `Model::Executable.glob`
      commit = commit[0, 7] if commit

      glob = Model::Executable.glob(entrypoint: entrypoint, digest: digest, commit: commit, crystal_version: crystal_version)
      glob_prefix = "#{glob.split('*').first}*"
      glob_query = File.join(binary_store, glob_prefix)

      Dir.glob(glob_query, follow_symlinks: true)
        .reject(&.ends_with?(Model::Executable::INFO_EXT))
        .map(&->Model::Executable.new(String))
        .select do |executable|
          {
            {executable.entrypoint, entrypoint},
            {executable.digest, digest},
            {executable.commit, commit},
            {executable.crystal_version, crystal_version},
          }.reduce(true) do |match, (executable_attribute, attribute)|
            match = match | (executable_attribute == attribute) if attribute
            match
          end
        end
    end

    # Query for metadata for an exact driver executable
    def info(driver : Model::Executable) : Model::Executable::Info
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

    def link(source : Model::Executable, destination : Model::Executable) : Nil
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
