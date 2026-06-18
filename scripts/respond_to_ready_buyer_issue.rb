#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "csv"
require "open3"

REPO = ENV.fetch("GITHUB_REPOSITORY", "jaxassistant55/jax-micro-offer-studio")
DOCS = File.expand_path("../docs", __dir__)
CATALOG_PATH = File.join(DOCS, "paid-offer-action-catalog.json")
PAYMENT_PACKETS_PATH = File.join(DOCS, "one-sale-payment-packets.csv")
SITE = "https://jaxassistant55.github.io/jax-micro-offer-studio/"
PAYMENT_ACTIVATION = "#{SITE}payment-activation"
ONE_SALE_PAYMENT_PACKETS = "#{SITE}one-sale-payment-packets.html"
SAMPLE_GALLERY = "https://jaxassistant55.github.io/jax-micro-offer-studio/one-sale-sample-output-gallery.html"
SAMPLE_GALLERY_RELEASE = "https://github.com/jaxassistant55/jax-micro-offer-studio/releases/tag/one-sale-sample-output-gallery-v1"
SAMPLE_GALLERY_CSV = "https://jaxassistant55.github.io/jax-micro-offer-studio/one_sale_sample_output_gallery.csv"
SAMPLE_GALLERY_JSON = "https://jaxassistant55.github.io/jax-micro-offer-studio/one_sale_sample_output_gallery.json"
READY_SIGNAL_ROOM = "#{SITE}ready-to-buy-signal-room.html"
READY_SIGNAL_ISSUE_NUMBER = "29"
PROOF_MONITOR = "#{SITE}proof-monitor.html"
PRODUCT_BUNDLE_TERMS = "#{SITE}first-100-product-bundle-terms.html"
PRODUCT_BUNDLE_ACCEPTANCE = "I accept the First $100 Product Bundle Terms at $100. I understand the private ZIP is delivered only after seller-owned external payment proof exists; the bundle is for my internal or client-project use only; I will not resell, redistribute, sublicense, or post the paid files publicly; and custom implementation or support is not included unless separately agreed before payment."
FAST_START_TERMS = "#{SITE}first-100-fast-start-terms.html"
FAST_START_ACCEPTANCE = "I accept the First $100 Fast Start fixed-scope terms at $100. I understand work starts only after seller-owned external payment proof exists; I will provide only public or buyer-authorized non-sensitive inputs; the selected starter scope is limited to the deliverable described on the First $100 Fast Start page; and custom implementation, account login work, credential handling, regulated advice, paid ads, purchasing, ongoing support, or extra revisions are not included unless separately agreed before payment."
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

def event_payload
  event_path = ENV["GITHUB_EVENT_PATH"].to_s
  return nil if event_path.empty? || !File.exist?(event_path)

  JSON.parse(File.read(event_path))
rescue JSON::ParserError
  nil
end

def issue_from_event
  event_payload && event_payload["issue"]
end

def comment_from_event
  event_payload && event_payload["comment"]
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

def paid_order_board_issue?(issue)
  labels = label_names(issue).map(&:downcase)
  title = issue["title"].to_s.downcase
  labels.any? { |label| %w[paid-inquiry order-board product-transfer service-order needs-scope].include?(label) } ||
    title.include?("order board") ||
    title.include?("first $100") ||
    title.include?("available now")
end

def signal_room_issue?(issue)
  issue["number"].to_s == READY_SIGNAL_ISSUE_NUMBER ||
    issue["title"].to_s.downcase.include?("ready-to-buy signal room") ||
    issue["body"].to_s.include?(READY_SIGNAL_ROOM)
end

def ready_buyer_comment?(comment)
  text = comment.to_s.downcase
  return false if text.empty?

  [
    "ready to pay",
    "ready-to-pay",
    "ready to buy",
    "ready-to-buy",
    "i accept",
    "please invoice",
    "send invoice",
    "payment link",
    "checkout link",
    "funded milestone",
    "i want to buy",
    "i want this",
    "buy this",
    "purchase this",
    "place an order",
    "start order",
    "hire you"
  ].any? { |phrase| text.include?(phrase) }
end

