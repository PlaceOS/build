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
      raise Build::Error.new("shard.yml does not exist at #{file}", cause: e)
    end

    # Extract the latest crystal version specified by `shard.yml` under `project_root`
    def self.extract_latest_crystal(project_root)
      requirement = extract_crystal_requirement(File.join(project_root, "shard.yml"))
      latest_version(requirement)
    end

    def self.install_latest
      install("latest")
    end

    def self.latest_version(requirement : Shards::VersionReq)
      latest = ::Shards::Versions.resolve(list_all_crystal, requirement).last?
      raise Error.new("could not resolve an existing crystal version for #{requirement}") if latest.nil?
      latest
    end

    def self.install_latest_matching(requirement : Shards::VersionReq)
      install(latest_version(requirement))
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

    # asdf
    #################################################################################################

    def self.current(directory : String = ".")
      result = ExecFrom.exec_from(directory, "asdf", {"current", "crystal"})
      raise Error.new(result.output) unless result.status.success?

      parts = result.output.to_s.chomp.split(/\s+/)
      raise Error.new("unexpected number of segments in `asdf current crystal` output") unless parts.size == 3
      Shards::Version.new(parts[1])
    end

    def self.current?
      current
    rescue e : Error
    end

    protected def self.asdf(*args)
      io = IO::Memory.new
      status = Process.run("asdf", args, output: io, error: io)
      {io, status}
    end

    def self.path?(version : Shards::Version | String) : String?
      version = version.value if version.is_a?(Shards::Version)

      output, status = asdf("where", "crystal", version)
      if status.success?
        root = output.to_s.chomp
        File.join(root, "bin/crystal")
      end
    end

    def self.local(version : Shards::Version | String, directory : String = ".") : Nil
      version = version.value if version.is_a?(Shards::Version)

      result = ExecFrom.exec_from(directory, "asdf", {"local", "crystal", version})
      raise Error.new(result.output) unless result.status.success?
    end

    def self.install(version : Shards::Version | String) : Nil
      version = version.value if version.is_a?(Shards::Version)

      output, status = asdf("install", "crystal", version)
      raise Error.new(output) unless status.success?
    end

    def self.list_all_crystal
      output, status = asdf("list", "all", "crystal")
      raise Error.new(output) unless status.success?
      extact_versions(output)
    end

    def self.list_crystal
      output, status = asdf("list", "crystal")
      raise Error.new(output) unless status.success?
      extact_versions(output)
    end

    private def self.extact_versions(io)
      io.to_s
        .each_line(chomp: true)
        .reject(&.empty?)
        .map { |l| Shards::Version.new(l.strip) }
        .to_a
    end
  end
end
