#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "csv"
require "json"
require "time"

ENV["TZ"] = "Asia/Tokyo"

ROOT = File.expand_path("..", __dir__)
DOCS = File.join(ROOT, "docs")
SITE = "https://jaxassistant55.github.io/jax-micro-offer-studio/"
STAMP = Time.now.strftime("%Y-%m-%d %H:%M:%S JST")
PAYMENT_URL = "#{SITE}payment-activation.html"
PROOF_URL = "#{SITE}proof-monitor.html"
SAMPLE_README_URL = "#{SITE}first-100-sample-pack/README.md"

def h(value)
  CGI.escapeHTML(value.to_s)
end

def absolute(path)
  "#{SITE}#{path}"
end

def write_csv(path, headers, rows)
  CSV.open(path, "w", write_headers: true, headers: headers) do |csv|
    rows.each { |row| csv << headers.map { |header| row[header] } }
  end
end

def add_urls_to_sitemap(path, urls)
  return unless File.exist?(path)

  body = File.read(path)
  urls.each do |url|
    next if body.include?("<loc>#{url}</loc>")

    body = body.sub("</urlset>", "  <url><loc>#{h(url)}</loc></url>\n</urlset>")
  end
  File.write(path, body)
end

def add_urls_to_indexnow(path, urls)
  return [] unless File.exist?(path)

  payload = JSON.parse(File.read(path))
  payload["urlList"] = (payload.fetch("urlList", []) + urls).uniq
  File.write(path, JSON.pretty_generate(payload))
  payload["urlList"]
end

def rewrite_indexnow_urls_csv(path, urls)
  write_csv(path, ["url"], urls.map { |url| { "url" => url } })
end

def upsert_search_docs(path, docs)
  return unless File.exist?(path)

  search = JSON.parse(File.read(path))
  documents = search["documents"] ||= []
  urls = docs.map { |doc| doc["url"] }
  documents.reject! { |doc| urls.include?(doc["url"].to_s) }
  documents.unshift(*docs)
  search["generated_at_jst"] = STAMP
  File.write(path, JSON.pretty_generate(search))
end

def upsert_structured(path, nodes)
  return unless File.exist?(path)

  data = JSON.parse(File.read(path))
  graph = data["@graph"] ||= []
  urls = nodes.map { |node| node["url"] }
  graph.reject! { |node| urls.include?(node["url"].to_s) }
  graph.concat(nodes)
  File.write(path, JSON.pretty_generate(data))
end

def upsert_llms(path, lines)
  return unless File.exist?(path)

  body = File.read(path)
  lines.each do |line|
    next if body.include?(line)

    body << "\n#{line}\n"
  end
  File.write(path, body)
end

