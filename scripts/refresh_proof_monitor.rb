#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "cgi"
require "json"
require "open3"
require "time"

ENV["TZ"] = "Asia/Tokyo"

REPO = "jaxassistant55/jax-micro-offer-studio"
LAUNCH_ROOT = File.expand_path("..", __dir__)
RUN_ROOT = File.expand_path("..", LAUNCH_ROOT)
DOCS = File.join(LAUNCH_ROOT, "docs")
GENERATED_AT = Time.now.strftime("%Y-%m-%d %H:%M:%S JST")
MONEY_COUNT_RULE = "Count $0 unless external paid order, cleared invoice, funded milestone, payable balance, posted refund/credit, or equivalent proof exists."
ASSISTANT_AUTHORS = %w[jaxassistant55].freeze
HEADERS = %w[
  checked_at_jst
  kind
  repo
  signal_id
  title
  price
  first_100_path
  url
  state
  issue_comments
  release_downloads
  labels
  proof_status
  money_confirmed_usd
  money_count_rule
  next_paid_step
].freeze

def h(value)
  CGI.escapeHTML(value.to_s)
end

def read_csv(path)
  return [] unless File.exist?(path)

  CSV.read(path, headers: true).map(&:to_h)
end

def gh_json(path)
  stdout, stderr, status = Open3.capture3("gh", "api", path)
  return { "__error" => stderr.to_s.strip.empty? ? "gh api failed for #{path}" : stderr.to_s.strip } unless status.success?

  JSON.parse(stdout)
rescue JSON::ParserError => e
  { "__error" => e.message }
end

def issue_comment_summary(repo, issue_number, fallback_count)
  comments = gh_json("repos/#{repo}/issues/#{issue_number}/comments")
  return { "buyer" => fallback_count.to_i, "self" => 0, "non_buyer_claim" => 0, "total" => fallback_count.to_i, "error" => comments["__error"] } if comments.is_a?(Hash) && comments["__error"]

  total = comments.length
  self_count = comments.count { |comment| ASSISTANT_AUTHORS.include?(comment.dig("user", "login").to_s) }
  non_buyer_claim_count = comments.count do |comment|
    next false if ASSISTANT_AUTHORS.include?(comment.dig("user", "login").to_s)

    body = comment["body"].to_s.downcase
    body.include?("[claim]") && (body.include?("bounty") || body.include?("wallet"))
  end
  { "buyer" => total - self_count - non_buyer_claim_count, "self" => self_count, "non_buyer_claim" => non_buyer_claim_count, "total" => total, "error" => nil }
end

def proof_status_for_issue(issue, comment_summary)
  return "issue_check_failed_manual_review_required" if issue["__error"]
  return "issue_closed_review_required" if issue["state"] != "open"
  return "buyer_comments_present_manual_payment_review_required" if comment_summary["buyer"].to_i.positive?
  return "non_buyer_bounty_claim_comment_no_payment_proof" if comment_summary["non_buyer_claim"].to_i.positive?
  return "assistant_update_comments_only_no_payment_proof" if comment_summary["self"].to_i.positive?

  "no_buyer_comments_no_payment_proof"
end

def issue_row(source, repo, issue_number, next_paid_step)
  issue = gh_json("repos/#{repo}/issues/#{issue_number}")
  comment_summary = issue_comment_summary(repo, issue_number, issue.fetch("comments", source["comments"]).to_i)
  buyer_comments = comment_summary["buyer"].to_i
  labels = issue.fetch("labels", []).map { |label| label["name"] }.join("|")
  labels = [labels, "assistant_updates:#{comment_summary["self"]}", "non_buyer_claims:#{comment_summary["non_buyer_claim"]}", "total_comments:#{comment_summary["total"]}"].reject(&:empty?).join("|")

  {
    "checked_at_jst" => GENERATED_AT,
    "kind" => source["kind"],
    "repo" => repo,
    "signal_id" => "##{issue_number}",
    "title" => source["title"] || issue["title"],
    "price" => source["price"],
    "first_100_path" => source["first_100_path"],
    "url" => issue["html_url"] || source["issue_url"],
    "state" => issue["state"] || source["state"] || "unknown",
    "issue_comments" => buyer_comments,
    "release_downloads" => 0,
    "labels" => labels,
    "proof_status" => proof_status_for_issue(issue, comment_summary),
    "money_confirmed_usd" => "0",
    "money_count_rule" => MONEY_COUNT_RULE,
    "next_paid_step" => next_paid_step
  }
