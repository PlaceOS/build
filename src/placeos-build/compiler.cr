require "shards"
require "shards/moplnillo_solver"

require "./error"

module PlaceOS::Build::Compiler
  def source_crystal(version_range : String?)
    # Use the latest installed compiler
    if version_range.presence.nil?
    end
  end

  def self.list_installed_crystal
    io = IO::Memory.new
    result = Process.run("asdf", {"list", "crystal"}, stdout: io, stderr: io)
    raise Error.new(io.to_s) unless result.success?

    output
      .each_line
      .map { |l| Compiler.parse_crystal_version(l) }
      .to_a
  end

  def self.parse_crystal_version(crystal_version : String?) : Shards::VersionReq
    crystal_pattern =
      if crystal_version
        if crystal_version =~ /^(\d+)\.(\d+)(\.(\d+))?$/
          "~> #{$1}.#{$2}, >= #{crystal_version}"
        else
          crystal_version
        end
      else
        "< 1.0.0"
      end

    VersionReq.new(crystal_pattern)
  end
end
