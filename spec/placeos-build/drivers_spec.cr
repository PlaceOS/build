module PlaceOS::Build
  describe Drivers do
    it "compiles a crystal binary specificed by an entrypoint" do
      Drivers.legacy_build_method = false
      Drivers.new.compile(
        repository_uri: "https://github.com/place-labs/exec_from",
        entrypoint: "src/app.cr",
        commit: "da824d2a59f7e29eea6525f472ffc67c294a48cf",
        crystal_version: "1.0.0",
      )
    end

    it "compiles drivers via the legacy ENV method" do
      Drivers.legacy_build_method = true
      Drivers.new.compile(
        repository_uri: "https://github.com/placeos/private-drivers",
        entrypoint: "drivers/place/private_helper.cr",
        commit: "c014d19225bb9aa2578494be797207c04745df39",
        crystal_version: "1.0.0",
      )
    end
  end
end
