require "../api"
require "../drivers"
require "./application"

module PlaceOS::Build::Api
  # Routes trigger builds and query the resulting artefacts.
  class Driver < Application
    include ::OpenAPI::Generator::Controller
    include ::OpenAPI::Generator::Helpers::ActionController

    base "/api/build/v1/driver"

    delegate builder, to: Build::Api

    # Parameters
    ###########################################################################

    getter repository_uri : String do
      param url : String, "URL for a git repository"
    end

    getter commit : String do
      param commit : String = "HEAD", "Commit to checkout"
    end

    getter repository_path : String? do
      param repository_path : String? = nil, "Local path to a repository if `build` is configured to support builds referencing a path"
    end

    ###########################################################################

    DRIVER_HEADER_KEY = "x-placeos-driver-key"

    get("/", :query_drivers, annotations: @[OpenAPI(<<-YAML
        summary: Query the driver store for driver binaries.
      YAML
    )]) do
      file = param file : String? = nil, "Entrypoint of the driver"
      digest = param digest : String? = nil, "Digest of the driver"
      commit = param commit : String? = nil, "Commit of the driver"
      crystal_version = param crystal_version : String? = nil, "Crystal version of the binary"

      render status_code: :ok, json: builder.binary_store.query(file, digest, commit, crystal_version)
    end

    # TODO: Once crystal version varying is supported, we'll add that as an argument
    #
    # Returns…
    #     200 if compiled, returning a stream of the binary
    #     500 if the object failed to compile, and error or build output
    #     404 if repository, entrypoint, or commit was not found
    # POST /build/<file>?url=[repository url]&commit=[HEAD]
    post("/:file", :trigger_build, annotations: @[OpenAPI(<<-YAML
        summary: Triggers a build of an object with as the entrypoint
        parameters:
          #{Schema.header_param("X-Git-Username", "An optional git username", required: false, type: "string")}
          #{Schema.header_param("X-Git-Password", "An optional git password", required: false, type: "string")}
      YAML
    )]) do
      file = route_params["file"]
      force_recompile = param force_recompile : Bool = false, "Whether to force a build in case of existing binary"

      args = {entrypoint: file, commit: commit, crystal_version: CRYSTAL_VERSION, force_recompile: force_recompile}

      result = if (path = repository_path.presence) && Build.support_local_builds?
                 builder.local_compile(Path[path].expand, **args)
               else
                 builder.compile(repository_uri,
                   **args,
                   username: username,
                   password: password,
                 )
               end

      case result
      in Build::Compilation::NotFound
        head code: :not_found
      in Build::Compilation::Success
        response.content_type = "application/octet-stream"
        result.to_http_headers.each { |k, v| response.headers[k] = v }
        response.content_length = File.size(result.path)
        File.open(result.path) do |file_io|
          IO.copy(file_io, response)
        end
        head code: :ok
      in Build::Compilation::Failure
        render status_code: :internal_server_error, json: result
      end
    end

    # GET /build/<file>/metadata?url=[repository url]&commit=[HEAD]
    get("/:file/metadata", :metadata, annotations: @[OpenAPI(<<-YAML
        summary: Returns the metadata extracted from the built artefact.
        parameters:
          #{Schema.header_param("X-Git-Username", "An optional git username", required: false, type: "string")}
          #{Schema.header_param("X-Git-Password", "An optional git password", required: false, type: "string")}
      YAML
    )]) do
      file = route_params["file"]

      metadata = Api::Driver.metadata(repository_uri, file, commit, repository_path, username, password)

      if metadata
        render status_code: :ok, json: metadata
      else
        head code: :not_found
      end
    end

    # This can be built independently of the artefact's compilation, so if not present, try to build the docs.
    # GET /build/<file>/docs?url=[repository url]&commit=[HEAD]
    get("/:file/docs", :documentation, annotations: @[OpenAPI(<<-YAML
        summary: Returns the docs extracted from the artefact.
        parameters:
          #{Schema.header_param("X-Git-Username", "An optional git username", required: false, type: "string")}
          #{Schema.header_param("X-Git-Password", "An optional git password", required: false, type: "string")}
      YAML
    )]) do
      file = route_params["file"]

      metadata = Api::Driver.metadata(repository_uri, file, commit, repository_path, username, password)

      if metadata
        render status_code: :ok, json: metadata.documentation
      else
        head code: :not_found
      end
    end

    def self.metadata(repository_uri, entrypoint, commit, username, password, repository_path, crystal_version = CRYSTAL_VERSION)
      args = {entrypoint: entrypoint, commit: commit, crystal_version: crystal_version}

      if (path = repository_path.presence) && Build.support_local_builds?
        Api.builder.local_metadata?(Path[path].expand, **args)
      else
        Api.builder.metadata?(
          repository_uri,
          **args,
          username: username,
          password: password,
        )
      end
    end

    # TODO: Once crystal version varying is supported, we'll add that as an argument
    #
    # Compilation status of an artefact
    # 200 if compiled
    # 404 not compiled
    # GET /build/<file>/compiled?url=[repository url]&commit=[HEAD]
    get("/:file/compiled", :compiled?, annotations: @[OpenAPI(<<-YAML
        summary: Compilation status of an artefact
        parameters:
          #{Schema.header_param("X-Git-Username", "An optional git username", required: false, type: "string")}
          #{Schema.header_param("X-Git-Password", "An optional git password", required: false, type: "string")}
      YAML
    )]) do
      file = route_params["file"]

      if filename = Api::Driver.compiled(repository_uri, file, commit, repository_path, username, password)
        render status_code: :ok, json: filename
      else
        head code: :not_found
      end
    end

    def self.compiled(repository_uri, entrypoint, commit, repository_path, username, password, crystal_version = CRYSTAL_VERSION)
      args = {entrypoint: entrypoint, commit: commit, crystal_version: crystal_version}

      if (path = repository_path.presence) && Build.support_local_builds?
        Api.builder.local_compiled(Path[path].expand, **args)
      else
        Api.builder.compiled(
          repository_uri,
          **args,
          username: username,
          password: password,
        )
      end
    end
  end
end
