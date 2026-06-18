#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "csv"
require "fileutils"
require "json"
require "time"
require "uri"

ENV["TZ"] = "Asia/Tokyo"

LAUNCH_ROOT = File.expand_path("..", __dir__)
DOCS = File.join(LAUNCH_ROOT, "docs")
SITE = "https://jaxassistant55.github.io/jax-micro-offer-studio/"
PAGE = "fastest-100-start.html"
CSV_NAME = "fastest_100_start.csv"
STAMP = Time.now.strftime("%Y-%m-%d %H:%M:%S JST")

def h(value)
  CGI.escapeHTML(value.to_s)
end

def url(path)
  URI.join(SITE, path).to_s
end

def rows(path)
  return [] unless File.exist?(path)

  CSV.read(path, headers: true).map(&:to_h)
end

def write_csv(path, headers, data)
  CSV.open(path, "w", write_headers: true, headers: headers) do |csv|
    data.each { |row| csv << headers.map { |header| row.fetch(header, "") } }
  end
end

def upsert_block(path, key, block, fallback)
  html = File.read(path, encoding: "UTF-8")
  start = "<!-- #{key}:start -->"
  finish = "<!-- #{key}:end -->"
  wrapped = "#{start}\n#{block.strip}\n#{finish}"

  html = html.sub(/<!-- #{Regexp.escape(key)}:start -->.*?<!-- #{Regexp.escape(key)}:end -->\n?/m, "")
  updated = html.sub(fallback, "#{wrapped}\n#{fallback}")

  File.write(path, updated)
end

def add_link_after(path, marker, link_html)
  html = File.read(path, encoding: "UTF-8")
  return if html.include?(link_html)

  html = html.sub(marker, "#{marker}#{link_html}")
  File.write(path, html)
end

def add_indexnow_url(path)
  full_url = url(path)

  urls_csv = File.join(DOCS, "indexnow_urls.csv")
  existing = rows(urls_csv).map { |row| row["url"] }
  merged = ([full_url] + existing).compact.uniq
  write_csv(urls_csv, ["url"], merged.map { |entry| { "url" => entry } })

  payload_path = File.join(DOCS, "indexnow_payload.json")
  if File.exist?(payload_path)
    payload = JSON.parse(File.read(payload_path, encoding: "UTF-8"))
    payload["urlList"] = ([full_url] + payload.fetch("urlList", [])).uniq
    File.write(payload_path, JSON.pretty_generate(payload))
  end

  sitemap_path = File.join(DOCS, "sitemap.xml")
  if File.exist?(sitemap_path)
    sitemap = File.read(sitemap_path, encoding: "UTF-8")
    unless sitemap.include?(full_url)
      sitemap = sitemap.sub("</urlset>", "  <url><loc>#{h(full_url)}</loc></url>\n</urlset>")
      File.write(sitemap_path, sitemap)
    end
  end
end

signal_rows = rows(File.join(DOCS, "ready-to-buy-signal-room.csv"))
signal_by_id = signal_rows.to_h { |row| [row["catalog_row_id"], row] }
proof_rows = rows(File.join(DOCS, "proof_monitor.csv"))

download_summary = {
  "hot-download-pdf-table-extraction-starter" => "observed release interest: preview downloads=2 and close-ready downloads=1",
  "hot-download-local-seo-gbp-audit-starter" => "observed release interest: preview downloads=2 and close-ready downloads=0"
}

proof_rows.each do |row|
  next unless row["kind"]&.include?("download") || row["kind"]&.include?("release_asset")

  title = row["title"].to_s.downcase
  if title.include?("pdf")
    key = "hot-download-pdf-table-extraction-starter"
  elsif title.include?("local seo")
    key = "hot-download-local-seo-gbp-audit-starter"
  else
    next
  end
  next if row["release_downloads"].to_s.empty?

  # Keep the short public summary stable; exact rows remain in proof_monitor.csv.
  download_summary[key] ||= "release-download interest exists; see proof monitor"
end

route_ids = [
  "hot-download-pdf-table-extraction-starter",
  "hot-download-local-seo-gbp-audit-starter",
  "central-first-100-fast-start",
  "central-first-100-product-bundle",
  "central-data-cleanup-sprint",
  "central-automation-blueprint"
]

route_notes = {
  "hot-download-pdf-table-extraction-starter" => {
    "primary_url" => url("pdf-table-download-intent-close.html"),
    "why" => "Warmest observed route: someone already reached the PDF/Table download path, and one close-ready packet has been downloaded.",
    "decision" => "Use first when the buyer has an authorized PDF, screenshot, or messy table and wants CSV/XLSX output."
  },
  "hot-download-local-seo-gbp-audit-starter" => {
    "primary_url" => url("local-seo-download-intent-close.html"),
    "why" => "Highest single-order price among observed download-interest paths; one accepted $175 audit clears the $100 target before fees/refunds.",
    "decision" => "Use first when the buyer has a public local business/profile URL and wants an audit without login access."
  },
  "central-first-100-fast-start" => {
    "why" => "Exact $100 service route with no catalog browsing and four fixed mini-scopes.",
    "decision" => "Use when the buyer wants the smallest accepted service order that can hit $100 gross."
  },
  "central-first-100-product-bundle" => {
    "why" => "Exact $100 product-transfer route; private ZIP delivery is already defined behind acceptance and proof gates.",
    "decision" => "Use when the buyer wants prepared product assets rather than custom service work."
  },
  "central-data-cleanup-sprint" => {
    "why" => "One $125 accepted cleanup sprint clears $100 and has a concrete before/after delivery shape.",
    "decision" => "Use when the buyer has an authorized spreadsheet or CSV and wants cleaned output plus QA counts."
  },
  "central-automation-blueprint" => {
    "why" => "One exact $100 blueprint can be delivered from public or buyer-provided non-sensitive workflow details.",
    "decision" => "Use when the buyer needs a plan before building in Make, Zapier, scripts, or internal tooling."
  }
}

routes = route_ids.each_with_index.map do |route_id, index|
  source = signal_by_id.fetch(route_id)
  note = route_notes.fetch(route_id)
  primary_url = note["primary_url"] || source.fetch("primary_url")
  {
    "generated_at_jst" => STAMP,
    "rank" => (index + 1).to_s,
    "route_id" => route_id,
    "title" => source.fetch("title"),
    "price" => source.fetch("price"),
    "why_this_is_close" => [note["why"], download_summary[route_id]].compact.join(" "),
    "decision_rule" => note["decision"],
    "next_paid_step" => primary_url,
    "ready_to_pay_form" => source.fetch("buyer_action_url"),
    "payment_packet" => source.fetch("payment_packet_url"),
    "payment_activation" => source.fetch("payment_activation_url"),
    "proof_required" => source.fetch("buyer_gate"),
    "money_confirmed_usd" => "0",
    "money_count_rule" => source.fetch("proof_rule")
  }
end

headers = %w[
  generated_at_jst rank route_id title price why_this_is_close decision_rule next_paid_step
  ready_to_pay_form payment_packet payment_activation proof_required money_confirmed_usd money_count_rule
]
write_csv(File.join(DOCS, CSV_NAME), headers, routes)

route_cards = routes.map do |route|
  <<~HTML
    <article class="panel">
      <span class="eyebrow">Rank #{h(route["rank"])} / #{h(route["price"])}</span>
      <h2>#{h(route["title"])}</h2>
      <p>#{h(route["why_this_is_close"])}</p>
      <p><strong>Use when:</strong> #{h(route["decision_rule"])}</p>
      <p><strong>Proof gate:</strong> #{h(route["proof_required"])}</p>
      <p class="buttons"><a href="#{h(route["next_paid_step"])}">Open close route</a><a href="#{h(route["ready_to_pay_form"])}">Open ready-to-pay form</a><a href="#{h(route["payment_packet"])}">Payment packet</a><a href="#{h(route["payment_activation"])}">Payment activation</a></p>
    </article>
  HTML
end.join

page = <<~HTML
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Fastest buyer-facing paths to a verified $100 paid order for Micro Offer Studio.">
    <link rel="canonical" href="#{h(url(PAGE))}">
    <title>Fastest $100 Start - Micro Offer Studio</title>
    <style>
      :root{--ink:#17202a;--muted:#5d6875;--line:#d9dfeb;--panel:#f6f8fb;--accent:#075da8;--green:#17643a;--gold:#8a5a00}
      *{box-sizing:border-box}body{margin:0;color:var(--ink);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.45;background:#fff}main{width:min(1180px,calc(100% - 32px));margin:0 auto;padding:28px 0 48px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:20px}h1{margin:0 0 8px;font-size:clamp(1.8rem,4vw,2.75rem);letter-spacing:0}h2{margin:0 0 10px;font-size:1.22rem;letter-spacing:0}p{margin:0 0 10px}a{color:var(--accent);overflow-wrap:anywhere}.muted{color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.panel,.notice{border:1px solid var(--line);border-radius:8px;background:#fff;padding:12px;min-width:0;overflow-wrap:anywhere}.panel{border-left:6px solid var(--accent)}.notice{border-left:6px solid var(--gold);background:#fffaf0}.buttons{display:flex;gap:8px;flex-wrap:wrap}.buttons a{display:inline-block;border:1px solid var(--line);border-radius:8px;padding:8px 10px;background:#fff;text-decoration:none;font-weight:700}.eyebrow{display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.04em}.flow{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin:14px 0}.flow div{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:10px}.flow strong{display:block;margin-bottom:4px}table{width:100%;border-collapse:collapse;border:1px solid var(--line);background:#fff;margin-top:14px}th,td{padding:9px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top;font-size:.9rem;overflow-wrap:anywhere}th{background:var(--panel);color:var(--muted);font-size:.74rem;text-transform:uppercase;letter-spacing:.04em}
      @media(max-width:900px){.grid,.flow{grid-template-columns:1fr}.buttons{display:grid}.buttons a{width:100%}table,thead,tbody,tr,th,td{display:block}thead{display:none}tr{border-bottom:1px solid var(--line);padding:8px 0}td{border-bottom:0;padding:6px 9px}td::before{content:attr(data-label);display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase}}
    </style>
    <script type="application/ld+json">
    #{JSON.pretty_generate({
      "@context" => "https://schema.org",
      "@type" => "ItemList",
      "name" => "Fastest $100 buyer start",
      "url" => url(PAGE),
      "itemListElement" => routes.map do |route|
        {
          "@type" => "ListItem",
          "position" => route["rank"].to_i,
          "name" => route["title"],
          "url" => route["next_paid_step"]
        }
      end
    })}
    </script>
  </head>
  <body>
    <main>
      <header>
        <p class="buttons"><a href="index.html">Home</a><a href="pdf-table-download-intent-close.html">PDF close</a><a href="local-seo-download-intent-close.html">Local SEO close</a><a href="first-100-fast-start.html">Fast Start</a><a href="first-100-product-bundle.html">Product bundle</a><a href="payment-activation.html">Payment activation</a><a href="proof-monitor.html">Proof monitor</a><a href="#{h(CSV_NAME)}">CSV</a></p>
        <h1>Fastest $100 Start</h1>
        <p class="muted">A short buyer-facing route list for the closest current non-bounty paths to one verified $100+ paid order. This page does not process payment.</p>
      </header>
      <section class="notice">
        <h2>Money Boundary</h2>
        <p>Confirmed money remains $0. Count only real buyer acceptance, seller-owned external payment proof, delivery proof, and posted/released/payable/cleared funds after fees/refunds are known or disclosed.</p>
      </section>
      <section class="flow" aria-label="Paid order flow">
        <div><strong>1. Pick a route</strong><p>Use PDF/Table first for observed close-ready interest, Local SEO second for the highest single-order price, or exact $100 routes when the buyer wants a smaller decision.</p></div>
        <div><strong>2. Scope safely</strong><p>Use only public, synthetic, or buyer-authorized non-sensitive inputs. Do not request credentials or regulated private records.</p></div>
        <div><strong>3. Activate payment</strong><p>After accepted scope, use a seller-owned checkout, invoice, marketplace order, funded milestone, or payment request URL.</p></div>
        <div><strong>4. Deliver after proof</strong><p>Deliver only after payment proof exists, then save delivery and acceptance records before counting money.</p></div>
      </section>
      <section class="grid">#{route_cards}</section>
      <section>
        <h2>Machine-Readable Route Table</h2>
        <table><thead><tr><th>Rank</th><th>Route</th><th>Price</th><th>Why close</th><th>Start</th><th>Proof rule</th></tr></thead><tbody>
          #{routes.map do |route|
            <<~ROW
              <tr>
                <td data-label="Rank">#{h(route["rank"])}</td>
                <td data-label="Route">#{h(route["title"])}</td>
                <td data-label="Price">#{h(route["price"])}</td>
                <td data-label="Why close">#{h(route["why_this_is_close"])}</td>
                <td data-label="Start"><a href="#{h(route["next_paid_step"])}">close route</a></td>
                <td data-label="Proof rule">#{h(route["money_count_rule"])}</td>
              </tr>
            ROW
          end.join}
        </tbody></table>
      </section>
    </main>
  </body>
  </html>
