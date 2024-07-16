require "../api"
require "../drivers"
require "./application"

module PlaceOS::Build::Api
  # Routes trigger builds and query the resulting artefacts.
  class Driver < Application
    base "/api/build/v1/driver"

    delegate builder, to: Build::Api

    ###########################################################################

    # Query the driver store for driver binaries.
    @[AC::Route::GET("/")]
    def query_drivers(
      @[AC::Param::Info(description: "Entrypoint of the driver", example: "driver/place/bookings.cr")]
      file : String? = nil,
      @[AC::Param::Info(description: "Digest of the driver", example: "acb23af")]
      digest : String? = nil,
      @[AC::Param::Info(description: "Commit of the driver", example: "HEAD")]
      commit : String? = nil,
      @[AC::Param::Info(description: "Crystal version of the binary", example: "1.2.0")]
      crystal_version : String? = nil,
    ) : Array(PlaceOS::Model::Executable)
      builder.binary_store.query(file, digest, commit, crystal_version)
    end

    # Triggers a build of an object with as the entrypoint
    #
    # Returns…
    #     200 if compiled, returning a stream of the binary
    #     404 if repository, entrypoint, or commit was not found
    #     422 if the object failed to compile, and error or build output
    @[AC::Route::POST("/:file")]
    def trigger_build(
      @[AC::Param::Info(description: "URL for a git repository")]
      url : String,
      @[AC::Param::Info(description: "Entrypoint of the driver", example: "driver/place/bookings.cr")]
      file : String? = nil,
      @[AC::Param::Info(description: "Branch to return commits for")]
      branch : String? = nil,
      @[AC::Param::Info(description: "Commit of the driver", example: "HEAD")]
      commit : String = "HEAD",
      @[AC::Param::Info(description: "Local path to a repository if 'build' is configured to support builds referencing a path")]
      repository_path : String? = nil,
      @[AC::Param::Info(description: "Whether to force a build in case of existing binary")]
      force_recompile : Bool = false
    ) : Nil
      args = {entrypoint: file, commit: commit, crystal_version: CRYSTAL_VERSION, force_recompile: force_recompile}
      Log.context.set(**args)

      result = if (path = repository_path.presence) && Build.support_local_builds?
                 builder.local_compile(Path[path].expand, **args)
               else
                 builder.compile(url,
                   **args,
                   username: username,
                   password: password,
                 )
               end

      case result
      in Build::Compilation::NotFound
        raise AC::Error::NotFound.new("could not find file")
      in Build::Compilation::Success
        if !BUILD_SERVICE_DISABLED
          PlaceOS::Build.call_cloud_build_service(url, branch || "HEAD", file, commit, username: username, password: password)
        end
        path = builder.binary_store.path(result.executable)

        response.content_type = "application/octet-stream"
        response.headers.merge! result.to_http_headers
        response.content_length = File.size(path)
        response.status_code = 200
        @__render_called__ = true

        File.open(path) do |file_io|
          IO.copy(file_io, response)
        end
      in Build::Compilation::Failure
        raise AC::Error::Failure.new(result.error)
      end
    end

    # Returns the metadata extracted from the built artefact.
    @[AC::Route::GET("/:file/metadata")]
    def metadata(
      @[AC::Param::Info(description: "URL for a git repository")]
      url : String,
      @[AC::Param::Info(description: "Entrypoint of the driver", example: "driver/place/bookings.cr")]
      file : String? = nil,
      @[AC::Param::Info(description: "Commit of the driver", example: "HEAD")]
      commit : String = "HEAD",
      @[AC::Param::Info(description: "Local path to a repository if 'build' is configured to support builds referencing a path")]
      repository_path : String? = nil
    ) : PlaceOS::Model::Executable::Info
      metadata = Api::Driver.metadata(url, file, commit, repository_path, username, password)
      raise AC::Error::NotFound.new("no metadata found") unless metadata
      metadata
    end

    # Returns the docs extracted from the artefact.
    #
    # This can be built independently of the artefact's compilation, so if not present, try to build the docs.
    @[AC::Route::GET("/:file/docs")]
    def documentation(
      @[AC::Param::Info(description: "URL for a git repository")]
      url : String,
      @[AC::Param::Info(description: "Entrypoint of the driver", example: "driver/place/bookings.cr")]
      file : String? = nil,
      @[AC::Param::Info(description: "Commit of the driver", example: "HEAD")]
      commit : String = "HEAD",
      @[AC::Param::Info(description: "Local path to a repository if 'build' is configured to support builds referencing a path")]
      repository_path : String? = nil
    ) : String
      metadata = Api::Driver.metadata(url, file, commit, username, password, repository_path)
      raise AC::Error::NotFound.new("no metadata found") unless metadata
      metadata.documentation
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

    # Compilation status of an artefact
    #
    # 200 if compiled
    # 404 not compiled
    @[AC::Route::GET("/:file/compiled")]
    def compiled?(
      @[AC::Param::Info(description: "URL for a git repository")]
      url : String,
      @[AC::Param::Info(description: "Entrypoint of the driver", example: "driver/place/bookings.cr")]
      file : String? = nil,
      @[AC::Param::Info(description: "Commit of the driver", example: "HEAD")]
      commit : String = "HEAD",
      @[AC::Param::Info(description: "Local path to a repository if 'build' is configured to support builds referencing a path")]
      repository_path : String? = nil
    ) : NamedTuple(filename: String)
      filename = Api::Driver.compiled(url, file, commit, repository_path, username, password)
      raise AC::Error::NotFound.new("file not found") unless filename
      {filename: filename}
    end

    def self.compiled(repository_uri, entrypoint, ref, repository_path, username, password, crystal_version = CRYSTAL_VERSION)
      args = {entrypoint: entrypoint, ref: ref, crystal_version: crystal_version}

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
