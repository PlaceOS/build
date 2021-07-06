require "http"
require "json"
require "mutex"
require "responsible"
require "retriable"
require "uri"
require "uuid"
require "placeos-models/version"

require "./error"
require "./executable"

module PlaceOS::Build
  class Client
    include Responsible

    BASE_PATH     = "/api/build"
    BUILD_VERSION = "v1"

    getter build_version : String = BUILD_VERSION

    getter host : String = ENV["PLACEOS_BUILD_HOST"]? || "localhost"
    getter port : Int32 = (ENV["PLACEOS_BUILD_PORT"]? || 3000).to_i

    # Base struct for `PlaceOS::Build` responses
    private abstract struct BaseResponse
      include JSON::Serializable
    end

    # A one-shot `PlaceOS::Build::Client`
    def self.client(
      uri : URI,
      build_version : String = BUILD_VERSION
    )
      client = new(uri, build_version)
      begin
        response = yield client
      ensure
        client.connection.close
      end

      response
    end

    def initialize(
      uri : URI,
      @build_version : String = BUILD_VERSION
    )
      uri_host = uri.host
      @host = uri_host if uri_host
      @port = uri.port || 3000
      @connection = HTTP::Client.new(uri)
      @connection.read_timeout = 6.minutes
    end

    def initialize(
      host : String? = nil,
      port : Int32? = nil,
      @build_version : String = BUILD_VERSION
    )
      @host = host if host
      @port = port if port
      @connection = HTTP::Client.new(host: @host, port: @port)
      @connection.read_timeout = 6.minutes
    end

    protected getter connection : HTTP::Client
    protected getter connection_lock : Mutex = Mutex.new

    def close
      connection_lock.synchronize do
        connection.close
      end
    end

    # Root
    ###########################################################################

    # Healthcheck the service
    def healthcheck : Bool
      get("/", raises: false).success?
    end

    # Returns the service's `PlaceOS::Model::Version`
    def version : Model::Version
      parse_to_return_type do
        get("/version")
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
      password : String? = nil
    ) : Array(String)
      params = HTTP::Params{
        "url"    => url,
        "branch" => branch,
        "count"  => count.to_s,
      }
      parse_to_return_type do
        get("/repository?#{params}", authorization_header(username, password))
      end
    end

    # Returns the commits for a file
    def file_commits(
      file : String,
      url : String,
      branch : String = "master",
      count : Int32 = 50,
      username : String? = nil,
      password : String? = nil
    ) : Array(String)
      params = HTTP::Params{
        "url"    => url,
        "branch" => branch,
        "count"  => count.to_s,
      }
      parse_to_return_type do
        get("/repository/#{file}?#{params}", authorization_header(username, password))
      end
    end

    # Returns the branches of a repository
    def branches(
      url : String,
      username : String? = nil,
      password : String? = nil
    ) : Array(String)
      params = HTTP::Params{
        "url" => url,
      }
      parse_to_return_type do
        get("/repository/branches?#{params}", authorization_header(username, password))
      end
    end

    # Drivers
    ###########################################################################

    # Triggers a build of an object with as the entrypoint, yielding the build object
    def compile(
      file : String,
      url : String,
      commit : String,
      username : String? = nil,
      password : String? = nil
    )
      params = HTTP::Params{
        "url"    => url,
        "commit" => commit,
      }
      post("/driver/#{file}?#{params}", authorization_header(username, password)) do |response|
        yield reponse.body_io
      end
    end

    # Returns `Executable::Info` extracted from the built artefact
    def metadata(
      file : String,
      url : String,
      commit : String,
      username : String? = nil,
      password : String? = nil
    ) : Executable::Info
      params = HTTP::Params{
        "url"    => url,
        "commit" => commit,
      }
      parse_to_return_type do
        get("/driver/#{file}/metadata?#{params}", authorization_header(username, password))
      end
    end

    # Returns the documentation extracted from the built artefact
    def documentation(
      file : String,
      url : String,
      commit : String,
      username : String? = nil,
      password : String? = nil
    ) : String
      params = HTTP::Params{
        "url"    => url,
        "commit" => commit,
      }
      parse_to_return_type do
        get("/driver/#{file}/docs?#{params}", authorization_header(username, password))
      end
    end

    # Returns the compilation status of a built artefact
    def compiled?(
      file : String,
      url : String,
      commit : String,
      username : String? = nil,
      password : String? = nil
    )
      get("/driver/#{file}/compiled", raises: false).success?
    end

    # Helpers
    ###########################################################################

    protected def authorization_header(username, password)
      HTTP::Headers.new.tap do |headers|
        headers["X-Git-Username"] = username if username
        headers["X-Git-Password"] = password if password
      end
    end

    protected def request_id
      UUID.random.to_s
    end

    protected def base_headers(existing : HTTP::Headers? = nil)
      existing ||= HTTP::Headers.new
      existing["Content-Type"] = "application/json"
      existing["X-Request-ID"] = request_id unless existing.has_key? "X-Request-ID"
      existing
    end

    # API modem
    ###########################################################################

    {% for method in %w(get post) %}
      # Executes a {{method.id.upcase}} request on build connection.
      #
      # The response status will be automatically checked and a `PlaceOS::Build::ClientError` raised if
      # unsuccessful.
      # ```
      private def {{method.id}}(path, headers : HTTP::Headers? = nil, body : HTTP::Client::BodyType? = nil, raises : Bool = true)
        path = File.join(BASE_PATH, BUILD_VERSION, path)
        rewind_io = ->(e : Exception, _a : Int32, _t : Time::Span, _n : Time::Span) {
          Log.error(exception: e) { {method: {{ method.stringify }}, path: path, message: "failed to request build"} }
          body.rewind if body.responds_to? :rewind
        }

        Retriable.retry times: 10, max_interval: 1.minute, on_retry: rewind_io do
          response = connection_lock.synchronize do
            connection.{{method.id}}(path, base_headers(headers), body)
          end

          if response.success? || !raises
            response
          else
            raise Build::ClientError.from_response("#{@host}:#{@port}#{path}", response)
          end
        end
      end

      # Executes a {{method.id.upcase}} request and yields a `HTTP::Client::Response`.
      #
      # When working with endpoint that provide stream responses these may be accessed as available
      # by calling `#body_io` on the yielded response object.
      #
      # The response status will be automatically checked and a `PlaceOS::Build::ClientErrror` raised if
      # unsuccessful.
      private def {{method.id}}(path, headers : HTTP::Headers? = nil, body : HTTP::Client::BodyType = nil, raises : Bool = false)
        path = File.join(BASE_PATH, BUILD_VERSION, path)
        rewind_io = ->(e : Exception, _a : Int32, _t : Time::Span, _n : Time::Span) {
          Log.error(exception: e) { {method: {{ method.stringify }}, path: path, message: "failed to request build"} }
          body.rewind if body.responds_to? :rewind
        }
        Retriable.retry times: 10, max_interval: 1.minute, on_retry: rewind_io do
          connection_lock.synchronize do
            connection.{{method.id}}(path, base_headers(headers), body) do |response|
              if response.success? || !raises
                yield response
              else
                raise Build::ClientError.from_response("#{@host}:#{@port}#{path}", response) unless response.success?
              end
            end
          end
        end
      end
    {% end %}
  end
end
