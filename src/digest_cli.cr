require "clip"
require "colorize"
require "digest/sha1"
require "future"
require "log"
require "placeos-log-backend"

require "./dependency_graph"

module PlaceOS::Build::Digest
  Log = ::Log.for(self)

  def self.run
    if (command = Cli.parse).is_a? Clip::Mapper::Help
      puts command.help
      exit 1
    end

    command.run
  rescue e : Clip::Error
    puts e
    exit 1
  end

  @[Clip::Doc("A program that walks require trees of Crystal programs")]
  abstract struct Cli
    include Clip::Mapper

    macro inherited
      include Clip::Mapper
      Log = ::Log.for({{ @type }})
    end

    Clip.add_commands({
      "digest"   => Digest,
      "requires" => Requires,
    })

    @[Clip::Doc("Specify a shard.lock")]
    @[Clip::Option("-s", "--shard-lock")]
    getter shard_lock : String? = nil

    getter entrypoints : Array(String)

    abstract def run

    # CRYSTAL_PATH         = self.validate_env!("CRYSTAL_PATH")
    # CRYSTAL_LIBRARY_PATH = self.validate_env!("CRYSTAL_LIBRARY_PATH")

    protected def self.validate_env!(key)
      ENV[key]?.presence || abort("#{key} not present in environment")
    end

    def lock_file
      shard_lock.tap { |f| abort("no shard.lock at #{f}") if f && !File.exists?(f) }
    end

    def self.paths(entrypoints)
      entrypoints.compact_map do |f|
        path = Path[f]
        if File.exists?(path)
          path
        else
          STDERR.puts "#{path} #{"does not exist.".colorize.red}"
          nil
        end
      end
    end
  end

  @[Clip::Doc("Outputs a list of crystal files in a source graphs, one file per line")]
  struct Requires < Cli
    def run
      require_channel = Channel(Set(String)).new

      all_paths = Cli.paths(entrypoints)
      all_paths.each do |entrypoint|
        spawn do
          require_channel.send DependencyGraph.requires(entrypoint)
        end
      end

      all_paths.size.times do
        require_channel.receive.each do |f|
          puts f
        end
      end
    end
  end

  @[Clip::Doc("Outputs a CSV of digested crystal source graphs, formatted as FILE,HASH")]
  struct Digest < Cli
    @[Clip::Doc("Enable verbose logging")]
    @[Clip::Option("-v", "--verbose")]
    getter verbose : Bool = false

    def run
      ::Log.setup("*", :debug, PlaceOS::LogBackend.log_backend) if verbose

      self.class.digest(entrypoints, lock_file).each do |result|
        puts result.join(',')
      end
    end

    def self.digest(entrypoints : Array(String), lock_file : String? = nil)
      lock_hash = lock_file.try &->file_hash(String)
      digests = Channel({Path, String}).new
      all_paths = Cli.paths(entrypoints)
      all_paths.each do |path|
        spawn do
          begin
            before = Time.utc
            digest = program_hash(path, lock_hash)
            after = Time.utc
            Log.trace { "digesting #{path} took #{(after - before).milliseconds}ms" } unless digests.closed?
            digests.send({path, digest}) rescue nil
          rescue e
            Log.error(exception: e) { "failed to digest #{path}" }
            digests.close
          end
        end
      end

      Array({Path, String}).new(all_paths.size).tap do |results|
        all_paths.size.times do
          result = digests.receive?
          raise "digesting failed!" if result.nil?
          results << result
        end
      end
    end

    def self.program_hash(entrypoint : String | Path, shard_digest)
      # Calculate SHA-1 hash of entrypoint's requires
      Log.debug { "digesting #{entrypoint}" }
      futures = DependencyGraph.requires(entrypoint).map do |file|
        future {
          Log.debug { file }
          file_hash(file) if File.exists?(file)
        }
      end

      # Include the entrypoint in the hash
      entrypoint_sha = File.open(entrypoint) do |io|
        ::Digest::SHA1.digest &.update(io)
      end

      shas = futures.compact_map &.get

      ::Digest::SHA1.hexdigest do |sha|
        shas.each { |digest| sha << digest }
        sha << entrypoint_sha
        shard_digest.try { |digest| sha << digest }
      end[0, 6]
    end

    def self.file_hash(path)
      self.object_store_hash?(path) || self.crystal_file_hash?(path) || self.digest_hash(path)
    end

    protected def self.object_store_hash?(path)
      nil
    end

    protected def self.crystal_file_hash?(path : String)
      "c".to_slice if path.starts_with? DependencyGraph.default_crystal_path
    end

    protected def self.digest_hash(path)
      File.open(path) do |io|
        ::Digest::SHA1.digest &.update(io)
      end
    end
  end
end

PlaceOS::Build::Digest.run
