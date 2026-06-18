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

def h(value)
  CGI.escapeHTML(value.to_s)
end

def url(path)
  "#{SITE}#{path}"
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
  incoming_by_url = documents.to_h { |document| [document.fetch("url"), document] }
  merged = existing.reject { |document| incoming_by_url.key?(document["url"]) } + documents
  index["documents"] = merged
  index["generated_at_jst"] = STAMP
  File.write(path, JSON.pretty_generate(index))
end

def base_style
  <<~CSS
    :root{--ink:#17202a;--muted:#5d6875;--line:#d9dfeb;--panel:#f6f8fb;--blue:#075da8;--green:#17643a;--gold:#8a5a00;--violet:#5d3f8f}
    *{box-sizing:border-box}body{margin:0;background:#fff;color:var(--ink);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.45}main{width:min(1080px,calc(100% - 32px));margin:0 auto;padding:28px 0 52px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:18px}h1{margin:0 0 8px;font-size:clamp(1.8rem,4vw,2.55rem);letter-spacing:0}h2{font-size:1.18rem;margin:24px 0 10px;letter-spacing:0}h3{font-size:1rem;margin:0 0 7px;letter-spacing:0}p{margin:0 0 10px}a{color:var(--blue);overflow-wrap:anywhere}.muted{color:var(--muted)}.buttons{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0}.buttons a{display:inline-block;border:1px solid var(--line);border-radius:8px;background:#fff;padding:8px 10px;text-decoration:none;font-weight:700}.summary,.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.metric,.panel,.notice{border:1px solid var(--line);border-radius:8px;background:#fff;padding:12px;min-width:0;overflow-wrap:anywhere}.metric{background:var(--panel)}.metric span,.eyebrow{display:block;color:var(--muted);font-size:.72rem;font-weight:800;text-transform:uppercase;letter-spacing:.04em}.metric strong{display:block;margin-top:5px;font-size:1.18rem}.notice{border-left:6px solid var(--gold);background:#fffaf0}.panel{border-left:6px solid var(--green)}.panel.violet{border-left-color:var(--violet);background:#fbf9ff}.strip{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin:14px 0}.strip div{border:1px solid var(--line);border-radius:8px;background:var(--panel);min-height:86px;padding:12px}table{width:100%;border-collapse:collapse;border:1px solid var(--line);background:#fff;margin:10px 0}th,td{border-bottom:1px solid var(--line);padding:9px;text-align:left;vertical-align:top;font-size:.92rem;overflow-wrap:anywhere}th{background:var(--panel);color:var(--muted);font-size:.74rem;text-transform:uppercase;letter-spacing:.04em}.copybox{white-space:pre-wrap;border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:10px;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.88rem;overflow:auto}ol{margin:8px 0 0;padding-left:22px}li{margin:7px 0}
    @media(max-width:760px){main{width:min(100% - 20px,1080px)}.summary,.grid,.strip{grid-template-columns:1fr}.buttons{display:grid}.buttons a{width:100%}table,thead,tbody,tr,th,td{display:block}thead{display:none}tr{border-bottom:1px solid var(--line);padding:8px 0}td{border-bottom:0;padding:6px 9px}td::before{content:attr(data-label);display:block;color:var(--muted);font-size:.72rem;font-weight:800;text-transform:uppercase}}
  CSS
end

def pdf_page
  <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="description" content="Synthetic PDF/Table Extraction sample output for buyers evaluating the $125 fixed-scope service.">
      <meta property="og:title" content="PDF/Table Sample Output">
      <meta property="og:description" content="A concrete sample of the extracted table, ambiguity notes, QA checklist, and payment-proof boundary.">
      <meta property="og:type" content="website">
      <link rel="canonical" href="#{url("pdf-table-sample-output.html")}">
      <title>PDF/Table Sample Output</title>
      <style>#{base_style}</style>
    </head>
    <body>
      <main>
        <header>
          <p class="buttons"><a href="pdf-table-download-intent-close.html">After-download close</a><a href="pdf-table-extraction.html">Paid offer</a><a href="pdf-table-extraction-terms.html">Terms</a><a href="payment-activation.html">Payment activation</a><a href="proof-monitor.html">Proof monitor</a></p>
          <h1>PDF/Table Sample Output</h1>
          <p class="muted">Generated #{h(STAMP)}. This is synthetic demonstration material for the $125 fixed-scope PDF/Table Extraction service. It is not a customer file, not paid delivery, and not payment proof.</p>
          <section class="summary">
            <div class="metric"><span>Fixed price</span><strong>$125</strong></div>
            <div class="metric"><span>First $100 path</span><strong>1 paid order</strong></div>
            <div class="metric"><span>Buyer input</span><strong>Public or authorized PDF</strong></div>
            <div class="metric"><span>Confirmed money</span><strong>$0</strong></div>
          </section>
        </header>
        <section class="notice">
          <h2>Use This Before Ready-To-Pay</h2>
          <p>A real buyer can compare this sample to the desired outcome, then open the ready-to-pay form only if the fixed scope is enough. Payment still requires a seller-owned external route and posted, released, payable, or cleared proof.</p>
          <p class="buttons"><a href="https://github.com/jaxassistant55/pdf-table-extraction-starter/issues/new?template=ready-to-pay-pdf-table-extraction.yml">Open ready-to-pay form</a><a href="pdf-table-download-intent-close.html">Open after-download path</a><a href="payment-activation.html">Payment activation after acceptance</a></p>
        </section>
        <section class="strip" aria-label="sample visual summary">
          <div><span class="eyebrow">Step 1</span><strong>Table found</strong><p>Source page and target columns are named before extraction.</p></div>
          <div><span class="eyebrow">Step 2</span><strong>CSV returned</strong><p>Rows are normalized, totals checked, and unclear cells are flagged.</p></div>
          <div><span class="eyebrow">Step 3</span><strong>Proof saved</strong><p>Delivery note, ambiguity log, and buyer acceptance record close the job.</p></div>
        </section>
        <section class="panel">
          <h2>Synthetic Extracted CSV Preview</h2>
          <table>
            <thead><tr><th>Source</th><th>Row</th><th>Item</th><th>Qty</th><th>Unit</th><th>Total</th><th>Note</th></tr></thead>
            <tbody>
              <tr><td data-label="Source">sample-01.pdf#page=1</td><td data-label="Row">1</td><td data-label="Item">Workshop setup</td><td data-label="Qty">1</td><td data-label="Unit">$75</td><td data-label="Total">$75</td><td data-label="Note">Clean row</td></tr>
              <tr><td data-label="Source">sample-01.pdf#page=1</td><td data-label="Row">2</td><td data-label="Item">Template customization</td><td data-label="Qty">2</td><td data-label="Unit">$25</td><td data-label="Total">$50</td><td data-label="Note">Clean row</td></tr>
              <tr><td data-label="Source">sample-01.pdf#page=2</td><td data-label="Row">3</td><td data-label="Item">QA pass</td><td data-label="Qty">1</td><td data-label="Unit">$40</td><td data-label="Total">$40</td><td data-label="Note">Ambiguous tax field omitted</td></tr>
            </tbody>
          </table>
        </section>
        <section class="grid">
          <article class="panel"><h2>Included After Payment</h2><ol><li>Extracted CSV/XLSX for the accepted sample.</li><li>Ambiguity notes for unclear cells.</li><li>Source page/row references.</li><li>Repeatable extraction checklist.</li></ol></article>
          <article class="panel violet"><h2>Not Included</h2><ol><li>Private regulated records through public GitHub.</li><li>Large-batch OCR or custom software.</li><li>Credential/account access.</li><li>Extra revisions outside accepted scope.</li></ol></article>
        </section>
        <section class="panel">
          <h2>Acceptance Statement</h2>
          <div class="copybox">I accept the PDF/Table Extraction fixed-scope terms at $125. I understand work starts only after seller-owned external payment proof exists; I will provide only public or buyer-owned/buyer-authorized non-sensitive documents through an approved channel; the deliverable is limited to extracted CSV/XLSX output, ambiguity notes, and a repeatable extraction checklist for the accepted sample.</div>
        </section>
      </main>
    </body>
    </html>
  HTML
end

def local_seo_page
  <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="description" content="Synthetic Local SEO / GBP Audit sample output for buyers evaluating the $175 fixed-scope audit.">
      <meta property="og:title" content="Local SEO Sample Output">
      <meta property="og:description" content="A concrete sample of the public audit snapshot, priority matrix, and payment-proof boundary.">
      <meta property="og:type" content="website">
      <link rel="canonical" href="#{url("local-seo-sample-output.html")}">
      <title>Local SEO Sample Output</title>
      <style>#{base_style}</style>
    </head>
    <body>
      <main>
        <header>
          <p class="buttons"><a href="local-seo-download-intent-close.html">After-download close</a><a href="local-seo-gbp-audit.html">Paid offer</a><a href="local-seo-gbp-audit-terms.html">Terms</a><a href="payment-activation.html">Payment activation</a><a href="proof-monitor.html">Proof monitor</a></p>
          <h1>Local SEO Sample Output</h1>
          <p class="muted">Generated #{h(STAMP)}. This is synthetic demonstration material for the $175 fixed-scope Local SEO / GBP Audit. It is not a customer file, not paid delivery, and not payment proof.</p>
          <section class="summary">
            <div class="metric"><span>Fixed price</span><strong>$175</strong></div>
            <div class="metric"><span>First $100 path</span><strong>1 paid order</strong></div>
            <div class="metric"><span>Buyer input</span><strong>Public business footprint</strong></div>
            <div class="metric"><span>Confirmed money</span><strong>$0</strong></div>
          </section>
        </header>
        <section class="notice">
          <h2>Use This Before Ready-To-Pay</h2>
          <p>A real buyer can compare this sample to the desired audit shape, then open the ready-to-pay form only if the fixed scope is enough. Payment still requires a seller-owned external route and posted, released, payable, or cleared proof.</p>
          <p class="buttons"><a href="https://github.com/jaxassistant55/local-seo-gbp-audit-starter/issues/new?template=ready-to-pay-local-seo-gbp-audit.yml">Open ready-to-pay form</a><a href="local-seo-download-intent-close.html">Open after-download path</a><a href="payment-activation.html">Payment activation after acceptance</a></p>
        </section>
        <section class="strip" aria-label="sample visual summary">
          <div><span class="eyebrow">Step 1</span><strong>Public scan</strong><p>Website, public profile, service area, and review path are checked.</p></div>
          <div><span class="eyebrow">Step 2</span><strong>Priority matrix</strong><p>Findings are ranked by buyer impact and owner effort.</p></div>
          <div><span class="eyebrow">Step 3</span><strong>Owner actions</strong><p>Only owner-authorized profile and website changes are recommended.</p></div>
        </section>
        <section class="panel">
          <h2>Synthetic Audit Snapshot</h2>
          <table>
            <thead><tr><th>Area</th><th>Observation</th><th>Priority</th><th>Buyer action</th></tr></thead>
            <tbody>
              <tr><td data-label="Area">Homepage</td><td data-label="Observation">Primary service is visible but city is missing above the fold.</td><td data-label="Priority">High</td><td data-label="Buyer action">Add service plus city near the first call to action.</td></tr>
              <tr><td data-label="Area">Profile consistency</td><td data-label="Observation">Service area appears in footer but not near booking path.</td><td data-label="Priority">Medium</td><td data-label="Buyer action">Repeat service area beside contact options.</td></tr>
              <tr><td data-label="Area">Review path</td><td data-label="Observation">Public website has no visible review/profile link.</td><td data-label="Priority">Medium</td><td data-label="Buyer action">Add public profile and review link on contact page.</td></tr>
            </tbody>
          </table>
        </section>
        <section class="grid">
          <article class="panel"><h2>Included After Payment</h2><ol><li>Public website/profile observations.</li><li>Category, citation, review, and landing-page notes.</li><li>Prioritized next-action checklist.</li><li>Proof-ready delivery note.</li></ol></article>
          <article class="panel violet"><h2>Not Included</h2><ol><li>Google account login, claiming, or verification.</li><li>Fake reviews, review incentives, or ranking guarantees.</li><li>Paid ads or legal advice.</li><li>Publishing edits without owner action.</li></ol></article>
        </section>
        <section class="panel">
          <h2>Acceptance Statement</h2>
          <div class="copybox">I accept the Local SEO / GBP Audit fixed-scope terms at $175. I understand work starts only after seller-owned external payment proof exists; I will provide only public or buyer-authorized non-sensitive business details; the audit is limited to public website/profile review, category/citation/review/landing-page observations, and a prioritized action checklist.</div>
        </section>
      </main>
    </body>
    </html>
  HTML
end

sample_pages = [
  {
    path: "pdf-table-sample-output.html",
    title: "PDF/Table Sample Output",
    route: "PDF/Table Extraction",
    price: "$125",
    source: "pdf-table-download-intent-close.html",
    html: pdf_page
  },
  {
    path: "local-seo-sample-output.html",
    title: "Local SEO Sample Output",
    route: "Local SEO / GBP Audit",
    price: "$175",
    source: "local-seo-download-intent-close.html",
    html: local_seo_page
  }
]

sample_pages.each do |page|
  File.write(File.join(DOCS, page.fetch(:path)), page.fetch(:html))
end

CSV.open(File.join(DOCS, "warm_buyer_sample_outputs.csv"), "w") do |csv|
  csv << %w[generated_at_jst route price sample_url source_close_page money_confirmed_usd proof_rule]
  sample_pages.each do |page|
    csv << [
      STAMP,
      page.fetch(:route),
      page.fetch(:price),
      url(page.fetch(:path)),
      url(page.fetch(:source)),
      "0",
      "Synthetic sample output only; count money only after accepted scope, external payment proof, delivery proof, and posted/released/payable/cleared funds."
    ]
  end
end

pdf_block = <<~HTML
  <section class="panel violet" id="sample-output">
    <h2>Sample Output Preview</h2>
    <p>Before opening the ready-to-pay form, compare the synthetic sample output with the result you need. This reduces scope uncertainty but still counts $0 until external payment proof exists.</p>
    <p class="buttons"><a href="pdf-table-sample-output.html">View PDF/Table sample output</a><a href="warm_buyer_sample_outputs.csv">Sample-output CSV</a><a href="https://github.com/jaxassistant55/pdf-table-extraction-starter/issues/new?template=ready-to-pay-pdf-table-extraction.yml">Ready-to-pay form</a></p>
  </section>
HTML

local_block = <<~HTML
  <section class="panel violet" id="sample-output">
    <h2>Sample Output Preview</h2>
    <p>Before opening the ready-to-pay form, compare the synthetic sample output with the audit shape you need. This reduces scope uncertainty but still counts $0 until external payment proof exists.</p>
    <p class="buttons"><a href="local-seo-sample-output.html">View Local SEO sample output</a><a href="warm_buyer_sample_outputs.csv">Sample-output CSV</a><a href="https://github.com/jaxassistant55/local-seo-gbp-audit-starter/issues/new?template=ready-to-pay-local-seo-gbp-audit.yml">Ready-to-pay form</a></p>
  </section>
HTML

offer_pdf_block = <<~HTML
  <section class="notice" id="sample-output-preview">
    <h2>Sample Output Preview</h2>
    <p>See the synthetic PDF/Table delivery shape before opening a ready-to-pay issue. The sample is not a buyer file and not payment proof.</p>
    <p class="buttons"><a href="pdf-table-sample-output.html">Open sample output</a><a href="pdf-table-download-intent-close.html">After-download close path</a></p>
  </section>
HTML

offer_local_block = <<~HTML
  <section class="notice" id="sample-output-preview">
    <h2>Sample Output Preview</h2>
    <p>See the synthetic Local SEO audit shape before opening a ready-to-pay issue. The sample is not a buyer file and not payment proof.</p>
    <p class="buttons"><a href="local-seo-sample-output.html">Open sample output</a><a href="local-seo-download-intent-close.html">After-download close path</a></p>
  </section>
HTML

upsert_block(File.join(DOCS, "pdf-table-download-intent-close.html"), "warm-sample-output", pdf_block, /<section>\n        <h2>Close Sequence<\/h2>/)
upsert_block(File.join(DOCS, "local-seo-download-intent-close.html"), "warm-sample-output", local_block, /<section>\n        <h2>Close Sequence<\/h2>/)
upsert_block(File.join(DOCS, "hot-download-close-pdf-table-extraction-starter.html"), "warm-sample-output", pdf_block, /<section>\n          <h2>Exact Close Sequence<\/h2>/)
upsert_block(File.join(DOCS, "hot-download-close-local-seo-gbp-audit-starter.html"), "warm-sample-output", local_block, /<section>\n          <h2>Exact Close Sequence<\/h2>/)
upsert_block(File.join(DOCS, "pdf-table-extraction.html"), "warm-sample-output", offer_pdf_block, %r{</header>})
upsert_block(File.join(DOCS, "local-seo-gbp-audit.html"), "warm-sample-output", offer_local_block, %r{</header>})

index_block = <<~HTML
  <section class="notice" id="warm-buyer-sample-outputs">
    <h2>Warm Buyer Sample Outputs</h2>
    <p>PDF/Table and Local SEO now have route-specific synthetic sample-output pages linked from the observed-download close paths. These pages show what a paid buyer receives after payment while preserving the $0 proof boundary.</p>
    <p class="buttons"><a href="pdf-table-sample-output.html">PDF/Table sample output</a><a href="local-seo-sample-output.html">Local SEO sample output</a><a href="warm_buyer_sample_outputs.csv">CSV</a></p>
  </section>
HTML
upsert_block(File.join(DOCS, "index.html"), "warm-buyer-sample-outputs", index_block, /<!-- pdf-download-intent-close:start -->/)

urls = sample_pages.map { |page| url(page.fetch(:path)) } + [url("warm_buyer_sample_outputs.csv"), url("index.html"), url("pdf-table-download-intent-close.html"), url("local-seo-download-intent-close.html")]
add_urls_to_sitemap(urls)
add_urls_to_indexnow(urls)
add_search_documents(
  sample_pages.map do |page|
    {
      "type" => "warm_buyer_sample_output",
      "title" => page.fetch(:title),
      "url" => url(page.fetch(:path)),
      "description" => "Synthetic sample output for #{page.fetch(:route)} buyers before ready-to-pay intake. Money remains $0 until external payment proof exists.",
      "tags" => ["sample-output", "ready-to-pay", "payment-proof", "warm-path", page.fetch(:route).downcase.gsub(/[^a-z0-9]+/, "-")]
    }
  end
)

puts "wrote #{sample_pages.map { |page| page.fetch(:path) }.join(", ")}"
puts "wrote warm_buyer_sample_outputs.csv"
puts "urls=#{urls.length}"
