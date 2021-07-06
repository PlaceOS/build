require "clip"
require "log"

require "./constants"

module PlaceOS::Build
  def self.run
    if (command = Cli.parse).is_a? Clip::Mapper::Help
      puts command.help
      exit 1
    end

    command.run
  rescue e : Clip::Error
    puts e
    exit 1
  end

  @[Clip::Doc("A program to build PlaceOS Drivers")]
  abstract struct Cli
    include Clip::Mapper

    macro inherited
      include Clip::Mapper
      Log = ::Log.for({{ @type }})
    end

    @[Clip::Doc("Display the application version")]
    @[Clip::Option("-v", "--version")]
    getter version : Bool = false

    @[Clip::Doc("List the application environment")]
    @[Clip::Option("-e", "--env")]
    getter environment : Bool = false

    @[Clip::Doc("Perform a basic health check by requesting the URL")]
    @[Clip::Option("-c", "--curl")]
    getter curl : String? = nil

    # AWS configuration
    getter aws_region : String? = AWS_REGION
    getter aws_key : String? = AWS_KEY
    getter aws_secret : String? = AWS_SECRET
    getter aws_s3_bucket : String? = AWS_S3_BUCKET

    def self.aws_configuration
      {aws_region: aws_region, aws_key: aws_key, aws_secret: aws_secret, aws_s3_bucket: aws_s3_bucket}
    end

    Clip.add_commands({
      "build"  => Build,
      "server" => Server,
    })

    def run
      run_version
      run_environment
      run_curl
    end

    protected def run_version
      return unless version
      puts "#{APP_NAME} v#{VERSION}"
      exit 0
    end

    protected def run_environment
      return unless environment
      ENV.accessed.sort.each &->puts(String)
      exit 0
    end

    def run_curl
      return unless url = curl.presence
      response = HTTP::Client.get url
      exit 0 if (200..499).includes? response.status_code
      puts "health check failed, received response code #{response.status_code}"
      exit 1
    rescue error
      error.inspect_with_backtrace(STDOUT)
      exit 2
    end

    struct Base < Cli
    end

    @[Clip::Doc("Run as a REST API, see <TODO: link to openapi.yml>")]
    struct Server < Cli
      @[Clip::Doc("Specifies the server host")]
      getter host : String = "127.0.0.1"
      @[Clip::Doc("Specifies the server port")]
      getter port : Int32 = 3000

      @[Clip::Option("-w", "--workers")]
      @[Clip::Doc("Specifies the number of processes to handle requests")]
      getter workers : Int32 = 1

      @[Clip::Doc("List the application routes")]
      @[Clip::Option("-r", "--routes")]
      getter routes : Bool = false

      def run
        super
        run_routes

        # Load the routes
        puts "Launching #{APP_NAME} v#{VERSION} (#{BUILD_COMMIT} @ #{BUILD_TIME})"
        server = ActionController::Server.new(port, host)

        # Start clustering
        server.cluster(workers, "-w", "--workers") if workers > 1

        terminate = Proc(Signal, Nil).new do |signal|
          puts " > terminating gracefully"
          spawn(same_thread: true) { server.close }
          signal.ignore
        end

        # Detect ctr-c to shutdown gracefully
        Signal::INT.trap &terminate
        # Docker containers use the term signal
        Signal::TERM.trap &terminate

        # Start the server
        server.run do
          puts "Listening on #{server.print_addresses}"
          STDOUT.flush
        end

        # Shutdown message
        puts "#{APP_NAME} leaps through the veldt\n"
      end

      protected def run_routes
        return unless routes
        ActionController::Server.print_routes
        exit 0
      end
    end

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
