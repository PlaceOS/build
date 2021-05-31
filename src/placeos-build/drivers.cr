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

    getter repository_store_path : String = "./repositories"
    getter binary_store_path : String = "./binaries"

    getter store : DriverStore

    def initialize(
      @store = Filesystem.new,
      binary_directory = nil,
      repository_store_path = nil
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
      if cloned?(repository_uri)
        PlaceOS::Compiler::Git.clone(
          repository: key,
          repository_uri: repository_uri,
          working_directory: repository_store_path,
        )
      else
        PlaceOS::Compiler::Git.fetch(
          repository: key,
          working_directory: repository_store_path,
        )
      end

      # Copy repository to a temporary directory
      repository_path = File.join(repository_store_path, key)
      random_directory = UUID.random.to_s
      temporary_directory = File.join(Dir.tempdir, random_directory)
      FileUtils.cp_r(repository_path, temporary_directory)
      repository_path = File.join(temporary_directory, key)

      # Checkout temporary copy to desired commit.
      PlaceOS::Compiler::Git.checkout(entrypoint, key, Dir.tempdir, commit) do
        # Extract the hash to name the file
        digest = PlaceOS::Build::Digest.digest([entrypoint], repository_path).first.hash

        # Compile with highest available compiler if no version specified
        crystal_version = Build::Compiler::Crystal.extract_latest_crystal(repository_path) if crystal_version.nil?
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
            working_directory: temporary_directory,
          )
        end

        store.path(executable)
      end
    ensure
      temporary_directory.try(&->FileUtils.rm_r(String)) rescue nil
    end

    protected def build_driver(
      executable : Executable,
      repository : String,
      working_directory : String
    ) : Nil
      PlaceOS::Build::Compiler::Crystal.install(executable.crystal_version.to_s)

      # Install shards
      # TODO: set the shards cache path
      result = PlaceOS::Compiler.install_shards(repository, working_directory)
      raise Build::Error.new(result.output) unless result.success?

      result = PlaceOS::Compiler.build_driver(
        source_file: executable.entrypoint,
        repository: repository,
        commit: executable.commit,
        working_directory: working_directory,
        binary_directory: working_directory,
      )
      raise Build::Error.new(result.output) unless result.success?

      path = result.path

      # Write the binary to the store
      File.open(path) do |file_io|
        store.write(executable.filename) do |store_io|
          IO.copy(file_io, store_io)
        end
      end
      # Extract the metadata to the store
      store.info(executable)
    ensure
      path.try &->File.delete(String)
    end

    # Returns the URIs of repositories in the `repository_store_path`
    def cloned_repositories : Array(String)
      repository_store_path.children.compact_map do |path|
        self.class.directory_to_uri(path) if Dir.exists? path
      end
    end

    # Yield the path
    def cloned?(repository_uri : String)
      git_dir = File.join(repository_store_path, self.class.uri_to_directory(repository_uri), ".git")
      Dir.exists? git_dir
    end

    def self.uri_to_directory(uri)
      Base64.urlsafe_encode(uri)
    end

    def self.directory_to_uri(key)
      Base64.decode_string(key)
    end
  end
end
