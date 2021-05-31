module PlaceOS::Build
  describe Drivers do
    it "compiles a specific driver" do
      drivers = Drivers.new
      drivers.compile(
        repository_uri: "https://github.com/placeos/private-drivers",
        entrypoint: "drivers/place/private_helper.cr",
        commit: "c014d19225bb9aa2578494be797207c04745df39",
        crystal_version: "1.0.0",
      )
    end
  end
end
