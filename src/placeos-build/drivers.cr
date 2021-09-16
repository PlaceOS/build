require "base64"
require "file_utils"
require "uuid"

require "placeos-compiler"
require "placeos-compiler/git"

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
    private getter compiling = Hash(Executable, Array(Channel(Nil))).new

    getter binary_store : DriverStore
    getter repository_store : RepositoryStore

    def initialize(
      @binary_store = Filesystem.new,
      @repository_store = RepositoryStore.new,
      @strict_driver_info = ENV["STRICT_DRIVER_INFO"]?.try(&.downcase) == "true"
    )
    end

    def discover_drivers?(
      repository_uri : String,
      branch : String,
      commit : String,
      username : String? = nil,
      password : String? = nil
    ) : Array(String)?
      repository_store.with_repository(repository_uri, "shard.yml", commit, branch, username, password) do |path|
        local_discover_drivers?(path)
      end
    rescue e
      Log.warn(exception: e) { {
        message:        "failed to discover drivers",
        repository_uri: repository_uri,
        branch:         branch,
        commit:         commit,
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

    def compile(
      repository_uri : String,
      entrypoint : String,
      commit : String,
      force_recompile : Bool = false,
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
      wait_for_compilation(executable) do
        ::Log.with_context do
          Log.context.set(
            entrypoint: executable.entrypoint,
            commit: executable.commit,
            digest: executable.digest,
          )

          begin
            start = Time.utc
            result = if self.class.legacy_build_method?
                       legacy_build(executable, working_directory)
                     else
                       require_build(executable, working_directory)
                     end

            return result if result.is_a? Compilation::Failure
            path = result

            Log.info { "compiling #{executable} took #{(Time.utc - start).total_seconds}s" }

            # Write the binary to the store
            File.open(path) do |file_io|
              binary_store.write(executable.filename, file_io)
            end

            if strict_driver_info?
              # Extract the metadata to the store
              binary_store.info(executable)
            end

            Compilation::Success.new(executable.filename)
          ensure
            path.try { |p| File.delete(p) } rescue nil
          end
        end
      end
    end

    private def legacy_build(executable, working_directory) : String | Compilation::Failure
      Log.trace { "using legacy build method" }
      result = PlaceOS::Compiler.build_driver(
        source_file: executable.entrypoint,
        repository: ".",
        commit: executable.commit,
        working_directory: working_directory,
        binary_directory: working_directory,
      )

      unless result.success?
        output = result.output.to_s
        Log.debug { "build failed with #{output}" }
        return Compilation::Failure.new(output)
      end

      result.path
    end

    class_property build_threads : Int32 = 1

    private def require_build(executable, working_directory) : String | Compilation::Failure
      Log.trace { "using require based method" }
      executable_name = UUID.random.to_s
      result = ExecFrom.exec_from(
        working_directory,
        "crystal",
        {
          "build",
          "--error-trace",
          "--no-color",
          "--static",
          "--threads", self.class.build_threads.to_s,
          "-o", executable_name,
          executable.entrypoint,
        }
      )

      unless result.status.success?
        output = result.output.to_s
        Log.debug { "build failed with #{output}" }
        return Compilation::Failure.new(output)
      end

      File.join(working_directory, executable_name)
    end

    # Returns the URIs of repositories in the `repository_store_path`
    def cloned_repositories : Array(String)
      repository_store_path.children.compact_map do |path|
        self.class.directory_to_uri(path) if Dir.exists? path
      end
    end

    # Local methods
    #
    # These methods are intended for use on existing git repositories at `repository_path`.
    ###############################################################################################
    def local_discover_drivers?(repository_path : Path) : Array(String)?
      Dir
        .glob(repository_path / "drivers/**/*.cr")
        .select! { |file|
          !file.ends_with?("_spec.cr") && File.read_lines(file).any?(&.includes?("< PlaceOS::Driver"))
        }
        .map(&.lchop(repository_path.to_s).lchop('/'))
        .tap do |drivers|
          Log.debug { {message: "discovered drivers", drivers: drivers} }
        end
    rescue e
      Log.warn(exception: e) { {
        message:         "failed to discover drivers",
        repository_path: repository_path.to_s,
      } }
      nil
    end

    def local_compiled(
      repository_path : Path,
      entrypoint : String,
      commit : String,
      crystal_version : String? = nil
    )
      # Attempt to get file's commit first
      commit = file_commit(repository_path, entrypoint) || commit

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

    def local_metadata?(
      repository_path : Path,
      entrypoint : String,
      commit : String,
      crystal_version : String? = nil
    )
      # Attempt to get file's commit first
      commit = file_commit(repository_path, entrypoint) || commit

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

    def local_compile(
      repository_path : Path,
      entrypoint : String,
      commit : String,
      force_recompile : Bool = false,
      crystal_version : String? = nil
    )
      # Attempt to get file's commit first
      commit = file_commit(repository_path, entrypoint) || commit

      executable = extract_executable(repository_path, entrypoint, commit, crystal_version)

      # Look for an exact match
      unless force_recompile
        if binary_store.exists?(executable)
          path = binary_store.path(executable)
          Log.trace { {message: "driver compiled and on disk", path: path} }
          return Compilation::Success.new(path)
        elsif unchanged_executable = query_unchanged(executable)
          # Look for drivers with matching hash, but different commit

          # If it exists, copy with the current commit for the binary
          binary_store.link(unchanged_executable, executable)
          path = binary_store.path(executable)
          Log.trace { {message: "matching driver found in store", path: path} }
          return Compilation::Success.new(path)
        end
      end

      build_driver(
        executable: executable,
        working_directory: repository_path.to_s,
      )
    end

    # Lookup drivers that match except for the file commit
    #
    def query_unchanged(executable)
      binary_store
        .query(executable.entrypoint, digest: executable.digest)
        .find(&.crystal_version.==(executable.crystal_version))
    end

    # File Helpers
    ###############################################################################################

    # Get the last modification time
    private def modification_time(executable) : Time
      File.info(binary_store.path(executable)).modification_time
    end

    # Attempt to extract the commit on disk
    private def file_commit(repository_path : Path, entrypoint : String)
      repository = repository_path.basename
      working_directory = repository_path.parent.to_s
      PlaceOS::Compiler::Git.current_file_commit(entrypoint, repository, working_directory)[0, 6] rescue nil
    end

    # Compilation helpers
    ###############################################################################################

    private def wait_for_compilation(executable : Executable)
      block_compilation(executable)
      yield
    ensure
      unblock_compilation(executable)
    end

    # Blocks if compilation for the executable is in progress
    private def block_compilation(executable : Executable)
      channel = nil
      compile_lock.synchronize do
        if compiling.has_key? executable
          channel = Channel(Nil).new
          compiling[executable] << channel
        else
          compiling[executable] = [] of Channel(Nil)
        end
      end

      if channel
        channel.receive?
        block_compilation(executable)
      end
    end

    private def unblock_compilation(executable : Executable)
      compile_lock.synchronize do
        if waiting = compiling.delete(executable)
          waiting.each &.send(nil)
        end
      end
    end
  end
end