def non_buyer_claim_text?(text)
  normalized = text.to_s.downcase
  return true if normalized.include?("/bounty")
  return true if normalized.include?("bounty:") && (normalized.include?("automated") || normalized.include?("ai agent") || normalized.include?("ai fix"))
  return true if normalized.include?("[ai fix]") && normalized.include?("order board:")
  return true if normalized.include?("[claim]") && (normalized.include?("bounty") || normalized.include?("wallet"))
  return true if normalized.include?("wallet") && normalized.include?("base usdc")
  return true if normalized.include?("happy to claim") && (normalized.include?("pr") || normalized.include?("eta") || normalized.include?("diff"))
  return true if normalized.include?("first reviewable pr")
  return true if normalized.include?("draft pr")
  return true if normalized.include?("submit a draft pr")
  return true if normalized.include?("post a concrete checkpoint")
  return true if normalized.include?("repro/logs")
  return true if normalized.include?("patch summary")
  return true if normalized.include?("i keep frontend diffs")
  return true if normalized.include?("reproducing the ui/layout issue")

  false
end

def catalog_rows
  return [] unless File.exist?(CATALOG_PATH)

  JSON.parse(File.read(CATALOG_PATH)).fetch("rows", [])
rescue JSON::ParserError
  []
end

def payment_packet_rows
  return [] unless File.exist?(PAYMENT_PACKETS_PATH)

  CSV.read(PAYMENT_PACKETS_PATH, headers: true).map(&:to_h)
rescue CSV::MalformedCSVError
  []
end