def term_steps(service)
  [
    {
      "step_id" => "01_open_terms",
      "step_title" => "Open the service terms",
      "actor" => "buyer",
      "exact_action" => "Open #{service[:terms_url]} and review the price, allowed inputs, excluded work, delivery boundary, and money-counting rule.",
      "proof_required" => "Buyer acceptance statement references this terms URL.",
      "counts_as_money" => "no",
      "public_url" => service[:terms_url]
    },
    {
      "step_id" => "02_paste_exact_acceptance",
      "step_title" => "Paste exact acceptance",
      "actor" => "buyer",
      "exact_action" => "Buyer posts or sends this exact acceptance statement: #{service[:acceptance]}",
      "proof_required" => "Dated issue body, marketplace order note, invoice approval, or private buyer message containing the exact statement.",
      "counts_as_money" => "no",
      "public_url" => service[:form_url]
    },
    {
      "step_id" => "03_confirm_allowed_inputs",
      "step_title" => "Confirm safe input boundary",
      "actor" => "buyer",
      "exact_action" => "Buyer confirms the input is public or buyer-authorized and matches this boundary: #{service[:allowed_inputs]}",
      "proof_required" => "Safe scope details in the issue or buyer message, with no credentials, tax identifiers, payment data, or private regulated files posted publicly.",
      "counts_as_money" => "no",
      "public_url" => service[:form_url]
    },
    {
      "step_id" => "04_confirm_fixed_deliverable",
      "step_title" => "Confirm fixed deliverable",
      "actor" => "buyer",
      "exact_action" => "Buyer confirms the paid output is limited to: #{service[:deliverable]}",
      "proof_required" => "Accepted deliverable, deadline, delivery channel, and acceptance criterion.",
      "counts_as_money" => "no",
      "public_url" => service[:close_url]
    },
    {
      "step_id" => "05_send_seller_owned_payment_route",
      "step_title" => "Use seller-owned payment route",
      "actor" => "seller",
      "exact_action" => "After exact acceptance, use #{PAYMENT_URL} with a checkout, invoice, marketplace order, funded milestone, or payment request controlled by the seller.",
      "proof_required" => "Seller-owned payment URL or external order reference plus accepted terms.",
      "counts_as_money" => "no",
      "public_url" => PAYMENT_URL
    },
    {
      "step_id" => "06_wait_for_payment_proof",
      "step_title" => "Wait for payment proof",
      "actor" => "seller",
      "exact_action" => "Do not start buyer-specific work until the external provider/platform shows payment posted, funded, released, payable, cleared, or otherwise saveable as proof.",
      "proof_required" => "Provider/platform, status, amount, date, buyer/order/reference id where available, and refund/hold status if visible.",
      "counts_as_money" => "yes_after_posted_released_payable_or_cleared",
      "public_url" => PAYMENT_URL
    },
    {
      "step_id" => "07_deliver_fixed_scope_output",
      "step_title" => "Deliver fixed-scope output",
      "actor" => "seller",
      "exact_action" => "Deliver only the accepted #{service[:price]} fixed-scope output through the agreed controlled channel after payment proof exists.",
      "proof_required" => "Delivery artifact, delivery message/status, and no public exposure of private buyer files.",
      "counts_as_money" => "no_without_payment_proof",
      "public_url" => PROOF_URL
    },
    {
      "step_id" => "08_capture_acceptance",
      "step_title" => "Capture buyer acceptance",
      "actor" => "buyer",
      "exact_action" => "Buyer confirms the delivered output satisfies the accepted criterion, or the platform/order marks delivery accepted or complete.",
      "proof_required" => "Buyer acceptance text, platform delivery completion, or order completion status.",
      "counts_as_money" => "yes_only_with_payment_proof",
      "public_url" => PROOF_URL
    },
    {
      "step_id" => "09_count_only_verified_money",
      "step_title" => "Record only verified money",
      "actor" => "seller",
      "exact_action" => "Keep money at $0 unless exact acceptance, payment proof, delivery proof, and posted/released/payable/cleared status exist.",
      "proof_required" => "Payment proof, delivery proof, acceptance/completion proof, amount, date, provider/platform, and refund/hold/fee status where available.",
      "counts_as_money" => "yes",
      "public_url" => PROOF_URL
    },
    {
      "step_id" => "10_stop_on_false_positive",
      "step_title" => "Stop on false positives",
      "actor" => "seller",
      "exact_action" => "Count $0 if the only signal is a page view, release download, star, fork, issue draft, unpaid comment, IndexNow response, or public route update.",
      "proof_required" => "Proof monitor row may show interest, but there is no external payment proof.",
      "counts_as_money" => "no",
      "public_url" => PROOF_URL
    }
  ]
end

