require "../helper"

module PlaceOS::Build::Compiler
  describe Crystal do
    describe ".extract_crystal_requirement" do
      it "raises for non-existant shard.yml" do
        expect_raises(Error, "shard.yml does not exist at does-not-exist") do
          Crystal.extract_crystal_requirement("does-not-exist")
        end
      end

      it "extracts a version range" do
        io = IO::Memory.new("crystal: ~> 1.0")
        requirement = Crystal.extract_crystal_requirement(io)
        requirement.patterns.first.should eq "~> 1.0"
      end
    end

    describe ".install" do
      it "installs a crystal version" do
        Crystal.install_latest
        latest = Crystal.list_all_crystal.last
        Crystal.list_crystal.should contain(latest)
      end
    end

    describe ".local" do
      pending "sets the local compiler version"
    end
  end
end
