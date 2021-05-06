require "shards/requirement"
require "shards/versions"
require "exec_from"
require "yaml"

require "./error"

module PlaceOS::Build::Compiler
  module Crystal
    Log = ::Log.for(self)

    # :nodoc:
    struct Shard
      include YAML::Serializable
      getter crystal : String?
    end

    # Extract the `crystal` keyinto a version requirement from a `shard.yml`
    #
    def self.extract_crystal_requirement(file : String | Path | IO) : Shards::VersionReq
      shard = case file
              in Path, String then File.open(file) { |io| Shard.from_yaml(io) }
              in IO           then Shard.from_yaml(file)
              end

      parse_crystal_version(shard.crystal)
    rescue e : File::NotFoundError
      raise Error.new("shard.yml does not exist at #{file}", cause: e)
    end

    def self.install_latest
      install("latest")
    end

    def self.install_latest_matching(requirement : Shards::VersionReq)
      latest = Shards::Version.resolve(list_all_crystal, requirement).last?
      raise Error.new("could not resolve an existing crystal version for #{requirement}") if latest.nil?
      install(latest)
    end

    def self.parse_crystal_version(crystal_version : String?) : Shards::VersionReq
      version = case crystal_version
                when /^(\d+)\.(\d+)(\.(\d+))?$/
                  "~> #{$1}.#{$2}, >= #{crystal_version}"
                when Nil
                  "< 1.0.0"
                when "*"
                  list_all_crystal.last.value
                else
                  crystal_version.as(String)
                end

      Shards::VersionReq.new version
    end

    # asdf methods
    #################################################################################################

    def self.current(directory : String = ".")
      io = IO::Memory.new
      result = ExecFrom.exec_from(directory, "asdf", {"current", "crystal", version})
      raise Error.new(result[:output].to_s) unless result[:exit_code].zero?

      parts = result[:output].to_s.split(/\s+/)
      raise Error.new("unexpected number of segments in `asdf current crystal` output") unless parts.size == 3
      Shards::Version.new(parts[1])
    end

    def self.current?
      current
    rescue e : Error
    end

    def self.local(version : Shards::Version | String, directory : String = ".") : Nil
      version = version.value if version.is_a?(Shards::Version)

      result = ExecFrom.exec_from(directory, "asdf", {"local", "crystal", version})
      raise Error.new(result[:output].to_s) unless result[:exit_code].zero?
    end

    def self.install(version : Shards::Version | String) : Nil
      version = version.value if version.is_a?(Shards::Version)

      io = IO::Memory.new
      result = Process.run("asdf", {"install", "crystal", version}, output: io, error: io)
      raise Error.new(io.to_s) unless result.success?
    end

    def self.list_all_crystal
      io = IO::Memory.new
      result = Process.run("asdf", {"list", "all", "crystal"}, output: io, error: io)
      raise Error.new(io.to_s) unless result.success?
      extact_versions(io)
    end

    def self.list_crystal
      io = IO::Memory.new
      result = Process.run("asdf", {"list", "crystal"}, output: io, error: io)
      raise Error.new(io.to_s) unless result.success?
      extact_versions(io)
    end

    private def self.extact_versions(io)
      io.to_s
        .each_line
        .map { |l| Shards::Version.new(l.strip) }
        .to_a
    end
  end
end
