require "digest/sha1"
require "compiler/crystal/**"

module PlaceOS::Build
  Log = ::Log.for(self)

  def self.digest(paths : Enumerable(Path), verbose : Bool)
    digests = Channel({Path, String}).new(5)

    paths.each do |path|
      spawn do
        begin
          before = Time.utc
          digest = PlaceOS::Build.source_hash(path)
          after = Time.utc
          puts "digesting #{path} took #{(after - before).seconds}s" if verbose && !digests.closed?
          digests.send({path, digest}) rescue nil
        rescue e
          puts e.inspect_with_backtrace
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

  def self.source_hash(path : String | Path)
    validate_compiler_env!

    # Compile and write output to /dev/null (or equivalent)
    result = ::Crystal::Program.new.host_compiler.compile(source: ::Crystal::Compiler::Source.new(path.to_s, File.read(path)), output_filename: File::NULL)
    # Calculate SHA-1 hash of entrypoint's requires
    Log.debug { "digesting #{path}" }
    sha = result.program.requires.each_with_object(::Digest::SHA1.new) do |file, digest|
      puts "> #{file}"
      digest.file(file)
    end

    # Include the entrypoint in the hash
    sha.file(path)

    sha.final.hexstring
  end

  protected def self.validate_compiler_env!
    {"CRYSTAL_PATH", "CRYSTAL_LIBRARY_PATH"}.each do |key|
      ENV[key]? || abort("#{key} not present in environment")
    end
    nil
  end
end

paths = [] of Path
verbose = false

# Command line options
OptionParser.parse(ARGV.dup) do |parser|
  parser.banner = <<-DOC
  Usage: source_digest [<crystal entrypoint>]

  Outputs a CSV, formatted as FILE,HASH
  Expects CRYSTAL_PATH and CRYSTAL_LIBRARY_PATH in the environment
  DOC

  parser.on("-v", "--verbose", "Add some statistics") { verbose = true }

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

PlaceOS::Build.digest(paths, verbose).each { |v| puts v.join(',') }
