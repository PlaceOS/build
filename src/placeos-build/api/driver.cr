require "./application"
require "../drivers"

module PlaceOS::Build::Api
  # Routes trigger builds and query the resulting artefacts.
  class Driver < Application
    base "/api/build/v1/driver"

    getter builder : Build::Drivers { Api.builder }

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
      file = params["file"]
      repository_uri = param url : String, "URL for a git repository"
      commit = param branch : String = "HEAD", "Commit to checkout"
      result = builder.compile(
        repository_uri,
        file,
        commit,
        crystal_version: nil,
        username: username,
        password: password
      )

      case result
      in NotFound
        head :not_found
      in CompilationSuccess
        response.content_type = "application/octet-stream"
        response.content_length = File.size(result.path)
        File.open(result.path) do |file_io|
          IO.copy(file_io, response)
        end
        head :ok
      in CompilationFailure
        render :internal_server_error, json: result
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
      file = params["file"]
      repository_uri = param url : String, "URL for a git repository"
      commit = param branch : String = "HEAD", "Commit to checkout"

      metadata = builder.metadata?(repository_uri, file, commit, username: username, password: password)
      if metadata
        render json: metadata
      else
        head :not_found
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
      file = params["file"]
      repository_uri = param url : String, "URL for a git repository"
      commit = param branch : String = "HEAD", "Commit to checkout"
      metadata = builder.metadata?(repository_uri, file, commit, username: username, password: password)

      if metadata
        render json: metadata.documentation
      else
        head :not_found
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
      file = params["file"]
      repository_uri = param url : String, "URL for a git repository"
      commit = param branch : String = "HEAD", "Commit to checkout"
      head builder.compiled?(repository_uri, file, commit, username: username, password: password) ? HTTP::Status::OK : HTTP::Status::NOT_FOUND
    end
  end
end