services = [
  {
    slug: "local-seo-gbp-audit-terms",
    title: "Local SEO / GBP Audit Terms and Acceptance",
    short_title: "Local SEO / GBP Audit",
    price: "$175",
    terms_url: absolute("local-seo-gbp-audit-terms.html"),
    terms_csv_url: absolute("local-seo-gbp-audit-terms.csv"),
    close_url: absolute("hot-download-close-local-seo-gbp-audit-starter.html"),
    offer_url: absolute("local-seo-gbp-audit.html"),
    form_url: "https://github.com/jaxassistant55/local-seo-gbp-audit-starter/issues/new?template=ready-to-pay-local-seo-gbp-audit.yml",
    board_url: "https://github.com/jaxassistant55/local-seo-gbp-audit-starter/issues/1",
    allowed_inputs: "Business name, public website, Google Business Profile URL if available, target city/service area, and 1-3 priority services. Do not send account credentials.",
    deliverable: "One local SEO / GBP audit covering profile completeness, category fit, review/citation gaps, landing-page fit, and a prioritized next-action checklist.",
    excluded: "Google account login work, profile claiming/verification, fake reviews, keyword-stuffed business names, paid ads, legal advice, publishing edits, ongoing SEO, or extra revisions.",
    acceptance: "I accept the Local SEO / GBP Audit fixed-scope terms at $175. I understand work starts only after seller-owned external payment proof exists; I will provide only public or buyer-authorized non-sensitive business details; the audit is limited to public website/profile review, category/citation/review/landing-page observations, and a prioritized action checklist; and Google account login work, profile claiming/verification, fake reviews, paid ads, legal advice, publishing edits, ongoing SEO, or extra revisions are not included unless separately agreed before payment."
  },
  {
    slug: "pdf-table-extraction-terms",
    title: "PDF/Table Extraction Terms and Acceptance",
    short_title: "PDF/Table Extraction",
    price: "$125",
    terms_url: absolute("pdf-table-extraction-terms.html"),
    terms_csv_url: absolute("pdf-table-extraction-terms.csv"),
    close_url: absolute("hot-download-close-pdf-table-extraction-starter.html"),
    offer_url: absolute("pdf-table-extraction.html"),
    form_url: "https://github.com/jaxassistant55/pdf-table-extraction-starter/issues/new?template=ready-to-pay-pdf-table-extraction.yml",
    board_url: "https://github.com/jaxassistant55/pdf-table-extraction-starter/issues/1",
    allowed_inputs: "One buyer-owned or public PDF sample, target table fields, desired CSV/XLSX column names, and redaction requirements. Do not post private documents publicly.",
    deliverable: "Extracted CSV/XLSX output from the accepted PDF/table sample, notes on ambiguous rows, and a repeatable extraction checklist.",
    excluded: "Confidential regulated data handling, OCR of large batches, custom software implementation, credential/account access, ongoing support, or extra revisions.",
    acceptance: "I accept the PDF/Table Extraction fixed-scope terms at $125. I understand work starts only after seller-owned external payment proof exists; I will provide only public or buyer-owned/buyer-authorized non-sensitive documents through an approved channel; the deliverable is limited to extracted CSV/XLSX output, ambiguity notes, and a repeatable extraction checklist for the accepted sample; and confidential regulated data handling, OCR of large batches, custom software implementation, credential/account access, ongoing support, or extra revisions are not included unless separately agreed before payment."
  }
]

