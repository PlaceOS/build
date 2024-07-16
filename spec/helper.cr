require "placeos-log-backend"
require "spec"
require "webmock"

require "action-controller/spec_helper"

Spec.before_suite do
  WebMock.allow_net_connect = true
  backend = PlaceOS::LogBackend::STDOUT
  Log.builder.bind "place_os.*", :trace, backend
  Log.builder.bind "*", :trace, backend
  Log.builder.bind "raven", :warn, backend
end

require "../src/config"
require "../src/placeos-build"
require "../src/placeos-build/*"
