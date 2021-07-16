require "clip"
require "compiler/crystal/**"
require "digest/sha1"
require "future"
require "log"

require "placeos-log-backend"

class Crystal::TopLevelVisitor < Crystal::SemanticVisitor
  # Overload to catch exceptions for missing files.
  #
  # This is overriding some very internal compiler code,
  # thankfully tests will loudly catch errors in this.
  def visit(node : Require)
    super
  rescue ex
    raise ex unless ex.message.try &.starts_with? "can't find file"
    nop = Nop.new
    node.expanded = nop
    node.bind_to(nop)
    false
  end
end

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
    getter shard_lock : String?

    getter entrypoints : Array(String)

    abstract def run

    CRYSTAL_PATH         = self.validate_env!("CRYSTAL_PATH")
    CRYSTAL_LIBRARY_PATH = self.validate_env!("CRYSTAL_LIBRARY_PATH")

    protected def self.validate_env!(key)
      ENV[key]?.presence || abort("#{key} not present in environment")
    end

    def lock_file
      shard_lock.try do |f|
        abort("no shard.lock at #{f}") unless File.exists? f
        f
      end
    end

    def paths
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

    def requires(entrypoint) : Enumerable(String)
      compiler = ::Crystal::Compiler.new.tap do |config|
        dev_null = File.open(File::NULL, mode: "w")
        config.color = false
        config.no_codegen = true
        config.release = false
        config.wants_doc = false
        config.stderr = dev_null
        config.stdout = dev_null
      end

      compiler
        .top_level_semantic(source: ::Crystal::Compiler::Source.new(entrypoint.to_s, File.read(entrypoint)))
        .program
        .requires
    end
  end

  @[Clip::Doc("Outputs a list of crystal files in a source graphs, one file per line\nExpects CRYSTAL_PATH and CRYSTAL_LIBRARY_PATH in the environment\n")]
  struct Requires < Cli
    def run
      require_channel = Channel(Enumerable(String)).new

      all_paths = paths
      all_paths.each do |entrypoint|
        spawn do
          require_channel.send requires(entrypoint)
        end
      end

      all_paths.size.times do
        require_channel.receive.each do |f|
          puts f
        end
      end
    end
  end

  @[Clip::Doc("Outputs a CSV of digested crystal source graphs, formatted as FILE,HASH\nExpects CRYSTAL_PATH and CRYSTAL_LIBRARY_PATH in the environment\n")]
  struct Digest < Cli
    @[Clip::Doc("Enable verbose logging")]
    @[Clip::Option("-v", "--verbose")]
    getter verbose : Bool = false

    def run
      ::Log.setup("*", :debug, PlaceOS::LogBackend.log_backend) if verbose

      lock_hash = lock_file.try &->file_hash(String)

      digests = Channel({Path, String}).new
      all_paths = paths
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

      all_paths.size.times do
        result = digests.receive?
        raise "digesting failed!" if result.nil?
        puts result.join(',')
      end
    end

    # Ignore the file if it is from the crystal lib
    # as `digest_cli` is using the compiler purely to compute requires.
    protected def crystal_file_hash?(path : String)
      "c".to_slice if path.starts_with? CRYSTAL_PATH
    end

    # TODO:
    # Look up the SHA1 for a path in the git object store
    protected def object_store_hash?(path)
      nil
    end

    protected def digest_hash(path)
      File.open(path) do |io|
        ::Digest::SHA1.digest &.update(io)
      end
    end

    def file_hash(path)
      object_store_hash?(path) || crystal_file_hash?(path) || digest_hash(path)
    end

    def program_hash(entrypoint : String | Path, shard_digest)
      # Calculate SHA-1 hash of entrypoint's requires
      Log.debug { "digesting #{entrypoint}" }
      futures = requires(entrypoint).map do |file|
        future {
          Log.debug { file }
          file_hash(file)
        }
      end

      # Include the entrypoint in the hash
      entrypoint_sha = File.open(entrypoint) do |io|
        ::Digest::SHA1.digest &.update(io)
      end

      shas = futures.map &.get

      ::Digest::SHA1.hexdigest do |sha|
        shas.each { |digest| sha << digest }
        sha << entrypoint_sha
        shard_digest.try { |digest| sha << digest }
      end[0, 6]
    end
  end
end

PlaceOS::Build::Digest.run
