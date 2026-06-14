#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"

REPO = ENV.fetch("GITHUB_REPOSITORY", "jaxassistant55/jax-micro-offer-studio")
DOCS = File.expand_path("../docs", __dir__)
CATALOG_PATH = File.join(DOCS, "paid-offer-action-catalog.json")
SITE = "https://jaxassistant55.github.io/jax-micro-offer-studio/"
PAYMENT_ACTIVATION = "#{SITE}payment-activation"
PROOF_MONITOR = "#{SITE}proof-monitor.html"
MARKER = "<!-- micro-offer-studio:buyer-response:v1 -->"
ASSISTANT_AUTHORS = %w[jaxassistant55 github-actions[bot]].freeze
RESPONSE_LABELS = {
  "buyer-response-sent" => ["6f42c1", "Autonomous safe buyer next-step response has been posted."],
  "payment-proof-needed" => ["fbca04", "External seller-owned payment or payout proof is still required."],
  "ready-for-seller-review" => ["0e8a16", "A real seller must review scope, payment route, and delivery boundary."]
}.freeze

def dry_run?
  %w[1 true yes].include?(ENV.fetch("DRY_RUN", "").downcase)
end

def token_env
  token = ENV["GH_TOKEN"] || ENV["GITHUB_TOKEN"]
  token.to_s.empty? ? {} : { "GH_TOKEN" => token }
end

def run_gh(*args, input: nil, allow_failure: false)
  stdout, stderr, status =
    if input.nil?
      Open3.capture3(token_env, "gh", *args)
    else
      Open3.capture3(token_env, "gh", *args, stdin_data: input)
    end
  return [stdout, stderr, status] if allow_failure || status.success?

  raise "gh #{args.join(" ")} failed: #{stderr.strip}"
end

def gh_json(*args)
  stdout, = run_gh(*args)
  JSON.parse(stdout)
end

def issue_from_event
  event_path = ENV["GITHUB_EVENT_PATH"].to_s
  return nil if event_path.empty? || !File.exist?(event_path)

  event = JSON.parse(File.read(event_path))
  event["issue"]
rescue JSON::ParserError
  nil
end

def issue_number
  [ENV["ISSUE_NUMBER"], ARGV[0]].map(&:to_s).find { |value| !value.empty? }
end

def fetch_issue(repo, number)
  gh_json("api", "repos/#{repo}/issues/#{number}")
end

def label_names(issue)
  issue.fetch("labels", []).map { |label| label.is_a?(Hash) ? label["name"].to_s : label.to_s }
end

def ready_issue?(issue)
  labels = label_names(issue).map(&:downcase)
  title = issue["title"].to_s.downcase
  labels.any? { |label| %w[ready-to-pay ready-to-buy].include?(label) } ||
    title.start_with?("ready to pay:") ||
    title.start_with?("ready to buy:")
end

def non_buyer_claim_text?(text)
  normalized = text.to_s.downcase
  return true if normalized.include?("/bounty")
  return true if normalized.include?("bounty:") && (normalized.include?("automated") || normalized.include?("ai agent") || normalized.include?("ai fix"))
  return true if normalized.include?("[ai fix]") && normalized.include?("order board:")
  return true if normalized.include?("[claim]") && (normalized.include?("bounty") || normalized.include?("wallet"))
  return true if normalized.include?("wallet") && normalized.include?("base usdc")

  false
end

def catalog_rows
  return [] unless File.exist?(CATALOG_PATH)

  JSON.parse(File.read(CATALOG_PATH)).fetch("rows", [])
rescue JSON::ParserError
  []
end

