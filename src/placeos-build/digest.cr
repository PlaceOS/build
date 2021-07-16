require "log"

require "./error"

module PlaceOS::Build::Digest
  Log = ::Log.for(self)

  record Result, path : String, hash : String do
    def self.from_line?(line : String)
      path, hash = line.split(',')
      Result.new(path, hash)
    rescue e
      Log.error(exception: e) { "failed to parse #{line}" }
      nil
    end
  end

  private EXECUTABLE_PATH = Path["./bin/digest_cli"].expand.to_s

  def self.requires(entrypoints : Array(String), working_directory : String? = nil)
    output = IO::Memory.new
    error = IO::Memory.new

    entrypoints = entrypoints.dup
    entrypoints.unshift("requires")
    started = Time.utc
    unless Process.run(EXECUTABLE_PATH, entrypoints, chdir: working_directory, output: output, error: error).success?
      raise Build::Error.new("failed to extract requires: #{error}")
    end
    Log.debug { "extracting requires from #{entrypoints.join(", ")} took #{(Time.utc - started).milliseconds}ms" }

    output
      .rewind
      .read_lines(chomp: true)
  end

  # Expects the presence of `digest` binary under `bin` directory
  #
  def self.digest(entrypoints : Array(String), working_directory : String? = nil, shard_lock : String? = nil) : Array(Result)
    output = IO::Memory.new
    error = IO::Memory.new

    entrypoints = entrypoints.dup
    entrypoints.unshift("-s", shard_lock.as(String)) if shard_lock
    entrypoints.unshift("digest")
    started = Time.utc
    unless Process.run(EXECUTABLE_PATH, entrypoints, chdir: working_directory, output: output, error: error).success?
      raise Build::Error.new("failed to digest: #{error}")
    end

    Log.debug { "digesting #{entrypoints.join(", ")} took #{(Time.utc - started).milliseconds}ms" }

    output
      .rewind
      .each_line(chomp: true)
      .compact_map(&->Result.from_line?(String))
      .to_a
  end
end
