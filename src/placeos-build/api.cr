require "./drivers"
require "./api/*"
require "./driver_store/s3"

module PlaceOS::Build::Api
  class_property credentials : S3::Credentials? = S3.credentials(
    aws_region: AWS_REGION,
    aws_key: AWS_KEY,
    aws_secret: AWS_SECRET,
    aws_s3_bucket: AWS_S3_BUCKET
  )

  class_getter builder : Build::Drivers do
    Build::Drivers.new(DriverStore.from_credentials(credentials))
  end
end
