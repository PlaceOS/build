require "compiler/crystal/**"
require "digest/sha1"
require "future"

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

class PlaceOS::Build::Digest::Cli
  Log = ::Log.for(self)

  def self.run(args = ARGV.dup)
    paths = [] of Path

    shard_lock = nil

    # Command line options
    OptionParser.parse(args) do |parser|
      parser.banner = <<-DOC
      Usage: digest_cli [<crystal entrypoint>]

      Outputs a CSV of digested crystal source graphs, formatted as FILE,HASH
      Expects CRYSTAL_PATH and CRYSTAL_LIBRARY_PATH in the environment\n
      DOC

      parser.on("-s PATH", "--shard-lock=PATH", "Specify a shard.lock") do |path|
        abort("no shard.lock at #{path}") unless File.exists? path
        shard_lock = path
      end

      parser.on("-v", "--verbose", "Enable verbose logging") do
        ::Log.setup("*", :debug, PlaceOS::LogBackend.log_backend)
      end

      parser.unknown_args do |pre_dash, post_dash|
        pre_dash.each.chain(post_dash.each).each do |argument|
          path = Path[argument]
          if File.exists?(path)
            paths << path
          else
            STDERR.puts "#{path} #{"does not exist.".colorize.red}"
          end
        end
      end

      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit 0
      end
    end

    new(shard_lock).digest(paths).each { |v| puts v.join(',') }
  end

  getter shard_digest : Bytes?

  def initialize(shard_lock : String?)
    # Include the shard.lock (if there is one)
    if shard_lock
      @shard_digest = File.open(shard_lock) do |io|
        ::Digest::SHA1.digest &.update(io)
      end
    end
  end

  def digest(paths : Enumerable(Path))
    digests = Channel({Path, String}).new

    paths.each do |path|
      spawn do
        begin
          before = Time.utc
          digest = program_hash(path)
          after = Time.utc
          Log.trace { "digesting #{path} took #{(after - before).milliseconds}ms" } unless digests.closed?
          digests.send({path, digest}) rescue nil
        rescue e
          Log.error(exception: e) { "failed to digest #{path}" }
          digests.close
        end
      end
    end

    results = [] of {Path, String}
    paths.size.times do
      result = digests.receive?
      raise "digesting failed!" if result.nil?
      results << result
    end

    results
  end

  # Ignore the file if it is from the crystal lib
  # as `digest_cli` is using the compiler purely to compute requires.
  protected def crystal_file_hash?(path)
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

  def program_hash(entrypoint : String | Path)
    compiler = ::Crystal::Compiler.new.tap do |config|
      dev_null = File.open(File::NULL, "w")

      config.color = false
      config.no_codegen = true
      config.release = false
      config.wants_doc = false
      config.stderr = dev_null
      config.stdout = dev_null
    end

    # Compile and write output to /dev/null (or equivalent)
    result = compiler.top_level_semantic(source: ::Crystal::Compiler::Source.new(entrypoint.to_s, File.read(entrypoint)))

    # Calculate SHA-1 hash of entrypoint's requires
    Log.debug { "digesting #{entrypoint}" }
    futures = result.program.requires.map do |file|
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

  CRYSTAL_PATH         = self.validate_env!("CRYSTAL_PATH")
  CRYSTAL_LIBRARY_PATH = self.validate_env!("CRYSTAL_LIBRARY_PATH")

  protected def self.validate_env!(key)
    ENV[key]?.presence || abort("#{key} not present in environment")
  end
end

PlaceOS::Build::Digest::Cli.run