HTML

File.write(File.join(DOCS, PAGE), page)

home_block = <<~HTML
  <section class="notice" id="fastest-100-start">
    <h2>Fastest $100 Start</h2>
    <p>A focused buyer route now ranks the six closest non-bounty paths to one verified $100+ order, starting with observed PDF/Table and Local SEO download-interest closes, then exact $100 fast-start and product-bundle routes.</p>
    <p class="buttons"><a href="fastest-100-start.html">Open fastest $100 start</a><a href="fastest_100_start.csv">CSV</a><a href="pdf-table-download-intent-close.html">PDF/Table $125 close</a><a href="local-seo-download-intent-close.html">Local SEO $175 close</a><a href="payment-activation.html">Payment activation</a><a href="proof-monitor.html">Proof monitor</a></p>
  </section>
HTML
index_path = File.join(DOCS, "index.html")
add_link_after(index_path, '<p class="buttons">', '<a href="fastest-100-start.html">Fastest $100 start</a>')
upsert_block(index_path, "fastest-100-start", home_block, "<!-- structured-ready-forms:start -->")

search_path = File.join(DOCS, "search-index.json")
if File.exist?(search_path)
  search = JSON.parse(File.read(search_path, encoding: "UTF-8"))
  document = {
    "type" => "fastest_100_buyer_start",
    "title" => "Fastest $100 Start",
    "slug" => "fastest-100-start",
    "url" => url(PAGE),
    "price" => "$100+",
    "amount_usd" => 100,
    "description" => "Focused buyer route for the closest current non-bounty paths to one verified $100+ paid order.",
    "first_100" => "Use the ranked route list; count $0 until external payment proof exists.",
    "start_order_url" => routes.first.fetch("ready_to_pay_form"),
    "proof_rule" => "Counts $0 until real buyer acceptance, seller-owned payment proof, delivery proof, and posted/released/payable funds exist."
  }
  docs = search.fetch("documents", []).reject { |row| row["slug"] == "fastest-100-start" }
  search["documents"] = [document] + docs
  File.write(search_path, JSON.pretty_generate(search))
