require "./application"

module PlaceOS::Build::Api
  # Routes to query git metadata.
  class Repositories < Application
    base "/api/build/v1/repository"

    getter repository_store : RepositoryStore { Api.builder.repository_store }

    # Returns the commits for a repository.
    # GET /repository?url=[repository url]&count=[commit count: 50]&branch=[master]
    get("/", :repository_commits, annotations: @[OpenAPI(<<-YAML
        summary: Returns the commit for a repository
        parameters:
          #{Schema.header_param("X-Git-Username", "An optional git username", required: false, type: "string")}
          #{Schema.header_param("X-Git-Password", "An optional git password", required: false, type: "string")}
      YAML
    )]) do
      repository_uri = param url : String, "URL for a git repository"
      branch = param branch : String = "master", "Branch to return commits for"
      count = param count : Int32 = 50, "Limit on commits returned"
      query &.repository_commits?(repository_uri, count, branch, username: username, password: password)
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
      repository_uri = param url : String, "URL for a git repository"
      branch = param branch : String = "master", "Branch to return commits for"
      count = param count : Int32 = 50, "Limit on commits returned"
      query &.file_commits?(file, repository_uri, count, branch, username: username, password: password)
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
      repository_uri = param url : String, "URL for a git repository"
      query &.branches?(repository_uri, username: username, password: password)
    end

    protected def query
      if (result = yield repository_store)
        render json: result
      else
        head :not_found
      end
    end
  end
end
