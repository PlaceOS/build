require "placeos-log-backend"

require "../driver_store/s3"

module PlaceOS::Build
  abstract struct Cli
    @[Clip::Doc("Run as a CLI. Mainly for use in continuous integration.")]
    struct Build < Cli
      include Clip::Mapper

      @[Clip::Doc("Path to existing repository")]
      getter repository_path : String? = nil

      @[Clip::Doc("Varying this is currently unsupported")]
      getter crystal_version : String = CRYSTAL_VERSION

      @[Clip::Doc("Where the git repositories are mounted")]
      getter repository_store_path : String = REPOSITORY_STORE_PATH

      @[Clip::Doc("Where the binaries are mounted")]
      getter binary_store_path : String = BINARY_STORE_PATH

      @[Clip::Doc("Username for git repository")]
      getter username : String? = nil

      @[Clip::Doc("Password for git repository")]
      getter password : String? = nil

      @[Clip::Doc("Extract driver info on build")]
      getter strict_driver_info : Bool = true

      @[Clip::Doc("Discover drivers and compile them")]
      getter discover : Bool = false

      @[Clip::Doc("URI of the git repository")]
      @[Clip::Option]
      getter repository_uri : String

      @[Clip::Doc("Ref to checkout")]
      @[Clip::Option]
      getter ref : String

      @[Clip::Doc("Driver entrypoints relative to specified repository")]
      @[Clip::Option]
      getter entrypoints : Array(String) = [] of String

      def run
        repository_store = RepositoryStore.new
        driver_store = DriverStore.from_credentials(aws_credentials)
        builder = Drivers.new(driver_store, repository_store, strict_driver_info: strict_driver_info)

        valid_driver_entrypoints = drivers(builder)

        abort("no valid driver entrypoints passed") if valid_driver_entrypoints.empty?

        valid_driver_entrypoints.each do |entrypoint|
          args = {entrypoint: entrypoint, commit: ref, crystal_version: crystal_version}
          ::Log.with_context(**args) do
            begin
              if (path = repository_path)
                Log.debug { "local compile" }
                builder.local_compile(Path[path].expand, **args)
              else
                Log.debug { "cloned compile" }
                builder.compile(repository_uri,
                  **args,
                  username: username,
                  password: password,
                )
              end
            rescue e
              Log.warn(exception: e) { "failed to compile #{entrypoint}" }
            end
          end
        end
      end

      def drivers(builder : PlaceOS::Build::Drivers) : Array(String)
        valid_driver_entrypoints = entrypoints.compact_map do |file|
          builder.repository_store.with_repository(repository_uri, ref, username, password) do |downloaded_repository|
            driver = downloaded_repository.path.join(file)
            if File.exists?(driver) && Build.is_driver?(driver)
              file
            else
              Log.warn { "#{driver} is not a driver" }
              nil
            end
          end
        end

        if discover
          found = if (path = repository_path)
                    builder.local_discover_drivers?(Path[path].expand)
                  else
                    builder.discover_drivers?(repository_uri, ref, username, password)
                  end
          valid_driver_entrypoints.concat(found).uniq! unless found.nil? || found.empty?
        end

        valid_driver_entrypoints
      end

      protected def self.is_driver?(path : Path)
        !path.to_s.ends_with?("_spec.cr") && File.read_lines(path).any? &.includes?("< PlaceOS::Driver")
      end
    end
  end
end
