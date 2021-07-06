require "./drivers"
require "./api/*"
require "./driver_store/s3"

module PlaceOS::Build::Api
  class_property credentials : S3::Credentials? = nil

  class_getter builder : Build::Drivers do
    Build::Drivers.new
  end
end