services.each do |service|
  rows = term_steps(service)
  csv_path = File.join(DOCS, "#{service[:slug]}.csv")
  html_path = File.join(DOCS, "#{service[:slug]}.html")
  headers = %w[generated_at_jst step_id step_title actor exact_action proof_required counts_as_money public_url]
  write_csv(csv_path, headers, rows.map { |row| row.merge("generated_at_jst" => STAMP) })

  step_cards = rows.map.with_index(1) do |row, index|
    <<~HTML
      <article class="step-card">
        <div class="eyebrow">Step #{index} / #{h(row["actor"])}</div>
        <h3>#{h(row["step_title"])}</h3>
        <dl>
          <div><dt>Action</dt><dd>#{h(row["exact_action"])}</dd></div>
          <div><dt>Proof Required</dt><dd>#{h(row["proof_required"])}</dd></div>
          <div><dt>Counts As Money</dt><dd>#{h(row["counts_as_money"])}</dd></div>
        </dl>
      </article>
    HTML
  end.join

  html = <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="description" content="Fixed-scope terms, exact acceptance, payment proof gate, and delivery checklist for #{h(service[:short_title])}.">
      <meta property="og:title" content="#{h(service[:title])}">
      <meta property="og:description" content="Exact buyer acceptance and seller proof steps for #{h(service[:price])} #{h(service[:short_title])}.">
      <meta property="og:type" content="article">
      <link rel="canonical" href="#{h(service[:terms_url])}">
      <link rel="alternate" type="text/csv" title="#{h(service[:title])} CSV" href="#{h(service[:terms_csv_url])}">
      <title>#{h(service[:title])}</title>
      <style>
        :root{--ink:#17202a;--muted:#5d6875;--line:#d9dfeb;--panel:#f6f8fb;--accent:#075da8;--green:#17643a;--gold:#8a5a00;--red:#9b1c1c}
        *{box-sizing:border-box}body{margin:0;color:var(--ink);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.45;background:#fff}main{width:min(1180px,calc(100% - 32px));margin:0 auto;padding:28px 0 48px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:20px}h1{margin:0 0 8px;font-size:clamp(1.8rem,4vw,2.75rem);letter-spacing:0}h2{margin:24px 0 10px;font-size:1.25rem;letter-spacing:0}h3{margin:0 0 8px;font-size:1.04rem;letter-spacing:0}p{margin:0 0 10px;overflow-wrap:anywhere}a{color:var(--accent);overflow-wrap:anywhere}.muted{color:var(--muted)}.buttons{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0}.buttons a{display:inline-block;border:1px solid var(--line);border-radius:8px;padding:8px 10px;background:#fff;text-decoration:none;font-weight:700}.metrics,.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin:16px 0}.metric,.notice,.panel,.step-card{border:1px solid var(--line);border-radius:8px;background:#fff;padding:12px;min-width:0;overflow-wrap:anywhere}.metric{background:var(--panel)}.metric span,.eyebrow,dt{display:block;color:var(--muted);font-size:.72rem;font-weight:800;text-transform:uppercase;letter-spacing:.04em}.metric strong{display:block;margin-top:6px;font-size:1.15rem}.notice{border-left:6px solid var(--gold);background:#fffaf0}.danger{border-left:6px solid var(--red);background:#fff7f5}.panel,.step-card{border-left:6px solid var(--green)}.step-card dl{display:grid;grid-template-columns:1fr;gap:8px;margin:10px 0 0}.step-card dl div{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:9px}.step-card dd{margin:4px 0 0}.copybox{white-space:pre-wrap;border:1px solid var(--line);border-radius:8px;background:#101820;color:#f7fbff;padding:12px;overflow:auto;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.88rem}ol{margin:8px 0 0;padding-left:22px}li{margin:6px 0}
        @media(max-width:900px){.metrics,.grid{grid-template-columns:1fr}.buttons{display:grid}.buttons a{width:100%}}
      </style>
      <script type="application/ld+json">#{JSON.pretty_generate({
        "@context" => "https://schema.org",
        "@type" => "WebPage",
        "name" => service[:title],
        "url" => service[:terms_url],
        "isPartOf" => { "@type" => "WebSite", "name" => "Micro Offer Studio", "url" => SITE },
        "about" => { "@type" => "Service", "name" => service[:short_title], "url" => service[:offer_url], "offers" => { "@type" => "Offer", "priceCurrency" => "USD", "price" => service[:price].delete("$") } }
      })}</script>
    </head>
    <body>
      <main>
        <header>
          <p class="buttons"><a href="#acceptance">Acceptance</a><a href="#steps">Step checklist</a><a href="#proof">Proof gate</a><a href="#{h(service[:close_url])}">Close room</a><a href="#{h(service[:form_url])}">Ready-to-pay form</a><a href="#{h(PAYMENT_URL)}">Payment activation</a><a href="#{h(PROOF_URL)}">Proof monitor</a><a href="#{h(service[:terms_csv_url])}">CSV</a></p>
          <h1>#{h(service[:title])}</h1>
          <p class="muted">Generated #{h(STAMP)}. This page defines the exact acceptance statement, fixed-scope boundary, seller-owned payment proof gate, and delivery proof needed before this route can count as money.</p>
        </header>
        <section class="metrics">
          <div class="metric"><span>Price</span><strong>#{h(service[:price])}</strong></div>
          <div class="metric"><span>One sale clears $100</span><strong>Yes</strong></div>
          <div class="metric"><span>Money counted now</span><strong>$0</strong></div>
          <div class="metric"><span>Exact acceptance required</span><strong>Yes</strong></div>
        </section>
        <section class="notice">
          <h2>Close Boundary</h2>
          <p><strong>Money counted now $0.</strong> This can clear the first $100 with one paid order, but only after a real buyer accepts these terms, pays through a seller-owned external route, receives delivery, and the payment is posted, released, payable, or cleared.</p>
        </section>
        <section class="panel" id="acceptance">
          <h2>Exact Acceptance Statement</h2>
          <p>Ask the buyer to paste this exact statement before payment. If the buyer changes it materially, clarify before sending any payment route.</p>
          <div class="copybox">#{h(service[:acceptance])}</div>
        </section>
        <section class="grid">
          <article class="panel"><div class="eyebrow">Allowed inputs</div><p>#{h(service[:allowed_inputs])}</p></article>
          <article class="panel"><div class="eyebrow">Deliverable</div><p>#{h(service[:deliverable])}</p></article>
          <article class="panel"><div class="eyebrow">Excluded unless separately agreed</div><p>#{h(service[:excluded])}</p></article>
          <article class="panel"><div class="eyebrow">Sample proof</div><p><a href="#{h(SAMPLE_README_URL)}">Open sample README</a></p></article>
        </section>
        <section id="proof" class="notice danger">
          <h2>Proof Gate</h2>
          <ol>
            <li>Exact acceptance statement saved with date/channel.</li>
            <li>Seller-owned external payment proof saved before work starts.</li>
            <li>Delivery proof saved after fixed-scope output is sent.</li>
            <li>Buyer acceptance or platform completion status saved.</li>
            <li>Payment status is posted, released, payable, or cleared; otherwise the tracker remains $0.</li>
          </ol>
        </section>
        <section id="steps">
          <h2>Step Checklist</h2>
          <div class="grid">#{step_cards}</div>
        </section>
      </main>
    </body>
    </html>
  HTML
  File.write(html_path, html)
