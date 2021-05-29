require "base64"
require "file_utils"
require "uuid"

require "placeos-compiler/git"

module PlaceOS::Build
  abstract class BinaryStore
    abstract def query(
      entrypoint : String? = nil,
      digest : String? = nil,
      commit : String? = nil,
      crystal_version : SemanticVersion? = nil
    ) : Enumerable(Drivers::ExecutableInfo)

    # Query for metadata for an exact driver executable
    abstract def metadata(driver : Drivers::ExecutableInfo) : String?

    # Allow looser guarantees for metadata lookups
    abstract def metadata(entrypoint : String, commit : String) : String?

    abstract def link(source : Drivers::ExecutableInfo, destination : Drivers::ExecutableInfo) : Nil

    abstract def write(driver : Drivers::ExecutableInfo, io) : Nil

    abstract def read(driver : Drivers::ExecutableInfo, & : IO ->)
  end

  class Filesystem < BinaryStore
    protected getter directory : Dir

    def initialize(directory : String)
      @directory = Dir[directory]
    end

    def query(
      entrypoint : String? = nil,
      digest : String? = nil,
      commit : String? = nil,
      crystal_version : SemanticVersion? = nil
    ) : Enumerable(Drivers::ExecutableInfo)
      directory
        .glob(Drivers::ExecutableInfo.glob(entrypoint, digest, commit, crystal_version), follow_symlinks: true)
        .map { |filename| Drivers::ExecutableInfo.new(filename) }
    end

    def metadata(entrypoint : String, commit : String) : String?
      {{ raise "unimplemented" }}
      nil
    end

    def metadata(driver : Drivers::ExecutableInfo) : String?
      {{ raise "unimplemented" }}
      # Check the cache, return value if found
      # Check for driver in cache
      #   Run the executable for driver
      #   Extract metadata
      #   Cache metadata
      %({"dummy":"json"})
    end

    def link(source : Drivers::ExecutableInfo, destination : Drivers::ExecutableInfo) : Nil
      File.symlink(source.filename, destination.filename)
    end

    def read(driver : Drivers::ExecutableInfo, & : IO ->)
      File.open(path(driver)) do |file_io|
        yield file_io
      end
    end

    def write(driver : Drivers::ExecutableInfo, io) : Nil
      File.open(path(driver)) do |file_io|
        file_io << io
      end
    end

    private def path(driver : Drivers::ExecutableInfo)
      File.join(directory.path, driver.filename)
    end
  end
end

module Drivers
  Log = ::Log.for(self)

  class_property repository_store_path = "./repositories"
  class_property binary_store_path = "./binaries"

  def self.compile(
    repository_uri : String,
    entrypoint : String,
    commit : String,
    force_recompile : Bool = true,
    crystal_version : String? = nil
  ) : String
    key = uri_to_directory(repository_uri)

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

    File.copy(repository_path, temporary_directory)

    # Checkout temporary copy to desired commit.
    Git.checkout(entrypoint, key, Dir.tempdir, commit)

    # Install shards
    # TODO: set the shards cache path
    result = PlaceOS::Compiler.install_shards(key, temporary_directory)
    raise Build::Error.new(result) unless result.success?

    repository_path = File.join(temporary_directory, key)

    # Extract the hash to name the file
    hash = PlaceOS::Build::Digest.digest([entrypoint], repository_path).first.hash

    if force_recompile
      build_driver(
        entrypoint,
        repository: key,
        commit: commit,
        hash: hash,
        working_directory: temporary_directory,
        binary_directory: binary_directory,
        crystal_version: crystal_version,
      )
    else
      # Digest the driver
      _driver_entrypoint = File.join(temporary_directory, key, entrypoint)

      # Look for drivers with matching hash, but different commit
      # Check locally
      # TODO: Check remote cache

      # If it exists, copy with the current commit for the binary

      # Else, look

      # Check locally if a binary exists for any compiler version

      # Check remote if a binary exists for any compiler version

      # If it exists, copy with the correct naming for the binary

      # Otherwise

      # Look for drivers with matching commit, and compiler version
    end
  ensure
    temporary_directory.try(&->FileUtils.rm_r(String)) rescue nil
  end

  protected def self.build_driver(
    entrypoint,
    repository,
    commit,
    working_directory,
    binary_directory,
    hash : String,
    crystal_version : String? = nil
  ) : String
    unless crystal_version
      # Compile with highest available compiler if no version specified
      crystal_version = PlaceOS::Build::Compiler.extract_latest_crystal(repository_path)
    end

    PlaceOS::Build::Compiler.install(crystal_version)

    result = PlaceOS::Compiler.build_driver(
      source_file: entrypoint,
      repository: key,
      commit: commit,
      working_directory: temporary_directory,
      binary_directory: temporary_directory,
    )

    # NOTE: For now write binary to temporary directory, then rename it
    filename = ExecutableInfo.new(entrypoint, commit, hash, crystal_version).filename
    File.join(binary_store_path, filename).tap do |path|
      File.copy result.path, path
    end
  ensure
    result.try { |r| File.delete(r.path) } rescue nil
  end

  # Information pertaining to a binary
  # `entrypoint` is the entrypoint to the file relative to its `shard.yml`
  record ExecutableInfo, entrypoint : String, commit : String, digest : String, crystal_version : SemanticVersion do
    private SEPERATOR = '-'

    def initialize(filename : String)
      name, commit, digest, crystal_version, encoded_directory = File.basename(filename).split(SEPERATOR)
      @entrypoint = File.join(Base64.decode_string(encoded_directory, "#{name}.cr"))
      @commit = commit
      @digest = digest
      @crystal_version = SemanticVersion.parse(crystal_version)
    rescue e
      raise Build::Error.new("#{File.basename(filename)} is not well-formed", cause: e)
    end

    # Produces a glob to match relevant executables
    #
    def self.glob(entrypoint : String?, digest : String?, commit : String?, crystal_version : SemanticVersion?)
      {
        entrypoint.try &->encoded_directory(String),
        digest,
        commit,
        crystal_version.try &.to_s,
      }.join(SEPERATOR) do |value|
        value || "*"
      end
    end

    def name : String
      self.class.name(entrypoint)
    end

    def encoded_directory : String
      self.class.encoded_directory(entrypoint)
    end

    def self.name(entrypoint)
      Path[entrypoint].basename.chop(".cr")
    end

    def self.encoded_directory(entrypoint)
      Base64.urlsafe_encode Path[entrypoint].dirname
    end

    def filename : String
      {name, commit, digest, crystal_version, encoded_directory}.join(SEPERATOR)
    end
  end

  # Returns the URIs of repositories in the `repository_store_path`
  def self.cloned_repositories : Array(String)
    repository_store_path.children.compact_map do |path|
      directory_to_uri(path) if Dir.exists? path
    end
  end

  def self.uri_to_directory(uri)
    Base64.urlsafe_encode(uri)
  end

  def self.directory_to_uri(key)
    Base64.decode_string(key)
  end

  # Yield the path
  def self.cloned?(repository_uri)
    path = Path.join(repository_store_path, uri_to_directory(repository_uri))
    Dir.exists? File.join(path, ".git")
  end
end
