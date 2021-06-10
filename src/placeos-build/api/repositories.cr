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
      YAML
    )]) do
      repository_uri = param repository : String, "URL for a git repository"
      count = param count : Int32 = 50, "Limit on commits returned"
      query &.repository_commits?(repository_uri, count)
    end

    # Returns the branches for a repository
    # GET /repository/branches?url=[repository url]
    get("/branches", :repository_branches, annotations: @[OpenAPI(<<-YAML
        summary: Returns the branches for a repository
      YAML
    )]) do
      repository_uri = param repository : String, "URL for a git repository"
      query &.branches?(repository_uri)
    end

    # Returns the commits for a file.
    # GET /repository/<file>?url=[repository url]&count=[commit count: 50]&branch=[master]
    get("/commits/:file", :file_commits, annotations: @[OpenAPI(<<-YAML
        summary: Returns the commits for a file
      YAML
    )]) do
      file = params["file"]
      repository_uri = param repository : String, "URL for a git repository"
      count = param count : Int32 = 50, "Limit on commits returned"
      query &.file_commits?(file, repository_uri, count)
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
