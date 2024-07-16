require "./application"

module PlaceOS::Build::Api
  # Routes to query git metadata.
  class Repositories < Application
    base "/api/build/v1/repository"

    delegate repository_store, to: Build::Api.builder

    ###########################################################################

    # Returns the commit for a repository
    @[AC::Route::GET("/commits")]
    def repository_commits(
      @[AC::Param::Info(description: "URL for a git repository")]
      url : String,
      @[AC::Param::Info(description: "Limit on commits returned")]
      count : Int32 = 50,
      @[AC::Param::Info(description: "Branch to return commits for")]
      branch : String? = nil
    ) : Array(GitRepository::Commit)
      query_store &.repository_commits?(url, count, branch, username: username, password: password)
    end

    # Returns the commits for a file.
    @[AC::Route::GET("/commits/:file")]
    def file_commits(
      @[AC::Param::Info(description: "Entrypoint of the driver", example: "driver/place/bookings.cr")]
      file : String,
      @[AC::Param::Info(description: "URL for a git repository")]
      url : String,
      @[AC::Param::Info(description: "Limit on commits returned")]
      count : Int32 = 50,
      @[AC::Param::Info(description: "Branch to return commits for")]
      branch : String? = nil
    ) : Array(GitRepository::Commit)
      query_store &.file_commits?(file, url, count, branch, username: username, password: password)
    end

    # Returns the branches for a repository
    @[AC::Route::GET("/branches")]
    def repository_branches(
      @[AC::Param::Info(description: "URL for a git repository")]
      url : String
    ) : Array(String)
      query_store &.branches?(url, username: username, password: password)
    end

    # Returns an array of files containing driver implementations for a repository
    @[AC::Route::GET("/discover/drivers")]
    def discover_drivers(
      @[AC::Param::Info(description: "URL for a git repository")]
      url : String,
      @[AC::Param::Info(description: "Local path to a repository if 'build' is configured to support builds referencing a path")]
      repository_path : String? = nil,
      @[AC::Param::Info(description: "Ref on remote to discover drivers from. Defaults to default branch HEAD")]
      ref : String? = nil
    ) : Array(String)
      drivers = Api::Repositories.discover_drivers?(url, ref, repository_path, username, password)
      raise AC::Error::NotFound.new("no drivers found") unless drivers
      drivers
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
      result = yield repository_store
      raise AC::Error::NotFound.new("not found") unless result
      result
    end
  end
end
