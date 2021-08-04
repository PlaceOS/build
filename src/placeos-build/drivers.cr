require "base64"
require "file_utils"
require "uuid"

require "placeos-compiler"

require "./compilation"
require "./compiler"
require "./digest/cli"
require "./driver_store"
require "./executable"
require "./repository_store"

module PlaceOS::Build
  class Drivers
    Log = ::Log.for(self)

    protected class_property shards_cache_path do
      ENV["SHARDS_CACHE_PATH"]? || ENV["HOME"]?.try { |p| File.join(p, ".shards") } || File.join(Dir.current, ".shards")
    end

    # Whether to build via the entrypoint environment variable method or not
    class_property? legacy_build_method = false

    # Extract the driver metadata after compilation, rather than lazily
    getter? strict_driver_info : Bool

    private getter compile_lock = Mutex.new
    private getter compiling = Hash(Executable, Bool).new(false)

    getter binary_store : DriverStore
    getter repository_store : RepositoryStore

    def initialize(
      @binary_store = Filesystem.new,
      @repository_store = RepositoryStore.new,
      @strict_driver_info = ENV["STRICT_DRIVER_INFO"]?.try(&.downcase) == "true"
    )
    end

    def local_compiled(
      repository_path : Path,
      entrypoint : String,
      commit : String,
      crystal_version : String? = nil
    )
      executable = extract_executable(repository_path, entrypoint, commit, crystal_version)
      executable.filename if binary_store.exists?(executable)
    rescue e
      Log.debug(exception: e) { {
        message:         "failed to determine if driver was compiled",
        repository_path: repository_path.to_s,
        entrypoint:      entrypoint,
        commit:          commit,
      } }
      nil
    end

    def compiled(
      repository_uri : String,
      entrypoint : String,
      commit : String,
      crystal_version : String? = nil,
      username : String? = nil,
      password : String? = nil
    ) : String?
      repository_store.with_repository(
        repository_uri,
        entrypoint,
        commit,
        branch: nil,
        username: username,
        password: password,
      ) do |repository_path|
        local_compiled(repository_path, entrypoint, commit, crystal_version)
      end
    end

    def local_metadata?(
      repository_path : Path,
      entrypoint : String,
      commit : String,
      crystal_version : String? = nil
    )
      executable = extract_executable(repository_path, entrypoint, commit, crystal_version)
      binary_store.info(executable)
    rescue e
      Log.debug(exception: e) { {
        message:         "failed to extract metadata",
        repository_path: repository_path.to_s,
        entrypoint:      entrypoint,
        commit:          commit,
      } }
      nil
    end

    def metadata?(
      repository_uri : String,
      entrypoint : String,
      commit : String,
      crystal_version : String? = nil,
      username : String? = nil,
      password : String? = nil
    )
      repository_store.with_repository(
        repository_uri,
        entrypoint,
        commit,
        branch: nil,
        username: username,
        password: password,
      ) do |repository_path|
        local_metadata?(repository_path, entrypoint, commit, crystal_version)
      end
    end

    def local_compile(
      repository_path : Path,
      entrypoint : String,
      commit : String,
      force_recompile : Bool = true,
      crystal_version : String? = nil
    )
      executable = extract_executable(repository_path, entrypoint, commit, crystal_version)

      # Look for an exact match
      return Compilation::Success.new(binary_store.path(executable)) if !force_recompile && binary_store.exists?(executable)

      # Look for drivers with matching hash, but different commit
      if !force_recompile && (unchanged_executable = binary_store.query(entrypoint, digest: executable.digest, crystal_version: executable.crystal_version).first?)
        # If it exists, copy with the current commit for the binary
        binary_store.link(unchanged_executable, executable)
        Compilation::Success.new(binary_store.path(executable))
      else
        build_driver(
          executable: executable,
          working_directory: repository_path.to_s,
        )
      end
    end

    def compile(
      repository_uri : String,
      entrypoint : String,
      commit : String,
      force_recompile : Bool = true,
      crystal_version : String? = nil,
      username : String? = nil,
      password : String? = nil
    ) : Compilation::Result
      repository_store.with_repository(
        repository_uri,
        entrypoint,
        commit,
        branch: nil,
        username: username,
        password: password,
      ) do |repository_path|
        local_compile(
          repository_path: repository_path,
          entrypoint: entrypoint,
          commit: commit,
          force_recompile: force_recompile,
          crystal_version: crystal_version,
        )
      end
    rescue e : PlaceOS::Compiler::Error::Git
      Compilation::NotFound.new
    end

    private def extract_executable(repository_path : Path, entrypoint : String, commit : String, crystal_version : String?)
      crystal_version = crystal_version.presence

      # Compile with highest available compiler if no version specified
      crystal_version = Build::Compiler::Crystal.extract_latest_crystal(repository_path.to_s) if crystal_version.nil?

      # Set the local crystal version
      Build::Compiler::Crystal.install(crystal_version)
      Build::Compiler::Crystal.local(crystal_version, repository_path.to_s)

      # Check/Install shards
      install_shards(repository_path.to_s)

      path = repository_path.to_s
      shards_path = File.join(path, "shard.lock")
      entrypoint_path = File.join(path, entrypoint)

      # Extract the hash to name the file
      digest = begin
        PlaceOS::Build::Digest.digest([entrypoint_path], shards_path).first.hash
      rescue e
        Log.warn(exception: e) { "failed to digest #{entrypoint}, using the driver's commit" }
        # Use the commit if a digest could not be produced
        commit[0, 6]
      end

      crystal_version = crystal_version.value if crystal_version.is_a? ::Shards::Version

      Executable.new(entrypoint, commit, digest, crystal_version)
    end

    protected def install_shards(repository_path : String) : Nil
      result = ExecFrom.exec_from(repository_path, "shards", {"--no-color", "check", "--ignore-crystal-version", "--production"})
      output = result.output.to_s
      return if result.status.success? || output.includes?("Dependencies are satisfied")

      # Otherwise install shards
      result = ExecFrom.exec_from(repository_path, "shards", {"--no-color", "install", "--ignore-crystal-version", "--production"}, environment: {"SHARDS_CACHE_PATH" => self.class.shards_cache_path})
      raise Build::Error.new(result.output) unless result.status.success?
    end

    protected def build_driver(
      executable : Executable,
      working_directory : String
    ) : Compilation::Success | Compilation::Failure
      start = Time.utc
      path = if self.class.legacy_build_method?
               result = PlaceOS::Compiler.build_driver(
                 source_file: executable.entrypoint,
                 repository: ".",
                 commit: executable.commit,
                 working_directory: working_directory,
                 binary_directory: working_directory,
               )
               return Compilation::Failure.new(result.output) unless result.success?

               result.path
             else
               executable_name = UUID.random.to_s
               result = ExecFrom.exec_from(
                 working_directory,
                 "crystal",
                 {"build", "--static", "--error-trace", "--no-color", "-o", executable_name, executable.entrypoint}
               )
               return Compilation::Failure.new(result.output.to_s) unless result.status.success?

               File.join(working_directory, executable_name)
             end

      Log.info { "compiling #{executable} took #{(Time.utc - start).total_seconds}s" }

      # Write the binary to the store
      File.open(path) do |file_io|
        binary_store.write(executable.filename, file_io)
      end

      # Extract the metadata to the store
      binary_store.info(executable) if strict_driver_info?

      Compilation::Success.new(executable.filename)
    ensure
      path.try { |p| File.delete(p) } rescue nil
    end

    # Returns the URIs of repositories in the `repository_store_path`
    def cloned_repositories : Array(String)
      repository_store_path.children.compact_map do |path|
        self.class.directory_to_uri(path) if Dir.exists? path
      end
    end

    private def modification_time(executable) : Time
      File.info(binary_store.path(executable)).modification_time
    end
  end
end
