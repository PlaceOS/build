require "./application"

module PlaceOS::Build::Api
  # Routes trigger builds and query the resulting artefacts.
  class Driver < Application
    base "/api/build/v1/driver"

    # Triggers a build of an object with as the entrypoint
    # Returns…
    #     200 if compiled, returning a stream of the binary
    #     500 if the object failed to compile, and error or build output
    #     404 if repository, entrypoint, or commit was not found
    # POST /build/<file>?url=<repository url>&commit=<commit hash>
    post("/:file", :trigger_build) do
      # TODO
    end

    # Returns the metadata extracted from the built artefact.
    #
    # GET /build/<file>/metadata?url=<repository url>&commit=<commit hash>
    get("/:file/metadata", :metadata) do
      # TODO
    end

    # Returns the docs extracted from the artefact.
    # This can be built independently of the artefact's compilation, so if not present, try to build the docs.
    # GET /build/<file>/docs?url=<repository url>&commit=<commit hash>
    get("/:file/docs", :documentation) do
      # TODO
    end

    # Compilation status of an artefact
    # 200 if compiled
    # 404 not compiled
    # GET /build/<file>/compiled?url=<repository url>&commit=<commit hash>
    get("/:file/compiled", :compiled?) do
      # TODO
    end
  end
end
