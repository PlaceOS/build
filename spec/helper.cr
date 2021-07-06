require "placeos-log-backend"
require "spec"
require "webmock"

require "../src/placeos-build"
require "../src/placeos-build/*"

Spec.before_suite do
  ::Log.setup do |builder|
    backend = PlaceOS::LogBackend.log_backend
    builder.bind "place_os.*", :trace, backend
    builder.bind "*", :trace, backend
  end
end

Spec.before_each do
  WebMock.allow_net_connect = true
end
