module PlaceOS::Build
  abstract struct Cli
    @[Clip::Doc("Run as a CLI. Mainly for use in continuous integration.")]
    struct Build < Cli
      @[Clip::Argument]
      getter entrypoints : Array(String)

      def run
        super
        abort("Sorry, not implemented yet :(")
      end

      def drivers
        self.class.discover_drivers(entrypoints)
      end

      def self.discover_drivers(paths : Array(String)) : Array(String)
        paths.uniq.compact_map do |path|
          if !File.exists?(path)
            Log.warn { "#{path} is not a file" }
            path = nil
          elsif !is_driver?(path)
            Log.warn { "#{path} is not a driver" }
            path = nil
          end
          path
        end
      end

      protected def self.is_driver?(path)
        !path.ends_with?("_spec.cr") && File.read_lines(path).any? &.includes?("< PlaceOS::Driver")
      end
    end
  end
end
