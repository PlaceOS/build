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

  private EXECUTABLE_PATH = "./bin/digest_cli"

  # Expects the presence of `digest` binary under `bin` directory
  #
  def self.digest(entrypoints : Array(String), working_directory : String? = nil, shard_lock : String? = nil) : Array(Result)
    output = IO::Memory.new
    error = IO::Memory.new

    started = Time.utc
    entrypoints.unshift("-s", shard_lock.as(String)) if shard_lock
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
