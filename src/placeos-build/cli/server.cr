module PlaceOS::Build
  abstract struct Cli
    @[Clip::Doc("Run as a REST API, see <TODO: link to openapi.yml>")]
    struct Server < Cli
      include Clip::Mapper

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

      @[Clip::Doc("Perform a basic health check by requesting the URL")]
      @[Clip::Option("-c", "--curl")]
      getter curl : String? = nil

      def run
        run_routes
        run_curl

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

      protected def run_curl
        return unless url = curl.presence
        response = HTTP::Client.get url
        exit 0 if (200..499).includes? response.status_code
        puts "health check failed, received response code #{response.status_code}"
        exit 1
      rescue error
        error.inspect_with_backtrace(STDOUT)
        exit 2
      end
    end
  end
end
