#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "digest"
require "json"
require "net/http"
require "time"
require "uri"

ENV["TZ"] = "Asia/Tokyo"

launch_root = File.expand_path("..", __dir__)
payload_path = File.join(launch_root, "docs", "indexnow_payload.json")
endpoint = URI(ARGV[0] || "https://api.indexnow.org/indexnow")
payload = JSON.parse(File.read(payload_path))
body = JSON.generate(payload)

request = Net::HTTP::Post.new(endpoint)
request["Content-Type"] = "application/json; charset=utf-8"
request.body = body

response = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: endpoint.scheme == "https") do |http|
  http.request(request)
end

log_path = File.join(launch_root, "indexnow_submission_log.csv")
write_headers = !File.exist?(log_path)
CSV.open(log_path, "a", write_headers: write_headers, headers: %w[
  submitted_at_jst
  endpoint
  http_code
  response_message
  response_body
  host
  key_location
  url_count
  payload_sha256
]) do |csv|
  csv << [
    Time.now.strftime("%Y-%m-%d %H:%M:%S JST"),
    endpoint.to_s,
    response.code,
    response.message,
    response.body.to_s.strip,
    payload["host"],
    payload["keyLocation"],
    payload["urlList"].length,
    Digest::SHA256.hexdigest(body)
  ]
end

puts JSON.pretty_generate(
  endpoint: endpoint.to_s,
  http_code: response.code.to_i,
  response_message: response.message,
  response_body: response.body.to_s.strip,
  host: payload["host"],
  key_location: payload["keyLocation"],
  url_count: payload["urlList"].length,
  payload_sha256: Digest::SHA256.hexdigest(body),
  log_path: log_path
)

exit(response.code.to_i.between?(200, 202) ? 0 : 1)
