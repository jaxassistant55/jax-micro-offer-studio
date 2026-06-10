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

def proof_status_for_issue(issue)
  return "issue_check_failed_manual_review_required" if issue["__error"]
  return "issue_closed_review_required" if issue["state"] != "open"
  return "buyer_comments_present_manual_payment_review_required" if issue["comments"].to_i.positive?

  "no_buyer_comments_no_payment_proof"
end

def issue_row(source, repo, issue_number, next_paid_step)
  issue = gh_json("repos/#{repo}/issues/#{issue_number}")
  comments = issue.fetch("comments", source["comments"]).to_i
  labels = issue.fetch("labels", []).map { |label| label["name"] }.join("|")

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
    "issue_comments" => comments,
    "release_downloads" => 0,
    "labels" => labels,
    "proof_status" => proof_status_for_issue(issue),
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

github_lead_rows = read_csv(File.join(RUN_ROOT, "github_lead_repos", "github_lead_repos.csv"))
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

download_followup_rows = read_csv(File.join(RUN_ROOT, "github_lead_repos", "download_followup.csv"))
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
    "next_paid_step" => row["prefilled_inquiry_url"].to_s.empty? ? row["repo_order_issue_url"] : row["prefilled_inquiry_url"]
  }
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
issue_comment_count = rows.sum { |row| row["issue_comments"].to_i }
download_total = rows.sum { |row| row["release_downloads"].to_i }
hot_rows = rows.select { |row| row["issue_comments"].to_i.positive? || row["release_downloads"].to_i.positive? }

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
  </head>
  <body>
    <main>
      <header>
        <p class="buttons"><a href="index.html">Home</a><a href="order-boards.html">Order boards</a><a href="download-followup.html">Download follow-up</a><a href="proof.html">Proof rules</a><a href="proof_monitor.csv">CSV</a></p>
        <h1>Proof Monitor</h1>
        <p class="muted">Generated #{h(GENERATED_AT)}. This monitor checks public issue boards, standalone repo order boards, and observed release download interest. It does not infer income from pages, downloads, stars, forks, or comments.</p>
      </header>

      <section class="notice">
        <h2>Confirmed Money: $0</h2>
        <p>Every row stays at $0 until external paid order, cleared invoice, funded milestone, payable balance, posted refund/credit, or equivalent proof exists.</p>
      </section>

      <section class="summary">
        #{metric.call("Main issue-board rows", main_issue_count)}
        #{metric.call("Standalone order boards", standalone_count)}
        #{metric.call("Rows with download signals", download_signal_count)}
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