end

structured_path = File.join(DOCS, "structured-data.json")
if File.exist?(structured_path)
  structured = JSON.parse(File.read(structured_path, encoding: "UTF-8"))
  graph = structured.fetch("@graph", []).reject { |row| row["url"] == url(PAGE) }
  graph.unshift(
    "@type" => "WebPage",
    "name" => "Fastest $100 Start",
    "url" => url(PAGE),
    "description" => "Focused buyer route for the closest current non-bounty paths to one verified $100+ paid order."
  )
  structured["@graph"] = graph
  File.write(structured_path, JSON.pretty_generate(structured))
end

llms_path = File.join(DOCS, "llms.txt")
if File.exist?(llms_path)
  llms = File.read(llms_path, encoding: "UTF-8")
  line = "- Fastest $100 Start: #{url(PAGE)}"
  unless llms.include?(line)
    llms = llms.sub("## Fastest paid paths\n", "## Fastest paid paths\n#{line}\n")
    File.write(llms_path, llms)
  end
end

feed_path = File.join(DOCS, "feed.xml")
if File.exist?(feed_path)
  feed = File.read(feed_path, encoding: "UTF-8")
  unless feed.include?(url(PAGE))
    item = <<~XML
      <item>
        <title>Fastest $100 Start</title>
        <link>#{h(url(PAGE))}</link>
        <guid>#{h(url(PAGE))}</guid>
        <pubDate>#{Time.now.rfc2822}</pubDate>
        <description>Focused buyer route for the closest non-bounty paths to one verified $100+ paid order. Confirmed money remains $0 until external proof exists.</description>
      </item>
    XML
    feed = feed.sub("</channel>", "#{item}\n    </channel>")
    File.write(feed_path, feed)
  end
