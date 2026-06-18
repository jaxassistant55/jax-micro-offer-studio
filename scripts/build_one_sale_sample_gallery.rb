#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "csv"
require "json"
require "rexml/document"
require "time"

ENV["TZ"] = "Asia/Tokyo"

ROOT = File.expand_path("..", __dir__)
DOCS = File.join(ROOT, "docs")
SITE = "https://jaxassistant55.github.io/jax-micro-offer-studio/"
STAMP = Time.now.strftime("%Y-%m-%d %H:%M:%S JST")
GALLERY_PATH = "one-sale-sample-output-gallery.html"
CSV_PATH = "one_sale_sample_output_gallery.csv"
JSON_PATH = "one_sale_sample_output_gallery.json"
RELEASE_TAG = "one-sale-sample-output-gallery-v1"
RELEASE_URL = "https://github.com/jaxassistant55/jax-micro-offer-studio/releases/tag/#{RELEASE_TAG}"

def h(value)
  CGI.escapeHTML(value.to_s)
end

def url(path)
  "#{SITE}#{path}"
end

def read_csv(path)
  CSV.read(path, headers: true).map(&:to_h)
end

def upsert_block(path, marker, block, fallback_pattern)
  html = File.read(path)
  start = "<!-- #{marker}:start -->"
  finish = "<!-- #{marker}:end -->"
  wrapped = "#{start}\n#{block.strip}\n#{finish}"
  if html.include?(start)
    html = html.sub(/<!-- #{Regexp.escape(marker)}:start -->.*?<!-- #{Regexp.escape(marker)}:end -->/m, wrapped)
  else
    html = html.sub(fallback_pattern, "#{wrapped}\n\\0")
  end
  File.write(path, html)
end

def add_urls_to_sitemap(urls)
  path = File.join(DOCS, "sitemap.xml")
  doc = REXML::Document.new(File.read(path))
  existing = doc.root.get_elements("url/loc").map { |loc| loc.text.to_s.strip }.reject(&:empty?)
  all = (existing + urls).uniq
  xml = +"<?xml version='1.0' encoding='UTF-8'?>\n<urlset xmlns='http://www.sitemaps.org/schemas/sitemap/0.9'>\n"
  all.each { |entry| xml << "  <url>\n    <loc>#{h(entry)}</loc>\n  </url>\n" }
  xml << "</urlset>\n"
  File.write(path, xml)
end

def add_urls_to_indexnow(urls)
  path = File.join(DOCS, "indexnow_payload.json")
  payload = JSON.parse(File.read(path))
  payload["urlList"] = (payload.fetch("urlList", []) + urls).uniq.sort
  File.write(path, JSON.pretty_generate(payload))
end

def add_search_documents(documents)
  path = File.join(DOCS, "search-index.json")
  index = JSON.parse(File.read(path))
  existing = index.fetch("documents", [])
  incoming = documents.to_h { |document| [document.fetch("url"), document] }
  index["documents"] = existing.reject { |document| incoming.key?(document["url"]) } + documents
  index["generated_at_jst"] = STAMP
  File.write(path, JSON.pretty_generate(index))
end

def style
  <<~CSS
    :root{--ink:#17202a;--muted:#5d6875;--line:#d9dfeb;--panel:#f6f8fb;--blue:#075da8;--green:#17643a;--gold:#8a5a00;--violet:#5d3f8f}
    *{box-sizing:border-box}body{margin:0;background:#fff;color:var(--ink);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.45}main{width:min(1180px,calc(100% - 32px));margin:0 auto;padding:28px 0 52px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:18px}h1{margin:0 0 8px;font-size:clamp(1.8rem,4vw,2.6rem);letter-spacing:0}h2{font-size:1.2rem;margin:24px 0 10px;letter-spacing:0}h3{font-size:1rem;margin:0 0 7px;letter-spacing:0}p{margin:0 0 10px;overflow-wrap:anywhere}a{color:var(--blue);overflow-wrap:anywhere}.muted{color:var(--muted)}.buttons{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0}.buttons a{display:inline-block;border:1px solid var(--line);border-radius:8px;background:#fff;padding:8px 10px;text-decoration:none;font-weight:700}.summary,.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}.metric,.panel,.notice{border:1px solid var(--line);border-radius:8px;background:#fff;padding:12px;min-width:0;overflow-wrap:anywhere}.metric{background:var(--panel)}.metric span,.eyebrow{display:block;color:var(--muted);font-size:.72rem;font-weight:800;text-transform:uppercase;letter-spacing:.04em}.metric strong{display:block;margin-top:5px;font-size:1.18rem}.notice{border-left:6px solid var(--gold);background:#fffaf0}.panel{border-left:6px solid var(--green)}.panel.violet{border-left-color:var(--violet);background:#fbf9ff}.samples{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.sample{border:1px solid var(--line);border-left:6px solid var(--blue);border-radius:8px;padding:12px;background:#fff;min-width:0;overflow-wrap:anywhere}.sample.service{border-left-color:var(--green)}.sample.product{border-left-color:var(--violet)}.tag{display:inline-block;border:1px solid var(--line);border-radius:999px;background:var(--panel);padding:3px 8px;margin:0 4px 5px 0;font-size:.78rem;font-weight:700;color:var(--muted)}table{width:100%;border-collapse:collapse;border:1px solid var(--line);background:#fff;margin:10px 0}th,td{border-bottom:1px solid var(--line);padding:9px;text-align:left;vertical-align:top;font-size:.9rem;overflow-wrap:anywhere}th{background:var(--panel);color:var(--muted);font-size:.74rem;text-transform:uppercase;letter-spacing:.04em}.copybox{white-space:pre-wrap;border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:10px;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.86rem;overflow:auto}ol{margin:8px 0 0;padding-left:22px}li{margin:6px 0}
    @media(max-width:900px){main{width:min(100% - 20px,1180px)}.summary,.grid,.samples{grid-template-columns:1fr}.buttons{display:grid}.buttons a{width:100%}table,thead,tbody,tr,th,td{display:block}thead{display:none}tr{border-bottom:1px solid var(--line);padding:8px 0}td{border-bottom:0;padding:6px 9px}td::before{content:attr(data-label);display:block;color:var(--muted);font-size:.72rem;font-weight:800;text-transform:uppercase}}
  CSS
end

def sample_for(title, offer_type)
  text = title.downcase
  case text
  when /static|site/
    ["Homepage wireframe snapshot", "Service section, contact path, mobile pass, launch checklist", "Buyer receives a static page skeleton, copy placement notes, responsive QA notes, and handoff checklist."]
  when /local seo|gbp/
    ["Public local audit snapshot", "Service area, category fit, citation consistency, review path", "Buyer receives ranked public findings and owner-only action steps without account login."]
  when /workflow|automation/
    ["Workflow map and tracker spec", "Trigger list, status fields, owner tasks, risk notes", "Buyer receives a workflow blueprint or tracker outline ready for internal implementation."]
  when /quote|estimator/
    ["Estimator rules table", "Inputs, formula assumptions, output bands, edge-case notes", "Buyer receives a scoped estimator model with validation notes and implementation checklist."]
  when /technical docs|docs/
    ["Documentation cleanup diff plan", "Missing steps, unclear terms, quick-start order, acceptance checklist", "Buyer receives a prioritized docs cleanup plan plus revised sample sections."]
  when /website audit/
    ["Website audit punch list", "Above-fold clarity, CTA path, trust signals, performance notes", "Buyer receives a concise public-site audit with fixes ranked by buyer effort."]
  when /career|resume|linkedin|interview/
    ["Career packet outline", "Headline, proof bullets, interview story bank, follow-up copy", "Buyer receives edited positioning drafts and a concise interview prep sheet."]
  when /client intake|sop/
    ["Intake and SOP packet", "Client fields, handoff steps, status stages, reusable checklist", "Buyer receives a practical intake form and SOP skeleton for repeatable work."]
  when /data cleanup/
    ["Data cleanup report", "Column map, anomaly flags, normalized sample rows, QA checks", "Buyer receives cleaned sample data, change notes, and a repeatable cleanup checklist."]
  when /pdf|table/
    ["Extracted table preview", "Source page, row labels, normalized CSV, ambiguity notes", "Buyer receives CSV/XLSX output for accepted files plus extraction notes."]
  when /resale/
    ["Listing research packet", "Title options, comparable price band, photo checklist, risk notes", "Buyer receives listing-ready copy and a pricing worksheet."]
  when /subscription|savings/
    ["Savings action log", "Plan, renewal date, downgrade/cancel path, proof fields", "Buyer receives a savings checklist and proof log for owner-only account actions."]
  when /translation|localization/
    ["Localization draft pack", "Tone notes, glossary, translated sample, review checklist", "Buyer receives a draft localization pack with review notes, not certified translation."]
  when /browser extension/
    ["Extension starter handoff", "Manifest fields, popup copy, install notes, transfer checklist", "Buyer receives a template transfer packet and setup checklist."]
  when /mini course/
    ["Workbook preview", "Lesson map, exercise pages, checklist, buyer handoff", "Buyer receives a workbook pack ready for private delivery after payment."]
  when /csv cli/
    ["CLI toolkit handoff", "Command list, sample input/output, install notes, QA checklist", "Buyer receives a small toolkit package with usage notes and sample files."]
  when /invoice|expense/
    ["Tracker template sample", "Invoice fields, expense categories, totals, reconciliation notes", "Buyer receives a spreadsheet-style template and setup guide."]
  when /prompt|workflow/
    ["Prompt workflow pack", "Use case map, prompt set, QA checklist, revision notes", "Buyer receives reusable prompt/workflow assets with scope limits."]
  when /sales enablement/
    ["Sales enablement kit", "Offer one-liner, objection replies, follow-up sequence, CRM fields", "Buyer receives a concise sales packet for a single offer."]
  else
    if offer_type == "product"
      ["Product transfer preview", "Files, README, license note, handoff checklist", "Buyer receives the prepared product packet after accepted terms and external payment proof."]
    else
      ["Fixed-scope service sample", "Inputs, deliverable outline, QA notes, acceptance checklist", "Buyer receives the scoped service deliverable after accepted terms and external payment proof."]
    end
  end
end

rows = read_csv(File.join(DOCS, "one-sale-to-100.csv"))
sample_rows = rows.map do |row|
  sample_title, sample_fields, sample_deliverable = sample_for(row["title"], row["offer_type"])
  {
    "generated_at_jst" => STAMP,
    "rank" => row["rank"],
    "catalog_row_id" => row["catalog_row_id"],
    "title" => row["title"],
    "offer_type" => row["offer_type"],
    "price" => row["price"],
    "amount_usd" => row["amount_usd"],
    "sample_title" => sample_title,
    "sample_fields" => sample_fields,
    "sample_deliverable" => sample_deliverable,
    "primary_url" => row["primary_url"],
    "ready_to_pay_url" => row["structured_form_url"],
    "order_board_url" => row["order_board_url"],
    "payment_activation_url" => row["payment_activation_url"],
    "proof_rule" => "Synthetic sample only. Count money only after real buyer acceptance, seller-controlled external payment proof, delivery proof, and posted/released/payable/cleared funds.",
    "money_confirmed_usd" => "0"
  }
end

CSV.open(File.join(DOCS, CSV_PATH), "w") do |csv|
  csv << sample_rows.first.keys
  sample_rows.each { |row| csv << row.values }
end

File.write(File.join(DOCS, JSON_PATH), JSON.pretty_generate(
  "generated_at_jst" => STAMP,
  "money_confirmed_usd" => 0,
  "proof_rule" => "Synthetic sample-output gallery only; page views, downloads, issues, and samples count $0.",
  "routes" => sample_rows
))

cards = sample_rows.map do |row|
  <<~HTML
    <article class="sample #{h(row["offer_type"])}" id="#{h(row["catalog_row_id"])}">
      <p><span class="tag">Rank #{h(row["rank"])}</span><span class="tag">#{h(row["offer_type"])}</span><span class="tag">#{h(row["price"])}</span></p>
      <h3>#{h(row["title"])}</h3>
      <p><strong>Sample output:</strong> #{h(row["sample_title"])}</p>
      <p><strong>Fields shown:</strong> #{h(row["sample_fields"])}</p>
      <p><strong>Paid deliverable shape:</strong> #{h(row["sample_deliverable"])}</p>
      <p class="buttons"><a href="#{h(row["primary_url"])}">Offer page</a><a href="#{h(row["ready_to_pay_url"])}">Ready-to-pay form</a><a href="#{h(row["order_board_url"])}">Order board</a></p>
    </article>
  HTML
end.join("\n")

top_table = sample_rows.first(12).map do |row|
  <<~HTML
    <tr>
      <td data-label="Rank">#{h(row["rank"])}</td>
      <td data-label="Offer"><a href="##{h(row["catalog_row_id"])}">#{h(row["title"])}</a></td>
      <td data-label="Price">#{h(row["price"])}</td>
      <td data-label="Sample">#{h(row["sample_title"])}</td>
      <td data-label="Action"><a href="#{h(row["ready_to_pay_url"])}">Ready-to-pay form</a></td>
    </tr>
  HTML
end.join

schema = {
  "@context" => "https://schema.org",
  "@type" => "ItemList",
  "name" => "One Sale Sample Output Gallery",
  "url" => url(GALLERY_PATH),
  "description" => "Synthetic sample-output previews for one-sale-to-$100 paid routes.",
  "numberOfItems" => sample_rows.length,
  "itemListElement" => sample_rows.map do |row|
    {
      "@type" => "ListItem",
      "position" => row["rank"].to_i,
      "item" => {
        "@type" => row["offer_type"] == "product" ? "Product" : "Service",
        "name" => row["title"],
        "url" => row["primary_url"],
        "offers" => {
          "@type" => "Offer",
          "priceCurrency" => "USD",
          "price" => row["amount_usd"].to_f,
          "url" => row["ready_to_pay_url"],
          "availability" => "https://schema.org/InStock"
        }
      }
    }
  end
}

html = <<~HTML
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Synthetic sample-output previews for #{sample_rows.length} one-sale-to-$100 Micro Offer Studio routes.">
    <meta property="og:title" content="One Sale Sample Output Gallery - Micro Offer Studio">
    <meta property="og:description" content="Inspect buyer-facing sample deliverable shapes before opening a ready-to-pay form.">
    <meta property="og:type" content="website">
    <link rel="canonical" href="#{url(GALLERY_PATH)}">
    <link rel="alternate" type="application/json" title="One sale sample output gallery JSON" href="#{JSON_PATH}">
    <link rel="alternate" type="text/csv" title="One sale sample output gallery CSV" href="#{CSV_PATH}">
    <title>One Sale Sample Output Gallery - Micro Offer Studio</title>
    <style>#{style}</style>
    <script type="application/ld+json">#{JSON.pretty_generate(schema)}</script>
  </head>
  <body>
    <main>
      <header>
        <p class="buttons"><a href="one-sale-to-100.html">One sale to $100</a><a href="ready-to-buy-signal-room.html">Signal room</a><a href="paid-offer-action-catalog.html">Paid catalog</a><a href="marketplace-listing-packets.html">Marketplace packets</a><a href="#{RELEASE_URL}">Release packet</a><a href="payment-activation">Payment activation</a><a href="proof-monitor.html">Proof monitor</a></p>
        <h1>One Sale Sample Output Gallery</h1>
        <p class="muted">Generated #{h(STAMP)}. These are synthetic sample-output previews for #{sample_rows.length} one-sale-to-$100 routes. They make the buyer decision more concrete, but they are not paid work, not private delivery, and not payment proof.</p>
        <section class="summary">
          <div class="metric"><span>Routes covered</span><strong>#{sample_rows.length}</strong></div>
          <div class="metric"><span>One-sale routes</span><strong>#{sample_rows.count { |row| row["amount_usd"].to_f >= 100 }}</strong></div>
          <div class="metric"><span>CSV/JSON</span><strong>Ready</strong></div>
          <div class="metric"><span>Confirmed money</span><strong>$0</strong></div>
        </section>
      </header>
      <section class="notice">
        <h2>Use This Before Opening Ready-To-Pay</h2>
        <p>A real buyer can inspect the sample deliverable shape, pick the closest route, then open the ready-to-pay form. Paid work starts only after accepted scope and seller-owned external payment proof. Page views, samples, downloads, GitHub issues, and IndexNow submissions still count $0.</p>
        <p>Routes covered: #{sample_rows.length}. Confirmed money remains $0 until external buyer/payment/delivery proof exists.</p>
        <p class="buttons"><a href="#{CSV_PATH}">Download CSV</a><a href="#{JSON_PATH}">Download JSON</a><a href="proof-monitor.html">Check proof monitor</a></p>
      </section>
      <section class="panel violet" id="release-packet">
        <h2>Downloadable Release Packet</h2>
        <p>The same gallery is packaged as a GitHub release with ZIP, CSV, JSON, and manifest assets. Release downloads are interest-only and count $0 until real buyer acceptance, seller-owned external payment proof, delivery proof, and posted/released/payable/cleared funds exist.</p>
        <p class="buttons"><a href="#{RELEASE_URL}">Open release</a><a href="#{RELEASE_URL}/download/#{RELEASE_TAG}/one-sale-sample-output-gallery-v1.zip">Download ZIP</a><a href="#{RELEASE_URL}/download/#{RELEASE_TAG}/one_sale_sample_output_gallery.csv">Download CSV</a><a href="#{RELEASE_URL}/download/#{RELEASE_TAG}/one_sale_sample_output_gallery.json">Download JSON</a></p>
      </section>
      <section class="panel">
        <h2>Fastest High-Value Samples</h2>
        <table>
          <thead><tr><th>Rank</th><th>Offer</th><th>Price</th><th>Sample</th><th>Action</th></tr></thead>
          <tbody>#{top_table}</tbody>
        </table>
      </section>
      <section>
        <h2>All Sample Outputs</h2>
        <div class="samples">
          #{cards}
        </div>
      </section>
    </main>
  </body>
  </html>
HTML

File.write(File.join(DOCS, GALLERY_PATH), html)

block = <<~HTML
  <section class="notice" id="one-sale-sample-gallery">
    <h2>One-sale sample-output gallery</h2>
    <p>#{sample_rows.length} one-sale-to-$100 routes now have synthetic sample deliverable previews before the ready-to-pay step. These previews reduce scope uncertainty while preserving the $0 proof boundary.</p>
    <p class="buttons"><a href="#{GALLERY_PATH}">Open sample gallery</a><a href="#{CSV_PATH}">CSV</a><a href="#{JSON_PATH}">JSON</a><a href="#{RELEASE_URL}">Release packet</a><a href="proof-monitor.html">Proof monitor</a></p>
  </section>
HTML

%w[
  index.html
  one-sale-to-100.html
  ready-to-buy-signal-room.html
  paid-offer-action-catalog.html
  marketplace-listing-packets.html
].each do |filename|
  upsert_block(File.join(DOCS, filename), "one-sale-sample-gallery", block, /<section/)
end

new_urls = [url(GALLERY_PATH), url(CSV_PATH), url(JSON_PATH)]
add_urls_to_sitemap(new_urls)
add_urls_to_indexnow(new_urls)
add_search_documents([
  {
    "type" => "one_sale_sample_output_gallery",
    "title" => "One Sale Sample Output Gallery",
    "url" => url(GALLERY_PATH),
    "description" => "Synthetic sample-output previews for #{sample_rows.length} one-sale-to-$100 buyer routes.",
    "tags" => %w[first-100 sample-output ready-to-pay buyer-action]
  },
  {
    "type" => "one_sale_sample_output_gallery_csv",
    "title" => "One Sale Sample Output Gallery CSV",
    "url" => url(CSV_PATH),
    "description" => "Machine-readable sample-output previews and ready-to-pay links for the one-sale route set.",
    "tags" => %w[first-100 csv sample-output]
  },
  {
    "type" => "one_sale_sample_output_gallery_json",
    "title" => "One Sale Sample Output Gallery JSON",
    "url" => url(JSON_PATH),
    "description" => "JSON sample-output previews and ready-to-pay links for the one-sale route set.",
    "tags" => %w[first-100 json sample-output]
  }
])

puts "Wrote #{GALLERY_PATH}, #{CSV_PATH}, and #{JSON_PATH}"
puts "Routes covered: #{sample_rows.length}"
