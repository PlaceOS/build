require "../helper"

module PlaceOS::Build::Compiler
  describe Crystal do
    describe ".extract_crystal_requirement" do
      it "raises for non-existant shard.yml" do
        expect_raises(PlaceOS::Build::Error, /shard\.yml does not exist at does-not-exist/) do
          Crystal.extract_crystal_requirement("does-not-exist")
        end
      end

      it "extracts a version range" do
        io = IO::Memory.new("crystal: ~> 1.0")
        requirement = Crystal.extract_crystal_requirement(io)
        requirement.patterns.first.should eq "~> 1.0"
      end
    end

    describe ".path?" do
      it "lists the path for an installed crystal version" do
        Crystal.install("1.0.0")
        version = Crystal.current
        path = Crystal.path?(version.value)
        path.should_not be_nil
        path.not_nil!.should end_with("#{version.value}/bin/crystal")
      end

      it "returns null for non-installed crystal versions" do
        Crystal.path?("not-installed").should be_nil
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
