#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "json"
require "open3"
require "time"

ENV["TZ"] = "Asia/Tokyo"

REPO = "jaxassistant55/jax-micro-offer-studio"
LAUNCH_ROOT = File.expand_path("..", __dir__)
GENERATED_AT = Time.now.strftime("%Y-%m-%d %H:%M:%S JST")

def gh_json(path)
  stdout, stderr, status = Open3.capture3("gh", "api", path)
  raise stderr unless status.success?

  JSON.parse(stdout)
end

sources = [{
  "kind" => "main_board",
  "title" => "Available now: first paid $100+ micro-offer request",
  "issue_number" => "1",
  "issue_url" => "https://github.com/#{REPO}/issues/1",
  "price" => "various",
  "first_100_path" => "One accepted $100+ service or enough paid product transfers"
}]

order_boards_path = File.join(LAUNCH_ROOT, "order_boards.csv")
if File.exist?(order_boards_path)
  CSV.read(order_boards_path, headers: true).each do |row|
    sources << row.to_h.merge("kind" => "focused_order_board")
  end
end

rows = sources.map do |source|
  issue = gh_json("repos/#{REPO}/issues/#{source["issue_number"]}")
  comments = issue["comments"].to_i
  labels = issue["labels"].map { |label| label["name"] }.join("|")
  proof_status =
    if issue["state"] != "open"
      "issue_closed_review_required"
    elsif comments.zero?
      "no_buyer_comments_no_payment_proof"
    else
      "buyer_comments_present_manual_payment_review_required"
    end

  {
    "checked_at_jst" => GENERATED_AT,
    "kind" => source["kind"],
    "issue_number" => issue["number"],
    "title" => source["title"] || issue["title"],
    "price" => source["price"],
    "first_100_path" => source["first_100_path"],
    "issue_url" => issue["html_url"],
    "state" => issue["state"],
    "comments" => comments,
    "labels" => labels,
    "proof_status" => proof_status,
    "money_confirmed_usd" => "0",
    "money_count_rule" => "Count $0 unless external paid order, cleared invoice, funded milestone, payable balance, posted refund/credit, or equivalent proof exists."
  }
end

CSV.open(File.join(LAUNCH_ROOT, "proof_monitor.csv"), "w", write_headers: true, headers: rows.first.keys) do |csv|
  rows.each { |row| csv << row.values_at(*rows.first.keys) }
end

puts "Wrote #{rows.length} proof-monitor rows to #{File.join(LAUNCH_ROOT, "proof_monitor.csv")}"
