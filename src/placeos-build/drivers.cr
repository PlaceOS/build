require "base64"
require "file_utils"
require "uuid"

require "placeos-compiler"
require "placeos-compiler/git"

require "./executable"
require "./driver_store"

module PlaceOS::Build
  class Drivers
    Log = ::Log.for(self)

    getter repository_store_path : String do
      Path["./repositories"].expand.to_s.tap &->Dir.mkdir_p(String)
    end

    getter binary_store_path : String do
      Path["./binaries"].expand.to_s.tap &->Dir.mkdir_p(String)
    end

    protected class_property shards_cache_path do
      ENV["SHARDS_CACHE_PATH"]? || ENV["HOME"]?.try { |p| File.join(p, ".shards") } || File.join(Dir.current, ".shards")
    end

    # Whether to build via the entrypoint environment variable method or not
    class_property? legacy_build_method = true

    # Extract the driver metadata after compilation, rather than lazily
    getter? strict_driver_info : Bool

    getter store : DriverStore

    def initialize(
      @store = Filesystem.new,
      binary_directory = nil,
      repository_store_path = nil,
      @strict_driver_info = ENV["STRICT_DRIVER_INFO"]?.try(&.downcase) == "true"
    )
      @repository_store_path = repository_store_path unless repository_store_path.nil?
      @binary_store_path = binary_store_path unless binary_store_path.nil?
    end

    def compile(
      repository_uri : String,
      entrypoint : String,
      commit : String,
      force_recompile : Bool = true,
      crystal_version : String? = nil
    ) : String
      key = self.class.uri_to_directory(repository_uri)

      # Ensure repository exists
      if Dir.exists?(File.join(repository_store_path, key))
        PlaceOS::Compiler::Git.fetch(
          repository: key,
          working_directory: repository_store_path,
        )
      else
        PlaceOS::Compiler::Git.clone(
          repository: key,
          repository_uri: repository_uri,
          working_directory: repository_store_path,
        )
      end

      # Copy repository to a temporary directory
      repository_path = File.join(repository_store_path, key)
      key = UUID.random.to_s
      temporary_directory = File.join(Dir.tempdir, key)
      FileUtils.cp_r(repository_path, temporary_directory)
      repository_path = temporary_directory

      # Checkout temporary copy to desired commit.
      PlaceOS::Compiler::Git.checkout(entrypoint, key, Dir.tempdir, commit) do
        # Compile with highest available compiler if no version specified
        crystal_version = Build::Compiler::Crystal.extract_latest_crystal(repository_path) if crystal_version.nil?

        # Set the local crystal version
        Build::Compiler::Crystal.install(crystal_version)
        Build::Compiler::Crystal.local(crystal_version, repository_path)

        # Check/Install shards
        install_shards(repository_path)

        # Extract the hash to name the file
        digest = begin
          PlaceOS::Build::Digest.digest([entrypoint], repository_path).first.hash
        rescue e
          Log.warn { "failed to digest #{entrypoint} using the driver's commit" }
          # Use the commit if a digest could not be produced
          commit[0, 6]
        end

        crystal_version = crystal_version.value if crystal_version.is_a? ::Shards::Version

        executable = Executable.new(entrypoint, commit, digest, crystal_version)

        # Look for an exact match
        return store.path(executable) if !force_recompile && store.exists?(executable)

        # Look for drivers with matching hash, but different commit
        if !force_recompile && (unchanged_executable = store.query(entrypoint, digest: digest, crystal_version: crystal_version).first?)
          # If it exists, copy with the current commit for the binary
          store.link(unchanged_executable, executable)
        else
          build_driver(
            executable: executable,
            repository: key,
            working_directory: Dir.tempdir,
          )
        end

        store.path(executable)
      end
    ensure
      temporary_directory.try { |dir| FileUtils.rm_r(dir) } rescue nil
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
      repository : String,
      working_directory : String
    ) : Nil
      repository_path = File.join(working_directory, repository)

      start = Time.utc

      path = if self.class.legacy_build_method?
               result = PlaceOS::Compiler.build_driver(
                 source_file: executable.entrypoint,
                 repository: repository,
                 commit: executable.commit,
                 working_directory: working_directory,
                 binary_directory: repository_path,
               )
               raise Build::Error.new(result.output) unless result.success?
               result.path
             else
               executable_name = UUID.random.to_s
               result = ExecFrom.exec_from(
                 repository_path,
                 "crystal",
                 {"build", "--static", "--error-trace", "--no-color", "-o", executable_name, executable.entrypoint}
               )
               raise Build::Error.new(result.output) unless result.status.success?
               File.join(repository_path, executable_name)
             end

      Log.info { "compiling #{executable} took #{(Time.utc - start).total_seconds}s" }

      # Write the binary to the store
      File.open(path) do |file_io|
        store.write(executable.filename) do |store_io|
          IO.copy(file_io, store_io)
        end
      end

      # Extract the metadata to the store
      store.info(executable) if strict_driver_info?
    ensure
      path.try { |p| File.delete(p) } rescue nil
    end

    # Returns the URIs of repositories in the `repository_store_path`
    def cloned_repositories : Array(String)
      repository_store_path.children.compact_map do |path|
        self.class.directory_to_uri(path) if Dir.exists? path
      end
    end

    def self.uri_to_directory(uri)
      Base64.urlsafe_encode(uri)
    end

    def self.directory_to_uri(key)
      Base64.decode_string(key)
    end
  end
end
