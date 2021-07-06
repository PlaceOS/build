require "../driver_store/s3"

module PlaceOS::Build
  abstract struct Cli
    @[Clip::Doc("Run as a CLI. Mainly for use in continuous integration.")]
    struct Build < Cli
      getter repository_uri : String
      getter commit : String
      getter branch : String

      @[Clip::Doc("Varying this is currently unsupported")]
      getter crystal_version : String = "1.0.0"

      getter repository_store_path : String = "./repositories"
      getter binary_store_path : String = "./bin/drivers"

      getter username : String? = nil
      getter password : String? = nil

      @[Clip::Doc("Extract driver info on build")]
      getter strict_driver_info : Bool = false

      @[Clip::Doc("Driver entrypoints relative to specified repository")]
      getter entrypoints : Array(String)

      def run
        super
        repository_store = RepositoryStore.new(repository_store_path)
        valid_driver_entrypoints = drivers(repository_store_path)

        if valid_driver_entrypoints.empty?
          Log.info { "no valid driver entrypoints passed" }
          exit 0
        end

        driver_store = DriverStore.from_credentials(aws_credentials)
        builder = Drivers.new(driver_store, repository_store, strict_driver_info: strict_driver_info)
        valid_driver_entrypoints.each do |entrypoint|
          begin
            builder.compile(
              repository_uri: repository_uri,
              entrypoint: entrypoint,
              commit: commit,
              crystal_version: crystal_version,
              username: username,
              password: password
            )
          rescue e
            Log.warn(exception: e) { "failed to compile #{entrypoint}" }
          end
        end
      end

      def drivers(store : RepositoryStore) : Array(String)
        entrypoints.compact_map do |file|
          store.with_repository(repository_uri, file, commit, branch) do |path|
            driver = path / file
            if !File.exists?(driver)
              Log.warn { "#{driver} is not a file" }
              file = nil
            elsif !is_driver?(driver)
              Log.warn { "#{driver} is not a driver" }
              file = nil
            end
            file
          end
        end
      end

      protected def self.is_driver?(path : Path)
        !path.to_s.ends_with?("_spec.cr") && File.read_lines(path).any? &.includes?("< PlaceOS::Driver")
      end
    end
  end
end
