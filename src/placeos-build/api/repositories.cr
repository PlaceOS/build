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

    getter repository_uri : String do
      param url : String, "URL for a git repository"
    end

    getter branch : String do
      param branch : String = "master", "Branch to return commits for"
    end

    getter count : Int32 do
      param count : Int32 = 50, "Limit on commits returned"
    end

    ###########################################################################

    # Returns the commits for a repository.
    # GET /repository?url=[repository url]&count=[commit count: 50]&branch=[master]
    get("/", :repository_commits, annotations: @[OpenAPI(<<-YAML
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

    protected def query_store
      if (result = yield repository_store)
        render status_code: :ok, json: result
      else
        head code: :not_found
      end
    end
  end
end