def repo_from_url(url)
  url.to_s.sub(%r{\Ahttps://github\.com/}, "").sub(%r{/(issues|pull)/.*\z}, "").sub(%r{/\z}, "")
end

def catalog_match(issue, repo)
  title = issue["title"].to_s.downcase
  body = issue["body"].to_s.downcase
  candidates = catalog_rows
  repo_candidates = candidates.select do |row|
    [row["repo_url"], row["structured_form_url"], row["order_board_url"], row["best_buyer_action_url"]].any? do |value|
      repo_from_url(value).casecmp?(repo)
    end
  end
  candidates = repo_candidates unless repo_candidates.empty?

  candidates.find do |row|
    row_title = row["title"].to_s.downcase
    row_id = row["catalog_row_id"].to_s.tr("-", " ").downcase
    (!row_title.empty? && (title.include?(row_title) || body.include?(row_title))) ||
      (!row_id.empty? && (title.include?(row_id) || body.include?(row_id)))
  end || candidates.first || {}
end

def existing_response?(repo, number)
  return false if dry_run?

  comments = gh_json("api", "repos/#{repo}/issues/#{number}/comments?per_page=100")
  comments.any? { |comment| comment["body"].to_s.include?(MARKER) }
end

def create_label_if_needed(repo, name, color, description)
  return if dry_run?

  _, stderr, status = run_gh(
    "api", "--method", "POST", "repos/#{repo}/labels",
    "-f", "name=#{name}",
    "-f", "color=#{color}",
    "-f", "description=#{description}",
    allow_failure: true
  )
  return if status.success? || stderr.include?("already_exists") || stderr.include?("Validation Failed")

  warn "Could not create label #{name}: #{stderr.strip}"
end

def add_labels(repo, number)
  return if dry_run?

  RESPONSE_LABELS.each { |name, (color, description)| create_label_if_needed(repo, name, color, description) }
  run_gh(
    "api", "--method", "POST", "repos/#{repo}/issues/#{number}/labels",
    "--input", "-",
    input: JSON.generate(labels: RESPONSE_LABELS.keys)
  )
end

def post_comment(repo, number, body)
  return if dry_run?

  run_gh(
    "api", "--method", "POST", "repos/#{repo}/issues/#{number}/comments",
    "--input", "-",
    input: JSON.generate(body: body)
  )
end

def response_body(issue, matched_row)
  offer = matched_row["title"].to_s.empty? ? "the selected Micro Offer Studio route" : matched_row["title"]
  price = matched_row["price"].to_s.empty? ? "the listed fixed price" : matched_row["price"]
  detail_url = matched_row["primary_url"].to_s.empty? ? "#{SITE}paid-offer-action-catalog.html" : matched_row["primary_url"]
  payment_url = matched_row["payment_activation_url"].to_s.empty? ? PAYMENT_ACTIVATION : matched_row["payment_activation_url"]
  proof_rule = matched_row["proof_rule"].to_s.empty? ? "Count $0 until a real buyer accepts scope, pays through a seller-owned external route, receives delivery, and payment is posted, released, payable, or cleared." : matched_row["proof_rule"]

  <<~MD
    #{MARKER}
    Thanks for opening a ready-to-pay or ready-to-buy request.

    Matched route: #{offer}
    Listed price: #{price}
    Offer page: #{detail_url}

    Exact next steps:
    1. Keep the scope public-safe in this issue. Do not post passwords, payment cards, tax identifiers, private regulated details, confidential files, or screenshots of payment accounts.
    2. Confirm the exact deliverable, deadline, acceptance proof, and any buyer-owned inputs that can safely be shared.
    3. Use the payment activation page only after scope or transfer terms are accepted: #{payment_url}
    4. Payment must happen through a seller-owned external checkout, invoice, marketplace order, payment request, or funded milestone. This GitHub issue is not a checkout and is not payment proof.
    5. After external payment is posted, released, payable, or cleared, the seller can deliver the private bundle or service output and record the proof in the monitor.

    Proof monitor: #{PROOF_MONITOR}

    Money rule: #{proof_rule}
  MD
end

def emit(result)
  puts JSON.pretty_generate(result)
end

issue = issue_from_event
number = issue_number
issue = fetch_issue(REPO, number) if number && (issue.nil? || issue["number"].to_s != number)

unless issue
  emit(status: "skipped", reason: "no_issue_context")
  exit 0
end

number = issue["number"].to_s
labels = label_names(issue)
author = issue.dig("user", "login").to_s
combined_text = [issue["title"], issue["body"], labels.join(" ")].join("\n")

if issue["pull_request"].is_a?(Hash)
  emit(status: "skipped", reason: "pull_request_not_buyer_issue", issue: number)
  exit 0
end

unless issue["state"].to_s == "open"
  emit(status: "skipped", reason: "issue_not_open", issue: number, state: issue["state"])
  exit 0
end

unless ready_issue?(issue)
  emit(status: "skipped", reason: "not_ready_to_pay_or_buy", issue: number, labels: labels)
  exit 0
end

if ASSISTANT_AUTHORS.include?(author)
  emit(status: "skipped", reason: "assistant_authored_issue", issue: number, author: author)
  exit 0
end

if non_buyer_claim_text?(combined_text)
  emit(status: "skipped", reason: "non_buyer_bounty_or_wallet_text", issue: number, author: author)
  exit 0
end

if labels.map(&:downcase).include?("buyer-response-sent") || existing_response?(REPO, number)
  emit(status: "skipped", reason: "response_already_present", issue: number)
  exit 0
end

matched_row = catalog_match(issue, REPO)
body = response_body(issue, matched_row)
post_comment(REPO, number, body)
add_labels(REPO, number)

emit(
  status: dry_run? ? "dry_run_ready_to_respond" : "responded",
  issue: number,
  author: author,
  matched_catalog_row: matched_row["catalog_row_id"],
  matched_title: matched_row["title"],
  labels_added: RESPONSE_LABELS.keys,
  comment_marker: MARKER
)