end

urls = services.flat_map { |service| [service[:terms_url], service[:terms_csv_url]] }
add_urls_to_sitemap(File.join(DOCS, "sitemap.xml"), urls)
payload_urls = add_urls_to_indexnow(File.join(DOCS, "indexnow_payload.json"), urls)
rewrite_indexnow_urls_csv(File.join(DOCS, "indexnow_urls.csv"), payload_urls) unless payload_urls.empty?

upsert_search_docs(
  File.join(DOCS, "search-index.json"),
  services.flat_map do |service|
    [
      {
        "type" => "service_terms",
        "title" => service[:title],
        "url" => service[:terms_url],
        "description" => "Fixed-scope terms and exact acceptance statement for #{service[:short_title]}.",
        "tags" => %w[terms acceptance payment-proof service]
      },
      {
        "type" => "service_terms_csv",
        "title" => "#{service[:title]} CSV",
        "url" => service[:terms_csv_url],
        "description" => "Machine-readable checklist for #{service[:short_title]} terms acceptance and proof.",
        "tags" => %w[csv terms acceptance payment-proof]
      }
    ]
  end
)

upsert_structured(
  File.join(DOCS, "structured-data.json"),
  services.flat_map do |service|
    [
      {
        "@context" => "https://schema.org",
        "@type" => "WebPage",
        "additionalType" => "service_terms",
        "name" => service[:title],
        "url" => service[:terms_url],
        "description" => "Fixed-scope terms and exact acceptance statement for #{service[:short_title]}."
      },
      {
        "@context" => "https://schema.org",
        "@type" => "Dataset",
        "additionalType" => "service_terms",
        "name" => "#{service[:title]} CSV",
        "url" => service[:terms_csv_url],
        "distribution" => [{ "@type" => "DataDownload", "encodingFormat" => "text/csv", "contentUrl" => service[:terms_csv_url] }]
      }
    ]
  end
)

upsert_llms(
  File.join(DOCS, "llms.txt"),
  services.map { |service| "- #{service[:short_title]} terms and acceptance: #{service[:terms_url]} | CSV #{service[:terms_csv_url]}" }
)

puts JSON.pretty_generate(
  generated_at_jst: STAMP,
  terms_pages: services.length,
  urls: urls,
  indexnow_urls: payload_urls.length,
  confirmed_money_usd: 0
)
