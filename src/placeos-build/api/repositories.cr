require "./application"

module PlaceOS::Build::Api
  # Routes to query git metadata.
  class Repositories < Application
    include ::OpenAPI::Generator::Controller
    include ::OpenAPI::Generator::Helpers::ActionController

    base "/api/build/v1/repository"

    delegate repository_store, to: Build::Api.builder

    # Parameters
    ###########################################################################

    getter count : Int32 do
      param count : Int32 = 50, "Limit on commits returned"
    end

    ###########################################################################

    # Returns the commits for a repository.
    # GET /repository?url=[repository url]&count=[commit count: 50]&branch=[master]
    get("/commits", :repository_commits, annotations: @[OpenAPI(<<-YAML
        summary: Returns the commit for a repository
        parameters:
          #{Schema.header_param("X-Git-Username", "An optional git username", required: false, type: "string")}
          #{Schema.header_param("X-Git-Password", "An optional git password", required: false, type: "string")}
      YAML
    )]) do
      query_store &.repository_commits?(repository_uri, count, branch, username: username, password: password)
    end

    # Returns the commits for a file.
    # GET /repository/<file>?url=[repository url]&count=[commit count: 50]&branch=[master]
    get("/commits/:file", :file_commits, annotations: @[OpenAPI(<<-YAML
        summary: Returns the commits for a file
        parameters:
          #{Schema.header_param("X-Git-Username", "An optional git username", required: false, type: "string")}
          #{Schema.header_param("X-Git-Password", "An optional git password", required: false, type: "string")}
      YAML
    )]) do
      file = params["file"]
      query_store &.file_commits?(file, repository_uri, count, branch, username: username, password: password)
    end

    # Returns the branches for a repository
    # GET /repository/branches?url=[repository url]
    get("/branches", :repository_branches, annotations: @[OpenAPI(<<-YAML
        summary: Returns the branches for a repository
        parameters:
          #{Schema.header_param("X-Git-Username", "An optional git username", required: false, type: "string")}
          #{Schema.header_param("X-Git-Password", "An optional git password", required: false, type: "string")}
      YAML
    )]) do
      query_store &.branches?(repository_uri, username: username, password: password)
    end

    # Returns an array of files containing driver implementations for a repository
    # GET /repository/discover/drivers?url=[repository url]&ref=[master]&commit=[HEAD]
    get("/discover/drivers", :discover_drivers, annotations: @[OpenAPI(<<-YAML
        summary: Returns the files containing PlaceOS driver implementations
        parameters:
          #{Schema.header_param("X-Git-Username", "An optional git username", required: false, type: "string")}
          #{Schema.header_param("X-Git-Password", "An optional git password", required: false, type: "string")}
      YAML
    )]) do
      ref = param ref : String? = nil, "Ref on remote to discover drivers from. Defaults to default branch HEAD"
      if drivers = Api::Repositories.discover_drivers?(repository_uri, ref, repository_path, username, password)
        render status_code: :ok, json: drivers
      else
        head code: :not_found
      end
    end

    def self.discover_drivers?(repository_uri, ref, repository_path, username, password)
      if (path = repository_path.presence) && Build.support_local_builds?
        Api.builder.local_discover_drivers?(Path[path].expand)
      else
        Api.builder.discover_drivers?(
          repository_uri,
          ref: ref,
          username: username,
          password: password,
        )
      end
    end

    protected def query_store
      if (result = yield repository_store)
        render status_code: :ok, json: result
      else
        head code: :not_found
      end
    end
  end
end
