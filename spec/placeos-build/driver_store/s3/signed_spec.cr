require "lz4"

require "../../../helper"
require "./responses"

module PlaceOS::Build
  describe S3::Signed do
    client = S3::Signed.new("placeos-drivers", "ap-southeast-2", "key", "secret")

    before_all do
      WebMock.allow_net_connect = false
      WebMock.reset
    end

    after_all do
      WebMock.allow_net_connect = true
    end

    describe "#read" do
      it "returns an object" do
        WebMock
          .stub(:get, "http://s3-ap-southeast-2.amazonaws.com/placeos-drivers/test.html")
          .to_return(body_io: IO::Memory.new)
        client.read("test.html") do |io|
          io.gets_to_end.should be_empty
        end
      end
    end

    describe "#list" do
      it "lists objects in the bucket" do
        WebMock
          .stub(:get, "http://s3-ap-southeast-2.amazonaws.com/placeos-drivers?list-type=2")
          .to_return(body: LIST_XML)
        client.list.should_not be_empty
      end
    end

    describe "#write" do
      it "writes bytes to a bucket" do
        value = "test"
        input = IO::Memory.new(value)
        expected = IO::Memory.new

        Compress::LZ4::Writer.open(expected) do |lz4|
          IO.copy(input, lz4)
        end

        WebMock
          .stub(:put, "http://s3-ap-southeast-2.amazonaws.com/placeos-drivers/test")
          .with(body: expected.to_s)
          .to_return(body: "", headers: {"ETag" => "s0m3th1ngs0m3th1ng"})
        client.write(value, IO::Memory.new(value))
      end
    end

    describe "#copy" do
      it "copies a file within a bucket" do
        WebMock
          .stub(:put, "http://s3-ap-southeast-2.amazonaws.com/placeos-drivers/destination")
          .with(body: "", headers: {"x-amz-copy-source" => "/placeos-drivers/source"})
          .to_return(body: COPY_XML)
        client.copy("source", "destination")
      end
    end
  end
end
