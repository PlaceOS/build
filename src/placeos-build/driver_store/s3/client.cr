require "awscr-s3"
require "retriable"

module PlaceOS::Build
  class S3 < DriverStore
    abstract class Client
      alias ListObjectsV2 = Awscr::S3::Response::ListObjectsV2
      alias Object = Awscr::S3::Object

      abstract def can_write? : Bool

      abstract def copy(source : String, destination : String)
      abstract def list(prefix = nil, max_keys = nil) : Iterator(Object)
      abstract def read(key : String, & : IO ->)
      abstract def write(key : String, io : IO) : Nil
    end
  end
end