end

add_indexnow_url(PAGE)
add_indexnow_url(CSV_NAME)

funding_path = File.join(LAUNCH_ROOT, ".github", "FUNDING.yml")
FileUtils.mkdir_p(File.dirname(funding_path))
File.write(funding_path, <<~YAML)
  # Routes GitHub's funding surface to the closest public paid-order paths.
  # These are not payment links; external payment proof is still required.
  custom:
    - #{url(PAGE)}
    - #{url("pdf-table-download-intent-close.html")}
    - #{url("local-seo-download-intent-close.html")}
    - #{url("payment-activation")}
YAML

config_path = File.join(LAUNCH_ROOT, ".github", "ISSUE_TEMPLATE", "config.yml")
if File.exist?(config_path)
  config = File.read(config_path, encoding: "UTF-8")
  unless config.include?("Fastest $100 buyer start")
    entry = <<~YAML
        - name: Fastest $100 buyer start
          url: #{url(PAGE)}
          about: Start with the ranked shortest paths to one verified $100+ paid order before choosing a specific form.
    YAML
    config = config.sub("contact_links:\n", "contact_links:\n#{entry}")
    File.write(config_path, config)
  end
end

puts "wrote #{File.join(DOCS, PAGE)}"
puts "wrote #{File.join(DOCS, CSV_NAME)}"
puts "routes=#{routes.length}"
