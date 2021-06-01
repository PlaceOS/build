require "./application"

module PlaceOS::Build::Api
  # Routes to query git metadata.
  class Repositories < Application
    base "/api/build/v1/repository"

    # Returns the commits for a repository.
    # GET /repository?url=[repository url]&count=[commit count: 50]&branch=[master]
    get("/", :repository_commits) do
      # TODO
    end

    # Returns the branches for a repository
    # GET /repository/branches?url=[repository url]
    get("/branches", :repository_branches) do
      # TODO
    end

    # Returns the commits for a file.
    # GET /repository/<file>?url=[repository url]&count=[commit count: 50]&branch=[master]
    get("/commits/:file", :file_commits) do
      # TODO
    end
  end
end
