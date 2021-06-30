require "./drivers"
require "./api/*"

module PlaceOS::Build::Api
  class_getter builder : Build::Drivers do
    Build::Drivers.new
  end
end
