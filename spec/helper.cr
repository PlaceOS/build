require "spec"
require "placeos-log-backend"
require "../src/placeos-build"
require "../src/placeos-build/*"

Spec.before_suite do
  ::Log.setup "place_os.*", :trace, PlaceOS::LogBackend.log_backend
end
