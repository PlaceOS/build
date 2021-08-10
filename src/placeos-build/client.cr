require "http"
require "json"
require "mutex"
require "placeos-models/version"
require "responsible"
require "retriable"
require "uri"
require "uuid"

require "../constants"
require "./compilation"
require "./error"
require "./executable"

module PlaceOS::Build
  class Client
    include Responsible

    BASE_PATH     = "/api/build"
    BUILD_VERSION = "v1"
    getter build_version : String

    getter host : String = ENV["PLACEOS_BUILD_HOST"]? || "localhost"
    getter port : Int32 = (ENV["PLACEOS_BUILD_PORT"]? || 3000).to_i

    # Primary use is for local use of build
    property repository_path : String? = nil

    # A one-shot `PlaceOS::Build::Client`
    def self.client
      client = new
      begin
        yield client
      ensure
        client.connection.close
      end
    end

    # :ditto:
    def self.client(uri : URI, build_version : String = BUILD_VERSION)
      client = new(uri, build_version)
      begin
        yield client
      ensure
        client.connection.close
      end
    end

    def initialize(uri : URI, @build_version : String = BUILD_VERSION)
      uri_host = uri.host.presence
      @host = uri_host if uri_host
      @port = uri.port || 3000
      @connection = HTTP::Client.new(uri)
      @connection.read_timeout = 6.minutes
    end

    def initialize(host : String? = nil, port : Int32? = nil, @build_version : String = BUILD_VERSION)
      @host = host if host && host.presence
      @port = port if port
      @connection = HTTP::Client.new(host: @host, port: @port)
      @connection.read_timeout = 6.minutes
    end

    # Root
    ###########################################################################

    # Healthcheck the service
    def healthcheck(request_id : String? = nil) : Bool
      get("/", raises: false, request_id: request_id).success?
    end

    # Returns the service's `PlaceOS::Model::Version`
    def version(request_id : String? = nil) : Model::Version
      parse_to_return_type do
        get("/version", request_id: request_id)
      end
    end

    # Repositories
    ###########################################################################

    # Returns the commits for a repository
    def repository_commits(
      url : String,
      branch : String = "master",
      count : Int32 = 50,
      username : String? = nil,
      password : String? = nil,
      request_id : String? = nil
    ) : Array(String)
      params = HTTP::Params{
        "url"    => url,
        "branch" => branch,
        "count"  => count.to_s,
      }

      if path = repository_path.presence
        params["repository_path"] = path
      end

      parse_to_return_type do
        get("/repository?#{params}", authorization_header(username, password), request_id: request_id)
      end
    end

    # Returns the commits for a file
    def file_commits(
      file : String,
      url : String,
      branch : String = "master",
      count : Int32 = 50,
      username : String? = nil,
      password : String? = nil,
      request_id : String? = nil
    ) : Array(String)
      params = HTTP::Params{
        "url"    => url,
        "branch" => branch,
        "count"  => count.to_s,
      }

      if path = repository_path.presence
        params["repository_path"] = path
      end

      parse_to_return_type do
        get("/repository/#{URI.encode_www_form(file)}?#{params}", authorization_header(username, password), request_id: request_id)
      end
    end

    # Returns the branches of a repository
    def branches(
      url : String,
      username : String? = nil,
      password : String? = nil,
      request_id : String? = nil
    ) : Array(String)
      params = HTTP::Params{
        "url" => url,
      }

      if path = repository_path.presence
        params["repository_path"] = path
      end

      parse_to_return_type do
        get("/repository/branches?#{params}", authorization_header(username, password), request_id: request_id)
      end
    end

    def discover_drivers(
      url : String,
      commit : String = "HEAD",
      branch : String = "master",
      username : String? = nil,
      password : String? = nil,
      request_id : String? = nil
    ) : Array(String)
      params = HTTP::Params{
        "url"    => url,
        "commit" => commit,
        "branch" => branch,
      }

      if path = repository_path.presence
        params["repository_path"] = path
      end

      parse_to_return_type do
        get("/repository/discover/drivers?#{params}", authorization_header(username, password), request_id: request_id)
      end
    end

    # Drivers
    ###########################################################################

    def query(
      file : String? = nil,
      digest : String? = nil,
      commit : String? = nil,
      crystal_version : String? = nil,
      request_id : String? = nil
    ) : Array(Executable)
      params = Hash(String, String?){
        "file"            => file,
        "digest"          => digest,
        "commit"          => commit,
        "crystal_version" => crystal_version,
      }.compact

      parse_to_return_type do
        get("/driver?#{HTTP::Params.encode params}", request_id: request_id)
      end
    end

    # Triggers a build of an object with as the entrypoint, yielding the build object
    def compile(
      file : String,
      url : String,
      commit : String,
      force_recompile : Bool = false,
      username : String? = nil,
      password : String? = nil,
      request_id : String? = nil,
      & : String, IO ->
    ) : Compilation::Result
      params = HTTP::Params{
        "url"             => url,
        "commit"          => commit,
        "force_recompile" => force_recompile.to_s,
      }

      if path = repository_path.presence
        params["repository_path"] = path
      end

      post("/driver/#{URI.encode_www_form(file)}?#{params}", authorization_header(username, password), request_id: request_id, raises: false, retries: 2) do |response|
        key = response.headers[DRIVER_HEADER_KEY]
        time = response.headers[DRIVER_HEADER_TIME].to_i64
        yield key, response.body_io
        Compilation::Success.new(key, time)
      end
    rescue e : Build::ClientError
      case e.response.status_code
      when 404 then Compilation::NotFound.new
      when 500 then Compilation::Failure.from_json(e.response.body)
      else
        raise e
      end
    end

    # Returns `Executable::Info` extracted from the built artefact
    def metadata(
      file : String,
      url : String,
      commit : String,
      username : String? = nil,
      password : String? = nil,
      request_id : String? = nil
    ) : Executable::Info
      params = HTTP::Params{
        "url"    => url,
        "commit" => commit,
      }
      if path = repository_path.presence
        params["repository_path"] = path
      end
      parse_to_return_type do
        get("/driver/#{URI.encode_www_form(file)}/metadata?#{params}", authorization_header(username, password), request_id: request_id)
      end
    end

    # Returns the documentation extracted from the built artefact
    def documentation(
      file : String,
      url : String,
      commit : String,
      username : String? = nil,
      password : String? = nil,
      request_id : String? = nil
    ) : String
      params = HTTP::Params{
        "url"    => url,
        "commit" => commit,
      }

      if path = repository_path.presence
        params["repository_path"] = path
      end

      parse_to_return_type do
        get("/driver/#{URI.encode_www_form(file)}/docs?#{params}", authorization_header(username, password), request_id: request_id)
      end
    end

    # Returns the compilation status of a built artefact
    def compiled(
      file : String,
      url : String,
      commit : String,
      username : String? = nil,
      password : String? = nil,
      request_id : String? = nil
    ) : String?
      parse_to_return_type do
        get("/driver/#{URI.encode_www_form(file)}/compiled", request_id: request_id, raises: false, retries: 1)
      end
    end

    # Helpers
    ###########################################################################

    protected def authorization_header(username, password)
      HTTP::Headers.new.tap do |headers|
        headers["X-Git-Username"] = username if username
        headers["X-Git-Password"] = password if password
      end
    end

    # Connection
    ###########################################################################

    protected getter connection : HTTP::Client
    protected getter connection_lock : Mutex = Mutex.new

    def close
      connection_lock.synchronize do
        connection.close
      end
    end

    # API modem
    ###########################################################################

    {% for method in %w(get post) %}
      # Executes a {{method.id.upcase}} request on build connection.
      #
      # The response status will be automatically checked and a `PlaceOS::Build::ClientError` raised if
      # unsuccessful and `raises` is `true`.
      private def {{method.id}}(path : String, headers : HTTP::Headers? = nil, body : HTTP::Client::BodyType? = nil, request_id : String? = nil, raises : Bool = true, retries : Int32 = 10) : HTTP::Client::Response
        {{method.id}}(path, headers, body, request_id, raises, retries) { |response| response }
      end

      # Executes a {{method.id.upcase}} request and yields a `HTTP::Client::Response`.
      #
      # When working with endpoint that provide stream responses these may be accessed as available
      # by calling `#body_io` on the yielded response object.
      #
      # The response status will be automatically checked and a `PlaceOS::Build::ClientError` raised if
      # unsuccessful and `raises` is `true`.
      private def {{method.id}}(path, headers : HTTP::Headers? = nil, body : HTTP::Client::BodyType = nil, request_id : String? = nil, raises : Bool = false, retries : Int32 = 10)
        headers ||= HTTP::Headers.new
        headers["Content-Type"] = "application/json"
        headers["X-Request-ID"] = request_id || UUID.random.to_s unless headers.has_key? "X-Request-ID"

        path = File.join(BASE_PATH, build_version, path)
        rewind_io = ->(e : Exception, _a : Int32, _t : Time::Span, _n : Time::Span) {
          Log.error(exception: e) { {method: {{ method }}, path: path, message: "failed to request build"} }
          body.rewind if body.responds_to? :rewind
        }
        Retriable.retry times: retries, max_interval: 1.minute, on_retry: rewind_io do
          connection_lock.synchronize do
            connection.{{method.id}}(path, headers, body) do |response|
              if response.success? || !raises
                yield response
              else
                raise Build::ClientError.from_response(path, response)
              end
            end
          end
        end
      end
    {% end %}
  end
end