def repo_from_url(url)
  url.to_s.sub(%r{\Ahttps://github\.com/}, "").sub(%r{/(issues|pull)/.*\z}, "").sub(%r{/\z}, "")
end

def catalog_match(issue, repo, extra_text = "")
  title = issue["title"].to_s.downcase
  body = [issue["body"], extra_text].join("\n").downcase
  candidates = catalog_rows
  title_match = candidates.find do |row|
    row_title = row["title"].to_s.downcase
    row_id = row["catalog_row_id"].to_s.tr("-", " ").downcase
    (!row_title.empty? && (title.include?(row_title) || body.include?(row_title))) ||
      (!row_id.empty? && (title.include?(row_id) || body.include?(row_id)))
  end
  return title_match if title_match
  return {} if signal_room_issue?(issue)

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

def first_100_product_bundle?(issue, matched_row)
  text = [
    issue["title"],
    issue["body"],
    matched_row["catalog_row_id"],
    matched_row["title"],
    matched_row["primary_url"],
    matched_row["structured_form_url"]
  ].join("\n").downcase

  text.include?("first $100 product bundle") ||
    text.include?("first-100-product-bundle") ||
    text.include?("central-first-100-product-bundle")
end

def first_100_fast_start?(issue, matched_row)
  text = [
    issue["title"],
    issue["body"],
    matched_row["catalog_row_id"],
    matched_row["title"],
    matched_row["primary_url"],
    matched_row["structured_form_url"],
    matched_row["best_buyer_action_url"]
  ].join("\n").downcase

  text.include?("first $100 fast start") ||
    text.include?("first-100-fast-start") ||
    text.include?("central-first-100-fast-start")
end

def payment_packet_match(matched_row)
  rows = payment_packet_rows
  return nil if rows.empty?

  catalog_row_id = matched_row["catalog_row_id"].to_s
  title = matched_row["title"].to_s.downcase
  primary_url = matched_row["primary_url"].to_s
  structured_url = matched_row["structured_form_url"].to_s
  order_board = matched_row["order_board_url"].to_s

  rows.find { |row| row["catalog_row_id"].to_s == catalog_row_id } ||
    rows.find { |row| !title.empty? && row["title"].to_s.downcase == title } ||
    rows.find do |row|
      [primary_url, structured_url, order_board].any? do |url|
        !url.empty? && [
          row["primary_url"],
          row["structured_form_url"],
          row["best_buyer_action_url"],
          row["order_board_url"]
        ].include?(url)
      end
    end
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
  signal_room = signal_room_issue?(issue)
  offer = matched_row["title"].to_s.empty? ? (signal_room ? "route not selected yet" : "the selected Micro Offer Studio route") : matched_row["title"]
  price = matched_row["price"].to_s.empty? ? "the listed fixed price" : matched_row["price"]
  detail_url = matched_row["primary_url"].to_s.empty? ? "#{SITE}paid-offer-action-catalog.html" : matched_row["primary_url"]
  payment_url = matched_row["payment_activation_url"].to_s.empty? ? PAYMENT_ACTIVATION : matched_row["payment_activation_url"]
  proof_rule = matched_row["proof_rule"].to_s.empty? ? "Count $0 until a real buyer accepts scope, pays through a seller-owned external route, receives delivery, and payment is posted, released, payable, or cleared." : matched_row["proof_rule"]
  payment_packet = payment_packet_match(matched_row)
  payment_packet_block = if payment_packet
                           <<~MD

                             Matching one-sale payment packet:
                             - Packet: #{payment_packet["packet_url"]}
                             - Packet ID: #{payment_packet["packet_id"]}
                             - Invoice line: #{payment_packet["invoice_line"]}
                             - Use this packet after acceptance to paste a seller-owned checkout, invoice, marketplace order, funded milestone, or payment request URL into the buyer message.
                           MD
                         else
                           <<~MD

                             One-sale payment packets:
                             - Packet index: #{ONE_SALE_PAYMENT_PACKETS}
                             - Use a packet only after a real buyer selects the route and scope or transfer terms are accepted.
                           MD
                         end
  bundle_terms = if first_100_product_bundle?(issue, matched_row)
                   <<~MD

                     First $100 Product Bundle terms:
                     - Terms and acceptance page: #{PRODUCT_BUNDLE_TERMS}
                     - Exact acceptance statement to provide before payment:
                       "#{PRODUCT_BUNDLE_ACCEPTANCE}"
                     - Private bundle transfer happens only after that acceptance plus seller-owned external payment proof.
                   MD
                 else
                   ""
                 end
  fast_start_terms = if first_100_fast_start?(issue, matched_row)
                       <<~MD

                         First $100 Fast Start terms:
                         - Terms and acceptance page: #{FAST_START_TERMS}
                         - Exact acceptance statement to provide before payment:
                           "#{FAST_START_ACCEPTANCE}"
                         - Paid work starts only after one exact $100 starter scope is selected, that acceptance is saved, and seller-owned external payment proof exists.
                       MD
                     else
                       ""
                     end
  signal_room_block = if signal_room
                        <<~MD

                          Ready-to-buy signal room:
                          - Signal room: #{READY_SIGNAL_ROOM}
                          - Pick one of the 34 one-sale-to-$100 routes before payment.
                          - If the exact route is not selected yet, reply with the route title, public-safe scope, deadline, and delivery preference.
                          - After the route is selected, use that row's buyer action and matching payment packet before sending any seller-owned payment URL.
                        MD
                      else
                        ""
                      end

  <<~MD
    #{MARKER}
    Thanks for opening a ready-to-pay or ready-to-buy request.

    Matched route: #{offer}
    Listed price: #{price}
    Offer page: #{detail_url}
    #{signal_room_block}

    Exact next steps:
    1. Keep the scope public-safe in this issue. Do not post passwords, payment cards, tax identifiers, private regulated details, confidential files, or screenshots of payment accounts.
    2. Confirm the exact route, deliverable, deadline, acceptance proof, and any buyer-owned inputs that can safely be shared.
    3. Use the payment activation page only after scope or transfer terms are accepted: #{payment_url}
    4. Use the sample-output gallery to confirm the expected deliverable shape before payment: https://jaxassistant55.github.io/jax-micro-offer-studio/one-sale-sample-output-gallery.html
    5. Use the matching one-sale payment packet below to prepare the seller-side invoice line and payment-request copy.
    6. Payment must happen through a seller-owned external checkout, invoice, marketplace order, payment request, or funded milestone. This GitHub issue is not a checkout and is not payment proof.
    7. After external payment is posted, released, payable, or cleared, the seller can deliver the private bundle or service output and record the proof in the monitor.
    Sample-output proof before payment:
    - Gallery: https://jaxassistant55.github.io/jax-micro-offer-studio/one-sale-sample-output-gallery.html
    - Release packet: https://github.com/jaxassistant55/jax-micro-offer-studio/releases/tag/one-sale-sample-output-gallery-v1
    - CSV: https://jaxassistant55.github.io/jax-micro-offer-studio/one_sale_sample_output_gallery.csv
    - JSON: https://jaxassistant55.github.io/jax-micro-offer-studio/one_sale_sample_output_gallery.json
    - These samples and release downloads count $0 until accepted scope, external payment proof, delivery proof, and posted/released/payable/cleared funds exist.
    #{payment_packet_block}
    #{bundle_terms}
    #{fast_start_terms}

    Proof monitor: #{PROOF_MONITOR}

    Money rule: #{proof_rule}
  MD
end

def emit(result)
  puts JSON.pretty_generate(result)
end

issue = issue_from_event
comment = comment_from_event
number = issue_number
issue = fetch_issue(REPO, number) if number && (issue.nil? || issue["number"].to_s != number)

unless issue
  emit(status: "skipped", reason: "no_issue_context")
  exit 0
end

number = issue["number"].to_s
labels = label_names(issue)
issue_author = issue.dig("user", "login").to_s
comment_author = comment.is_a?(Hash) ? comment.dig("user", "login").to_s : ""
comment_body = comment.is_a?(Hash) ? comment["body"].to_s : ""
trigger_author = comment_body.empty? ? issue_author : comment_author
combined_text = [issue["title"], issue["body"], labels.join(" "), comment_body].join("\n")

if issue["pull_request"].is_a?(Hash)
  emit(status: "skipped", reason: "pull_request_not_buyer_issue", issue: number)
  exit 0
end

unless issue["state"].to_s == "open"
  emit(status: "skipped", reason: "issue_not_open", issue: number, state: issue["state"])
  exit 0
end

ready_from_issue = ready_issue?(issue)
ready_from_comment = !comment_body.empty? && paid_order_board_issue?(issue) && ready_buyer_comment?(comment_body)

unless ready_from_issue || ready_from_comment
  emit(status: "skipped", reason: "not_ready_to_pay_or_buy", issue: number, labels: labels, comment_checked: !comment_body.empty?)
  exit 0
end

if ASSISTANT_AUTHORS.include?(trigger_author)
  emit(status: "skipped", reason: "assistant_authored_trigger", issue: number, author: trigger_author)
  exit 0
end

if non_buyer_claim_text?(combined_text)
  emit(status: "skipped", reason: "non_buyer_claim_or_task_offer", issue: number, author: trigger_author)
  exit 0
end

if labels.map(&:downcase).include?("buyer-response-sent") || existing_response?(REPO, number)
  emit(status: "skipped", reason: "response_already_present", issue: number)
  exit 0
end

matched_row = catalog_match(issue, REPO, comment_body)
matched_packet = payment_packet_match(matched_row)
body = response_body(issue, matched_row)
post_comment(REPO, number, body)
add_labels(REPO, number)

emit(
  status: dry_run? ? "dry_run_ready_to_respond" : "responded",
  issue: number,
  author: trigger_author,
  trigger: comment_body.empty? ? "issue" : "issue_comment",
  ready_from_issue: ready_from_issue,
  ready_from_comment: ready_from_comment,
  matched_catalog_row: matched_row["catalog_row_id"],
  matched_title: matched_row["title"],
  matched_payment_packet: matched_packet && matched_packet["packet_url"],
  signal_room_issue: signal_room_issue?(issue),
  response_includes_signal_room: body.include?(READY_SIGNAL_ROOM),
  response_includes_payment_packet: !matched_packet.nil? && body.include?(matched_packet["packet_url"].to_s),
  response_includes_payment_packet_index: body.include?(ONE_SALE_PAYMENT_PACKETS),
  response_includes_sample_gallery: body.include?(SAMPLE_GALLERY),
  response_includes_sample_gallery_release: body.include?(SAMPLE_GALLERY_RELEASE),
  response_includes_product_bundle_terms: body.include?(PRODUCT_BUNDLE_TERMS),
  response_includes_product_bundle_acceptance: body.include?(PRODUCT_BUNDLE_ACCEPTANCE),
  response_includes_fast_start_terms: body.include?(FAST_START_TERMS),
  response_includes_fast_start_acceptance: body.include?(FAST_START_ACCEPTANCE),
  labels_added: RESPONSE_LABELS.keys,
  comment_marker: MARKER
)