end

def repo_name_from_url(url)
  url.to_s.sub(%r{\Ahttps://github\.com/}, "").sub(%r{/issues/.*\z}, "").sub(%r{/\z}, "")
end

def download_count_for(row)
  repo = row["repo"].to_s
  release = gh_json("repos/#{repo}/releases/tags/preview-v1")
  return row["download_count"].to_i if release["__error"]

  asset_url = row["asset_url"].to_s
  matching_asset = release.fetch("assets", []).find do |asset|
    [asset["browser_download_url"], asset["url"], asset["name"]].compact.any? { |value| asset_url.include?(value.to_s) }
  end
  (matching_asset || release.fetch("assets", []).first || {})["download_count"].to_i
end

def release_asset_download_count(repo, tag, asset_match = nil)
  release = gh_json("repos/#{repo}/releases/tags/#{tag}")
  return { "count" => 0, "url" => "https://github.com/#{repo}/releases/tag/#{tag}", "error" => release["__error"] } if release["__error"]

  assets = release.fetch("assets", [])
  matching_asset = assets.find do |asset|
    asset_match.to_s.empty? || [asset["browser_download_url"], asset["url"], asset["name"]].compact.any? { |value| value.to_s.include?(asset_match.to_s) }
  end
  asset = matching_asset || assets.first || {}
  {
    "count" => asset["download_count"].to_i,
    "url" => release["html_url"].to_s.empty? ? "https://github.com/#{repo}/releases/tag/#{tag}" : release["html_url"],
    "asset_url" => asset["browser_download_url"].to_s,
    "error" => nil
  }
end

def issue_number_from_url(url)
  match = url.to_s.match(%r{/issues/(\d+)})
  match && match[1].to_i
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

def structured_ready_issue?(issue)
  labels = issue.fetch("labels", []).map { |label| label["name"].to_s.downcase }
  title = issue["title"].to_s.downcase
  return false if labels.include?("order-board")

  labels.any? { |label| %w[ready-to-pay ready-to-buy].include?(label) } ||
    title.start_with?("ready to pay:") ||
    title.start_with?("ready to buy:")
end

def catalog_repo_name(row)
  row["repo_url"].to_s.sub(%r{\Ahttps://github\.com/}, "").sub(%r{/\z}, "")
end

def hot_close_room_url(row)
  repo_name = row["repo"].to_s.split("/").last
  "https://jaxassistant55.github.io/jax-micro-offer-studio/hot-download-close-#{repo_name}.html"
end

sources = [{
  "kind" => "main_board",
  "title" => "Available now: first paid $100+ micro-offer request",
  "issue_number" => "1",
  "issue_url" => "https://github.com/#{REPO}/issues/1",
  "price" => "various",
  "first_100_path" => "One accepted $100+ service or enough paid product transfers",
  "next_paid_step" => "https://jaxassistant55.github.io/jax-micro-offer-studio/order-now.html"
}]

read_csv(File.join(LAUNCH_ROOT, "order_boards.csv")).each do |row|
  sources << row.merge(
    "kind" => "focused_order_board",
    "next_paid_step" => "https://jaxassistant55.github.io/jax-micro-offer-studio/#{File.basename(row["detail_url"].to_s)}"
  )
end

rows = sources.map do |source|
  issue_row(source, REPO, source["issue_number"], source["next_paid_step"])
end

github_lead_repo_source = File.join(RUN_ROOT, "github_lead_repos", "github_lead_repos.csv")
github_lead_repo_source = File.join(DOCS, "github_lead_repos.csv") unless File.exist?(github_lead_repo_source)
github_lead_rows = read_csv(github_lead_repo_source)
github_lead_rows.each do |repo_row|
  issue_url = repo_row["repo_order_issue_url"].to_s
  issue_number = repo_row["repo_order_issue_number"].to_s
  next if issue_url.empty? || issue_number.empty?

  repo = repo_name_from_url(issue_url)
  inquiry_url = "#{repo_row["standalone_index_url"]}inquiry.html"
  rows << issue_row({
    "kind" => "standalone_order_board",
    "title" => "Repo order board: #{repo_row["title"]}",
    "price" => repo_row["price"],
    "first_100_path" => repo_row["first_100_path"],
    "issue_url" => issue_url,
    "state" => repo_row["repo_order_issue_state"],
    "comments" => repo_row["repo_order_issue_comments"]
  }, repo, issue_number, inquiry_url)
end

download_followup_source = File.join(RUN_ROOT, "github_lead_repos", "download_followup.csv")
download_followup_source = File.join(DOCS, "download_followup.csv") unless File.exist?(download_followup_source)
download_followup_rows = read_csv(download_followup_source)
download_followup_rows.each do |row|
  downloads = download_count_for(row)
  next unless downloads.positive?

  rows << {
    "checked_at_jst" => GENERATED_AT,
    "kind" => "release_download_signal",
    "repo" => row["repo"],
    "signal_id" => "preview-v1",
    "title" => "Preview ZIP download: #{row["title"]}",
    "price" => row["price"],
    "first_100_path" => row["first_100_path"],
    "url" => row["download_followup_url"].to_s.empty? ? row["release_url"] : row["download_followup_url"],
    "state" => "download_count_present",
    "issue_comments" => 0,
    "release_downloads" => downloads,
    "labels" => "release-download|interest-only",
    "proof_status" => "download_interest_no_buyer_or_payment_proof",
    "money_confirmed_usd" => "0",
    "money_count_rule" => "Release downloads count $0. Count only externally posted, released, payable, or cleared payment after buyer acceptance and delivery.",
    "next_paid_step" => hot_close_room_url(row)
  }
end

[
  ["first_100_fast_start.csv", "First $100 Fast Start CSV release asset"],
  ["first-100-sample-pack.zip", "First $100 Fast Start sample-pack release asset"]
].each do |asset_name, title|
  first_100_release = release_asset_download_count(REPO, "first-100-fast-start-v1", asset_name)
  rows << {
    "checked_at_jst" => GENERATED_AT,
    "kind" => "first_100_release_asset",
    "repo" => REPO,
    "signal_id" => "first-100-fast-start-v1:#{asset_name}",
    "title" => title,
    "price" => "$100",
    "first_100_path" => "One paid fixed-scope starter reaches $100 before fees/refunds.",
    "url" => first_100_release["url"],
    "state" => first_100_release["count"].positive? ? "download_count_present" : "release_live_no_downloads",
    "issue_comments" => 0,
    "release_downloads" => first_100_release["count"],
    "labels" => ["release-asset", "interest-only", first_100_release["asset_url"].to_s].reject(&:empty?).join("|"),
    "proof_status" => first_100_release["count"].positive? ? "release_download_interest_no_buyer_or_payment_proof" : "release_live_no_buyer_or_payment_proof",
    "money_confirmed_usd" => "0",
    "money_count_rule" => "Release downloads count $0. Count only externally posted, released, payable, or cleared payment after buyer acceptance and delivery.",
    "next_paid_step" => "https://jaxassistant55.github.io/jax-micro-offer-studio/first-100-fast-start.html"
  }
end

[
  ["paid-offer-action-catalog-v1.zip", "Paid Offer Action Catalog v1 bundle release asset"],
  ["paid-offer-action-catalog.json", "Paid Offer Action Catalog JSON release asset"],
  ["paid-offer-action-catalog.csv", "Paid Offer Action Catalog CSV release asset"],
  ["paid-offer-action-catalog-release-manifest.csv", "Paid Offer Action Catalog manifest release asset"]
].each do |asset_name, title|
  catalog_release = release_asset_download_count(REPO, "paid-offer-action-catalog-v1", asset_name)
  rows << {
    "checked_at_jst" => GENERATED_AT,
    "kind" => "paid_catalog_release_asset",
    "repo" => REPO,
    "signal_id" => "paid-offer-action-catalog-v1:#{asset_name}",
    "title" => title,
    "price" => "various",
    "first_100_path" => "Any one verified $100+ paid order routed through the catalog reaches the first $100 target before fees/refunds.",
    "url" => catalog_release["url"],
    "state" => catalog_release["count"].positive? ? "download_count_present" : "release_live_no_downloads",
    "issue_comments" => 0,
    "release_downloads" => catalog_release["count"],
    "labels" => ["release-asset", "paid-action-catalog", "interest-only", catalog_release["asset_url"].to_s].reject(&:empty?).join("|"),
    "proof_status" => catalog_release["count"].positive? ? "catalog_release_download_interest_no_buyer_or_payment_proof" : "catalog_release_live_no_buyer_or_payment_proof",
    "money_confirmed_usd" => "0",
    "money_count_rule" => "Catalog release downloads count $0. Count only externally posted, released, payable, or cleared payment after buyer acceptance and delivery.",
    "next_paid_step" => "https://jaxassistant55.github.io/jax-micro-offer-studio/paid-offer-action-catalog.html"
  }
end

[
  ["first-100-product-bundle-marketplace-listing-packet.zip", "First $100 Product Bundle marketplace listing packet ZIP"],
  ["marketplace_listing_fields.csv", "First $100 Product Bundle marketplace listing fields CSV"],
  ["marketplace_listing_packet.json", "First $100 Product Bundle marketplace listing packet JSON"],
  ["seller_publish_checklist.md", "First $100 Product Bundle seller publish checklist"],
  ["buyer_reply_template.md", "First $100 Product Bundle buyer reply template"],
  ["first-100-product-bundle-cover.png", "First $100 Product Bundle cover image asset"]
].each do |asset_name, title|
  bundle_marketplace_release = release_asset_download_count(REPO, "first-100-product-bundle-marketplace-v1", asset_name)
  rows << {
    "checked_at_jst" => GENERATED_AT,
    "kind" => "bundle_marketplace_release_asset",
    "repo" => REPO,
    "signal_id" => "first-100-product-bundle-marketplace-v1:#{asset_name}",
    "title" => title,
    "price" => "$100",
    "first_100_path" => "One verified paid $100 product-bundle transfer reaches the first $100 target before fees/refunds.",
    "url" => bundle_marketplace_release["url"],
    "state" => bundle_marketplace_release["count"].positive? ? "download_count_present" : "release_live_no_downloads",
    "issue_comments" => 0,
    "release_downloads" => bundle_marketplace_release["count"],
    "labels" => ["release-asset", "first-100-product-bundle", "marketplace-listing-packet", "interest-only", bundle_marketplace_release["asset_url"].to_s].reject(&:empty?).join("|"),
    "proof_status" => bundle_marketplace_release["count"].positive? ? "bundle_marketplace_download_interest_no_buyer_or_payment_proof" : "bundle_marketplace_release_live_no_buyer_or_payment_proof",
    "money_confirmed_usd" => "0",
    "money_count_rule" => "Marketplace packet release downloads count $0. Count only externally posted, released, payable, or cleared payment after buyer acceptance and private bundle delivery.",
    "next_paid_step" => "https://jaxassistant55.github.io/jax-micro-offer-studio/first-100-product-bundle-marketplace.html"
  }
end

paid_catalog_path = File.join(DOCS, "paid-offer-action-catalog.json")
paid_catalog = File.exist?(paid_catalog_path) ? JSON.parse(File.read(paid_catalog_path)) : { "rows" => [] }
catalog_rows = paid_catalog.fetch("rows", [])
catalog_rows_by_repo = catalog_rows.group_by { |row| catalog_repo_name(row) }.reject { |repo, _| repo.empty? }
tracked_issue_numbers_by_repo = Hash.new { |hash, key| hash[key] = [] }
rows.each do |row|
  number = row["signal_id"].to_s[/\A#(\d+)\z/, 1]
  tracked_issue_numbers_by_repo[row["repo"]] << number.to_i if number
end

catalog_rows_by_repo.each do |repo, repo_catalog_rows|
  issues = gh_json("repos/#{repo}/issues?state=all&per_page=100")
  next if issues.is_a?(Hash) && issues["__error"]

  issues.each do |issue|
    issue_number = issue["number"].to_i
    labels = issue.fetch("labels", []).map { |label| label["name"].to_s }.reject(&:empty?)
    label_text = labels.join("|")
    title = issue["title"].to_s
    body = issue["body"].to_s
    author = issue.dig("user", "login").to_s
    is_pull_request = issue["pull_request"].is_a?(Hash)

    if is_pull_request && non_buyer_claim_text?([title, body, label_text].join("\n"))
      rows << {
        "checked_at_jst" => GENERATED_AT,
        "kind" => "non_buyer_pull_request_claim",
        "repo" => repo,
        "signal_id" => "PR##{issue_number}",
        "title" => title.empty? ? "Non-buyer pull request claim" : title,
        "price" => "$0",
        "first_100_path" => "Not a buyer path; this is a bounty/wallet-style claim and does not count toward $100.",
        "url" => issue["html_url"],
        "state" => issue["state"],
        "issue_comments" => 0,
        "release_downloads" => 0,
        "labels" => ["pull-request", "non-buyer-claim", "author:#{author}", label_text].reject(&:empty?).join("|"),
        "proof_status" => "non_buyer_bounty_pull_request_no_payment_proof",
        "money_confirmed_usd" => "0",
        "money_count_rule" => "Bounty, wallet, and pull-request claims count $0. Count only a real buyer order with seller-owned external payment proof after accepted scope and delivery.",
        "next_paid_step" => "https://jaxassistant55.github.io/jax-micro-offer-studio/paid-offer-action-catalog.html"
      }
      next
    end

    next if is_pull_request
    next if tracked_issue_numbers_by_repo[repo].include?(issue_number)
    next unless structured_ready_issue?(issue)

    matched_catalog_row = repo_catalog_rows.find do |row|
      row_title = row["title"].to_s.downcase
      !row_title.empty? && title.downcase.include?(row_title)
    end || repo_catalog_rows.first || {}
    comment_summary = issue_comment_summary(repo, issue_number, issue["comments"].to_i)
    author_is_assistant = ASSISTANT_AUTHORS.include?(author)
    buyer_issue_signal = author_is_assistant ? 0 : 1
    buyer_comment_signals = comment_summary["buyer"].to_i
    non_buyer_claim_signals = comment_summary["non_buyer_claim"].to_i
    buyer_signal_total = buyer_issue_signal + buyer_comment_signals
    proof_status = if non_buyer_claim_text?([title, body, label_text].join("\n")) || non_buyer_claim_signals.positive?
      "non_buyer_claim_on_structured_issue_no_payment_proof"
    elsif issue["state"] != "open"
      "structured_issue_closed_manual_review_required"
    elsif buyer_signal_total.positive?
      "structured_ready_issue_manual_payment_review_required"
    elsif comment_summary["self"].to_i.positive? || author_is_assistant
      "assistant_created_structured_issue_no_payment_proof"
    else
      "structured_ready_issue_no_buyer_or_payment_proof"
    end

    labels_for_row = [
      label_text,
      "author:#{author}",
      "assistant_comments:#{comment_summary["self"]}",
      "buyer_issue_signal:#{buyer_issue_signal}",
      "buyer_comments:#{buyer_comment_signals}",
      "non_buyer_claims:#{non_buyer_claim_signals}",
      "catalog_row:#{matched_catalog_row["catalog_row_id"]}"
    ].reject(&:empty?).join("|")

    rows << {
      "checked_at_jst" => GENERATED_AT,
      "kind" => "structured_ready_issue",
      "repo" => repo,
      "signal_id" => "##{issue_number}",
      "title" => title,
      "price" => matched_catalog_row["price"].to_s.empty? ? "various" : matched_catalog_row["price"],
      "first_100_path" => matched_catalog_row["one_sale_to_100"].to_s == "yes" ? "One verified paid order for this row can reach $100 before fees/refunds." : "Stack only verified paid net amounts until the total reaches $100.",
      "url" => issue["html_url"],
      "state" => issue["state"],
      "issue_comments" => buyer_signal_total,
      "release_downloads" => 0,
      "labels" => labels_for_row,
      "proof_status" => proof_status,
      "money_confirmed_usd" => "0",
      "money_count_rule" => "Structured ready-to-pay issues count $0 until a real buyer accepts terms, pays through a seller-owned external route, receives delivery, and funds are posted/released/payable/cleared.",
      "next_paid_step" => matched_catalog_row["payment_activation_url"].to_s.empty? ? "https://jaxassistant55.github.io/jax-micro-offer-studio/payment-activation" : matched_catalog_row["payment_activation_url"]
    }
  end
end

CSV.open(File.join(LAUNCH_ROOT, "proof_monitor.csv"), "w", write_headers: true, headers: HEADERS) do |csv|
  rows.each { |row| csv << HEADERS.map { |header| row[header] } }
end

Dir.mkdir(DOCS) unless Dir.exist?(DOCS)
CSV.open(File.join(DOCS, "proof_monitor.csv"), "w", write_headers: true, headers: HEADERS) do |csv|
  rows.each { |row| csv << HEADERS.map { |header| row[header] } }
end

main_issue_count = rows.count { |row| %w[main_board focused_order_board].include?(row["kind"]) }
standalone_count = rows.count { |row| row["kind"] == "standalone_order_board" }
download_signal_count = rows.count { |row| row["kind"] == "release_download_signal" }
structured_ready_issue_count = rows.count { |row| row["kind"] == "structured_ready_issue" }
non_buyer_claim_count = rows.count { |row| row["proof_status"].to_s.include?("non_buyer") }
issue_comment_count = rows.sum { |row| row["issue_comments"].to_i }
download_total = rows.sum { |row| row["release_downloads"].to_i }
hot_rows = rows.select do |row|
  row["issue_comments"].to_i.positive? ||
    row["release_downloads"].to_i.positive? ||
    row["proof_status"].to_s.include?("manual") ||
    row["proof_status"].to_s.include?("non_buyer")
end

metric = lambda do |label, value|
  %(<article class="metric"><span>#{h(label)}</span><strong>#{h(value)}</strong></article>)
end

hot_cards = if hot_rows.empty?
  %(<p class="muted">No buyer comments or release-download signals are present right now.</p>)
else
  hot_rows.map do |row|
    %(<article class="card"><span class="eyebrow">#{h(row["kind"])}</span><h3>#{h(row["title"])}</h3><p><a href="#{h(row["url"])}">Open signal</a> | <a href="#{h(row["next_paid_step"])}">Next paid step</a></p><p>Comments: #{h(row["issue_comments"])}. Downloads: #{h(row["release_downloads"])}. Status: #{h(row["proof_status"])}.</p></article>)
  end.join
end

table_rows = rows.map do |row|
  <<~HTML
    <tr>
      <td data-label="Signal"><a href="#{h(row["url"])}">#{h(row["signal_id"])}</a><br><span class="muted">#{h(row["repo"])}</span></td>
      <td data-label="Kind">#{h(row["kind"])}</td>
      <td data-label="Title">#{h(row["title"])}</td>
      <td data-label="Price">#{h(row["price"])}</td>
      <td data-label="State">#{h(row["state"])}</td>
      <td data-label="Issue comments">#{h(row["issue_comments"])}</td>
      <td data-label="Release downloads">#{h(row["release_downloads"])}</td>
      <td data-label="Proof status">#{h(row["proof_status"])}</td>
      <td data-label="Next paid step"><a href="#{h(row["next_paid_step"])}">Open</a></td>
      <td data-label="Money">$#{h(row["money_confirmed_usd"])}</td>
    </tr>
  HTML
end.join

html = <<~HTML
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Expanded proof monitor for Micro Offer Studio buyer comments, repo order boards, and release download interest.">
    <title>Proof Monitor - Micro Offer Studio</title>
    <style>
      :root{--ink:#17202a;--muted:#5d6875;--line:#d9dfeb;--panel:#f6f8fb;--accent:#075da8;--green:#17643a;--gold:#8a5a00}
      *{box-sizing:border-box}body{margin:0;color:var(--ink);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.45;background:#fff}main{width:min(1180px,calc(100% - 32px));margin:0 auto;padding:28px 0 48px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:20px}h1{margin:0 0 8px;font-size:clamp(1.8rem,4vw,2.75rem);letter-spacing:0}h2{margin:24px 0 10px;font-size:1.25rem;letter-spacing:0}h3{margin:0 0 6px;font-size:1.05rem;letter-spacing:0}p{margin:0 0 10px}a{color:var(--accent)}.muted{color:var(--muted)}.buttons{display:flex;gap:8px;flex-wrap:wrap}.buttons a{display:inline-block;border:1px solid var(--line);border-radius:8px;padding:8px 10px;background:#fff;text-decoration:none;font-weight:700}.summary,.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.metric,.notice,.card{border:1px solid var(--line);border-radius:8px;background:#fff;padding:12px;min-width:0;overflow-wrap:anywhere}.metric{background:var(--panel)}.metric span,.eyebrow{display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.04em}.metric strong{display:block;margin-top:5px;font-size:1.25rem}.notice{border-left:6px solid var(--gold);background:#fffaf0}.card{border-left:6px solid var(--green)}table{width:100%;border-collapse:collapse;border:1px solid var(--line);background:#fff}th,td{padding:9px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top;font-size:.88rem;overflow-wrap:anywhere}th{background:var(--panel);color:var(--muted);font-size:.72rem;text-transform:uppercase;letter-spacing:.04em}
      @media(max-width:900px){.summary,.grid{grid-template-columns:1fr}.buttons{display:grid}.buttons a{width:100%}table,thead,tbody,tr,th,td{display:block}thead{display:none}tr{border-bottom:1px solid var(--line);padding:8px 0}td{border-bottom:0;padding:6px 9px}td::before{content:attr(data-label);display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase}}
    </style>
    <link rel="alternate" type="application/json" title="Paid offer action catalog" href="paid-offer-action-catalog.json">
  </head>
  <body>
    <main>
      <header>
        <p class="buttons"><a href="paid-offer-action-catalog.html">Paid offer action catalog</a><a href="index.html">Home</a><a href="order-boards.html">Order boards</a><a href="download-followup.html">Download follow-up</a><a href="proof.html">Proof rules</a><a href="proof_monitor.csv">CSV</a></p>
        <h1>Proof Monitor</h1>
        <p class="muted">Generated #{h(GENERATED_AT)}. This monitor checks public issue boards, standalone repo order boards, and observed release download interest. It does not infer income from pages, downloads, stars, forks, or comments.</p>
      </header>

      <section id="first-100-fast-start" class="notice">
        <h2>First $100 Fast Start</h2>
        <p>A fixed-scope $100 route is available for buyers who want one clear starter order without negotiating a larger package. It offers four mini scopes, sample deliverables, and routes payment through the existing payment-activation boundary.</p>
        <p class="buttons"><a href="first-100-fast-start.html">Open First $100 Fast Start</a><a href="https://github.com/jaxassistant55/jax-micro-offer-studio/issues/24">Order board #24</a><a href="payment-activation/">Payment activation</a><a href="proof-monitor.html">Proof monitor</a><a href="first-100-sample-pack.zip">Sample pack</a></p>
      </section>

      <section class="notice">
        <h2>Confirmed Money: $0</h2>
        <p>Every row stays at $0 until external paid order, cleared invoice, funded milestone, payable balance, posted refund/credit, or equivalent proof exists.</p>
      </section>

      <section class="summary">
        #{metric.call("Main issue-board rows", main_issue_count)}
        #{metric.call("Standalone order boards", standalone_count)}
        #{metric.call("Rows with download signals", download_signal_count)}
        #{metric.call("Structured ready issues", structured_ready_issue_count)}
        #{metric.call("Non-buyer claims", non_buyer_claim_count)}
        #{metric.call("Total monitored rows", rows.length)}
        #{metric.call("Issue comments", issue_comment_count)}
        #{metric.call("Release downloads observed", download_total)}
        #{metric.call("Money confirmed", "$0")}
      </section>

      <section>
        <h2>Signals To Review First</h2>
        <div class="grid">#{hot_cards}</div>
      </section>

      <section>
        <h2>All Monitored Rows</h2>
        <table>
          <thead><tr><th>Signal</th><th>Kind</th><th>Title</th><th>Price</th><th>State</th><th>Issue comments</th><th>Release downloads</th><th>Proof status</th><th>Next paid step</th><th>Money</th></tr></thead>
          <tbody>#{table_rows}</tbody>
        </table>
      </section>
    </main>
  </body>
  </html>
HTML

File.write(File.join(DOCS, "proof-monitor.html"), html)

puts "Wrote #{rows.length} proof-monitor rows to #{File.join(LAUNCH_ROOT, "proof_monitor.csv")}"
puts "Wrote #{File.join(DOCS, "proof_monitor.csv")}"
puts "Wrote #{File.join(DOCS, "proof-monitor.html")}"
