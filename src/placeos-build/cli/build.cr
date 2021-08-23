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

      @[Clip::Doc("Disocover drivers and compile them")]
      getter discover : Bool = false

      @[Clip::Doc("URI of the git repository")]
      @[Clip::Option]
      getter repository_uri : String

      @[Clip::Doc("Commit to check the file out to")]
      @[Clip::Option]
      getter commit : String

      @[Clip::Doc("Branch to checkout")]
      @[Clip::Option]
      getter branch : String

      @[Clip::Doc("Driver entrypoints relative to specified repository")]
      @[Clip::Option]
      getter entrypoints : Array(String) = [] of String

      def run
        repository_store = RepositoryStore.new(repository_store_path)
        repository_path.try { |path| repository_store.link_existing(repository_uri, path) }

        driver_store = DriverStore.from_credentials(aws_credentials)
        builder = Drivers.new(driver_store, repository_store, strict_driver_info: strict_driver_info)

        valid_driver_entrypoints = drivers(builder)

        if valid_driver_entrypoints.empty?
          Log.info { "no valid driver entrypoints passed" }
          exit 0
        end

        valid_driver_entrypoints.each do |entrypoint|
          args = {entrypoint: entrypoint, commit: commit, crystal_version: crystal_version}
          begin
            if (path = repository_path)
              builder.local_compile(Path[path].expand, **args)
            else
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

      def drivers(builder : PlaceOS::Build::Drivers) : Array(String)
        valid_driver_entrypoints = entrypoints.compact_map do |file|
          builder.repository_store.with_repository(repository_uri, file, commit, branch, username, password) do |path|
            driver = path.join(file)
            if !File.exists?(driver)
              Log.warn { "#{driver} is not a file" }
              file = nil
            elsif !Build.is_driver?(driver)
              Log.warn { "#{driver} is not a driver" }
              file = nil
            end
            file
          end
        end

        if discover
          found = builder.discover_drivers?(repository_uri, branch, commit, username, password)
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
