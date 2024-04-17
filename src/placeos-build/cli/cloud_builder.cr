require "http/client"
require "uri"
require "http/headers"
require "git-repository"

module PlaceOS::Build
  def self.call_cloud_build_service(repository_uri : String, branch : String, entrypoint : String, ref : String, username : String?, password : String?)
    repo = GitRepository.new(repository_uri, username: username, password: password)
    commit = repo.commits(branch, entrypoint, depth: 1).try &.first.commit || ref

    headers = HTTP::Headers.new
    if token = BUILD_GIT_TOKEN
      headers["X-Git-Token"] = token
    elsif (user = username) && (pwd = password)
      headers["X-Git-Username"] = user
      headers["X-Git-Password"] = pwd
    end
    uri = URI.encode_www_form(entrypoint)
    params = HTTP::Params{
      "url"    => repository_uri,
      "branch" => branch,
      "commit" => commit,
    }

    client = HTTP::Client.new(URI.parse(BUILD_SERVICE_URL))
    begin
      ["amd64", "arm64"].each do |arch|
        Log.debug { "Sending #{entrypoint} compilation request for architecture #{arch}" }
        resp = client.post("/api/build/v1/#{arch}/#{uri}?#{params}", headers: headers)
        unless resp.status_code == 202
          Log.warn { "Compilation request for #{arch} returned status code #{resp.status_code}, while 202 expected" }
          Log.debug { "Cloud build service returned with response: #{resp.body}" }
        end
      end
    rescue e
      Log.warn(exception: e) { "failed to invoke cloud build service #{entrypoint}" }
    end
  end
end
