require "compiler/crystal/**"
require "digest/sha1"
require "future"

require "placeos-log-backend"

class PlaceOS::Build::Digest
  Log = ::Log.for(self)

  def initialize
  end

  def digest(paths : Enumerable(Path))
    digests = Channel({Path, String}).new

    paths.each do |path|
      spawn do
        begin
          before = Time.utc
          digest = program_hash(path)
          after = Time.utc
          Log.trace { "digesting #{path} took #{(after - before).seconds}s" } unless digests.closed?
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
    compiler = ::Crystal::Program.new.host_compiler.tap do |config|
      config.release = false
      config.no_codegen = true
      config.wants_doc = false
    end

    # Compile and write output to /dev/null (or equivalent)
    result = compiler.compile(source: ::Crystal::Compiler::Source.new(entrypoint.to_s, File.read(entrypoint)), output_filename: File::NULL)

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
    end
  end

  CRYSTAL_PATH         = self.validate_env!("CRYSTAL_PATH")
  CRYSTAL_LIBRARY_PATH = self.validate_env!("CRYSTAL_LIBRARY_PATH")

  protected def self.validate_env!(key)
    ENV[key]?.presence || abort("#{key} not present in environment")
  end
end

paths = [] of Path

# Command line options
OptionParser.parse(ARGV.dup) do |parser|
  parser.banner = <<-DOC
  Usage: digest [<crystal entrypoint>]

  Outputs a CSV, formatted as FILE,HASH
  Expects CRYSTAL_PATH and CRYSTAL_LIBRARY_PATH in the environment
  DOC

  parser.on("-v", "--verbose", "Add some statistics") do
    Log.setup("*", :debug, PlaceOS::LogBackend.log_backend)
  end

  parser.unknown_args do |pre_dash, post_dash|
    pre_dash.each.chain(post_dash.each).each do |argument|
      path = Path[argument]
      if File.exists?(path)
        paths << path
      else
        STDERR << path.to_s << " does not exist.\n"
      end
    end
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit 0
  end
end

PlaceOS::Build::Digest.new.digest(paths).each { |v| puts v.join(',') }
