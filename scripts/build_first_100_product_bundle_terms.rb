#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "cgi"
require "json"
require "rexml/document"
require "time"

ENV["TZ"] = "Asia/Tokyo"

ROOT = File.expand_path("..", __dir__)
DOCS = File.join(ROOT, "docs")
BASE_URL = "https://jaxassistant55.github.io/jax-micro-offer-studio/"
STAMP = Time.now.strftime("%Y-%m-%d %H:%M:%S JST")

TERMS_SLUG = "first-100-product-bundle-terms"
TERMS_HTML = "#{TERMS_SLUG}.html"
TERMS_CSV = "#{TERMS_SLUG}.csv"
TERMS_URL = "#{BASE_URL}#{TERMS_HTML}"
TERMS_CSV_URL = "#{BASE_URL}#{TERMS_CSV}"
BUNDLE_HTML = "first-100-product-bundle.html"
BUNDLE_URL = "#{BASE_URL}#{BUNDLE_HTML}"
BUNDLE_JSON_PATH = File.join(DOCS, "first-100-product-bundle.json")
BUNDLE_CSV_URL = "#{BASE_URL}first-100-product-bundle.csv"
BUNDLE_JSON_URL = "#{BASE_URL}first-100-product-bundle.json"
ORDER_BOARD_URL = "https://github.com/jaxassistant55/jax-micro-offer-studio/issues/25"
READY_FORM_URL = "https://github.com/jaxassistant55/jax-micro-offer-studio/issues/new?template=first-100-product-bundle.yml"
PAYMENT_URL = "#{BASE_URL}payment-activation.html"
PROOF_URL = "#{BASE_URL}proof-monitor.html"
MARKETPLACE_URL = "#{BASE_URL}first-100-product-bundle-marketplace.html"
COVER_URL = "#{BASE_URL}assets/first-100-product-bundle-cover.png"

def h(value)
  CGI.escapeHTML(value.to_s)
end

def write_json(path, data)
  File.write(path, "#{JSON.pretty_generate(data)}\n")
end

def add_terms_link(text, needles, link_html)
  cleaned = text.gsub(%r{<a href="(?:#{Regexp.escape(TERMS_HTML)}|#{Regexp.escape(TERMS_URL)})">Terms and acceptance</a>}, "")
  needles.each do |needle|
    next unless cleaned.include?(needle)

    return cleaned.sub(needle, "#{needle}#{link_html}")
  end
  cleaned
end

bundle = JSON.parse(File.read(BUNDLE_JSON_PATH))
components = bundle.fetch("components", [])

acceptance_statement = "I accept the First $100 Product Bundle Terms at $100. I understand the private ZIP is delivered only after seller-owned external payment proof exists; the bundle is for my internal or client-project use only; I will not resell, redistribute, sublicense, or post the paid files publicly; and custom implementation or support is not included unless separately agreed before payment."

buyer_reply = <<~TEXT.strip
  Thanks for the request. I can transfer the First $100 Product Bundle for $100 as a fixed product-transfer order.

  To lock terms, please reply with this exact acceptance statement:
  "#{acceptance_statement}"

  Then confirm:
  1. Delivery email or private delivery channel:
  2. External payment/proof route you want to use:
  3. Exact acceptance proof after delivery:

  The private ZIP is delivered only after terms are accepted and payment is posted, funded, released, payable, or otherwise externally provable. Please do not post passwords, payment screenshots, tax identifiers, private identifiers, confidential files, or delivery links in a public GitHub issue.
TEXT

seller_handoff = <<~TEXT.strip
  Terms accepted for First $100 Product Bundle at $100.

  Included deliverables: private first-100-product-bundle.zip transfer, public manifest links, delivery checklist, and buyer handoff note.

  Not included unless explicitly added before payment: custom implementation, ongoing support, extra revisions, resale/redistribution rights, private-account login work, regulated advice, paid ads, purchasing, or handling secrets/payment data.

  Payment/proof needed before transfer: external checkout, invoice, marketplace order, funded milestone, posted transfer, or another seller-owned record that can be saved as payment proof.
TEXT

terms_rows = [
  {
    "step_id" => "01_verify_public_route",
    "step_title" => "Open the public bundle route",
    "actor" => "seller",
    "exact_action" => "Open #{BUNDLE_URL}, #{TERMS_URL}, #{MARKETPLACE_URL}, #{ORDER_BOARD_URL}, #{PAYMENT_URL}, and #{PROOF_URL}; confirm the buyer is on the $100 First $100 Product Bundle path before discussing payment.",
    "proof_required" => "Buyer source URL or message plus selected product-bundle route.",
    "counts_as_money" => "no",
    "public_url" => TERMS_URL
  },
  {
    "step_id" => "02_show_private_bundle_seal",
    "step_title" => "Show the artifact seal without exposing the ZIP",
    "actor" => "seller",
    "exact_action" => "Point the buyer to the public manifest: artifact #{bundle["artifact"]}, bytes #{bundle["zip_bytes"]}, SHA-256 #{bundle["zip_sha256"]}, component count #{bundle["component_count"]}, and list value #{bundle["component_list_value_usd"]}. Do not attach the paid ZIP publicly.",
    "proof_required" => "Public manifest links #{BUNDLE_CSV_URL} and #{BUNDLE_JSON_URL}.",
    "counts_as_money" => "no",
    "public_url" => BUNDLE_JSON_URL
  },
  {
    "step_id" => "03_confirm_transfer_terms",
    "step_title" => "Collect exact acceptance statement",
    "actor" => "buyer",
    "exact_action" => "Buyer posts or sends the exact acceptance statement: #{acceptance_statement}",
    "proof_required" => "Saved buyer acceptance text with date/channel.",
    "counts_as_money" => "no",
    "public_url" => TERMS_URL
  },
  {
    "step_id" => "04_keep_public_issue_safe",
    "step_title" => "Keep public intake safe",
    "actor" => "seller",
    "exact_action" => "Use GitHub only for public-safe scope facts. Move delivery address, payment proof, private files, passwords, tax identifiers, private identifiers, and delivery links out of public issues.",
    "proof_required" => "Public issue or form contains no secrets, private payment screenshots, tax data, confidential files, or private delivery URLs.",
    "counts_as_money" => "no",
    "public_url" => ORDER_BOARD_URL
  },
  {
    "step_id" => "05_send_seller_owned_payment_route",
    "step_title" => "Send only a seller-owned payment route",
    "actor" => "seller",
    "exact_action" => "Use Payment Activation only after acceptance, and send a checkout, invoice, marketplace order, funded milestone, or payment request URL controlled by the seller.",
    "proof_required" => "Seller-owned payment URL or order reference plus accepted terms.",
    "counts_as_money" => "no",
    "public_url" => PAYMENT_URL
  },
  {
    "step_id" => "06_wait_for_external_payment_proof",
    "step_title" => "Wait for payment proof before transfer",
    "actor" => "seller",
    "exact_action" => "Do not send #{bundle["artifact"]} until an external provider/platform shows payment posted, funded, released, payable, cleared, or otherwise saveable as proof.",
    "proof_required" => "Provider/platform, date, status, gross amount, fees/refunds if known, net amount, buyer/order/reference id where available.",
    "counts_as_money" => "yes_after_posted_released_payable_or_cleared",
    "public_url" => PAYMENT_URL
  },
  {
    "step_id" => "07_deliver_private_zip",
    "step_title" => "Deliver privately after proof",
    "actor" => "seller",
    "exact_action" => "Transfer #{bundle["artifact"]} through the accepted private delivery channel only after payment proof exists. Include the SHA-256 so the buyer can verify the file.",
    "proof_required" => "Private delivery record plus bundle SHA-256 #{bundle["zip_sha256"]}.",
    "counts_as_money" => "no_without_payment_proof",
    "public_url" => TERMS_URL
  },
  {
    "step_id" => "08_capture_acceptance",
    "step_title" => "Capture buyer acceptance or platform delivery status",
    "actor" => "buyer",
    "exact_action" => "Buyer confirms receipt, acceptance, or platform delivery completion. If platform acceptance is automatic, save the platform delivery status.",
    "proof_required" => "Buyer acceptance text, platform delivery status, or order completion status.",
    "counts_as_money" => "yes_only_with_payment_proof",
    "public_url" => PROOF_URL
  },
  {
    "step_id" => "09_count_money_only_after_proof",
    "step_title" => "Record only verified money",
    "actor" => "seller",
    "exact_action" => "Record money only after the external payment proof and private delivery proof exist. Use verified net amount if fees/refunds are known; otherwise record gross and mark fees unresolved.",
    "proof_required" => "Payment proof, delivery proof, acceptance/delivery status, amount, date, provider/platform, reference id where available.",
    "counts_as_money" => "yes",
    "public_url" => PROOF_URL
  },
  {
    "step_id" => "10_stop_on_false_positive",
    "step_title" => "Stop on non-buyer or bounty-style signals",
    "actor" => "seller",
    "exact_action" => "Keep money at $0 if the only signal is a page view, release download, star, fork, issue draft, PR, bounty/wallet/AI-fix claim, unpaid comment, IndexNow response, or public route update.",
    "proof_required" => "Proof monitor row may show interest or non-buyer state, but no external payment proof.",
    "counts_as_money" => "no",
    "public_url" => PROOF_URL
  }
]

CSV.open(File.join(DOCS, TERMS_CSV), "w") do |csv|
  csv << %w[generated_at_jst step_id step_title actor exact_action proof_required counts_as_money public_url]
  terms_rows.each do |row|
    csv << [
      STAMP,
      row["step_id"],
      row["step_title"],
      row["actor"],
      row["exact_action"],
      row["proof_required"],
      row["counts_as_money"],
      row["public_url"]
    ]
  end
end

steps_html = terms_rows.map.with_index(1) do |row, index|
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

component_rows = components.map do |component|
  <<~HTML
    <tr>
      <td data-label="Component">#{h(component["title"])}</td>
      <td data-label="List price">#{h(component["list_price"])}</td>
      <td data-label="Artifact">#{h(component["artifact"])}</td>
      <td data-label="SHA-256"><code>#{h(component["sha256"])}</code></td>
    </tr>
  HTML
end.join

html = <<~HTML
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Transfer terms, exact acceptance statement, payment proof gate, and private delivery checklist for the $100 First $100 Product Bundle.">
    <meta property="og:title" content="First $100 Product Bundle Terms and Acceptance">
    <meta property="og:description" content="Exact buyer acceptance and seller proof steps for a $100 private product-bundle transfer.">
    <meta property="og:image" content="#{h(COVER_URL)}">
    <meta property="og:type" content="article">
    <link rel="alternate" type="text/csv" title="First $100 Product Bundle terms CSV" href="#{h(TERMS_CSV)}">
    <link rel="alternate" type="application/json" title="First $100 Product Bundle manifest" href="first-100-product-bundle.json">
    <link rel="search" type="application/json" title="Micro Offer Studio search index" href="search-index.json">
    <title>First $100 Product Bundle Terms and Acceptance</title>
    <style>
      :root{--ink:#17202a;--muted:#5d6875;--line:#d9dfeb;--panel:#f6f8fb;--accent:#075da8;--green:#17643a;--gold:#8a5a00;--red:#9b1c1c}
      *{box-sizing:border-box}body{margin:0;color:var(--ink);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.45;background:#fff}main{width:min(1180px,calc(100% - 32px));margin:0 auto;padding:28px 0 48px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:20px}h1{margin:0 0 8px;font-size:clamp(1.8rem,4vw,2.75rem);letter-spacing:0}h2{margin:24px 0 10px;font-size:1.25rem;letter-spacing:0}h3{margin:0 0 8px;font-size:1.04rem;letter-spacing:0}p{margin:0 0 10px}a{color:var(--accent)}code{white-space:normal;overflow-wrap:anywhere}.muted{color:var(--muted)}.buttons{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0}.buttons a{display:inline-block;border:1px solid var(--line);border-radius:8px;padding:8px 10px;background:#fff;text-decoration:none;font-weight:700}.hero{display:grid;grid-template-columns:minmax(0,1fr) 340px;gap:18px;align-items:start}.hero img{width:100%;border:1px solid var(--line);border-radius:8px;background:var(--panel);display:block}.metric-grid,.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin:16px 0}.metric,.notice,.panel,.step-card{border:1px solid var(--line);border-radius:8px;background:#fff;padding:12px;min-width:0;overflow-wrap:anywhere}.metric{background:var(--panel)}.metric span,.eyebrow,dt{display:block;color:var(--muted);font-size:.72rem;font-weight:800;text-transform:uppercase;letter-spacing:.04em}.metric strong{display:block;margin-top:6px;font-size:1.15rem}.notice{border-left:6px solid var(--gold);background:#fffaf0}.danger{border-left:6px solid var(--red);background:#fff7f5}.panel,.step-card{border-left:6px solid var(--green)}.step-card dl{display:grid;grid-template-columns:1fr;gap:8px;margin:10px 0 0}.step-card dl div{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:9px}.step-card dd{margin:4px 0 0}.copybox{white-space:pre-wrap;border:1px solid var(--line);border-radius:8px;background:#101820;color:#f7fbff;padding:12px;overflow:auto;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.88rem}table{width:100%;border-collapse:collapse;border:1px solid var(--line);background:#fff}th,td{padding:9px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top;font-size:.9rem;overflow-wrap:anywhere}th{background:var(--panel);color:var(--muted);font-size:.74rem;text-transform:uppercase;letter-spacing:.04em}ol{margin:8px 0 0;padding-left:22px}li{margin:6px 0}
      @media(max-width:900px){.hero,.metric-grid,.grid{grid-template-columns:1fr}.buttons{display:grid}.buttons a{width:100%}table,thead,tbody,tr,th,td{display:block}thead{display:none}tr{border-bottom:1px solid var(--line);padding:8px 0}td{border-bottom:0;padding:6px 9px}td::before{content:attr(data-label);display:block;color:var(--muted);font-size:.72rem;font-weight:800;text-transform:uppercase}}
    </style>
    <script type="application/ld+json">
    #{JSON.pretty_generate({
      "@context" => "https://schema.org",
      "@type" => "WebPage",
      "name" => "First $100 Product Bundle Terms and Acceptance",
      "url" => TERMS_URL,
      "isPartOf" => { "@type" => "WebSite", "name" => "Micro Offer Studio", "url" => BASE_URL },
      "about" => {
        "@type" => "Product",
        "name" => "First $100 Product Bundle",
        "url" => BUNDLE_URL,
        "offers" => { "@type" => "Offer", "priceCurrency" => "USD", "price" => 100 }
      }
    })}
    </script>
  </head>
  <body>
    <main>
      <header>
        <p class="buttons"><a href="#acceptance">Acceptance statement</a><a href="#proof">Proof gate</a><a href="#steps">Step checklist</a><a href="#components">Components</a><a href="#templates">Reply templates</a><a href="#{h(BUNDLE_HTML)}">Bundle page</a><a href="first-100-product-bundle-marketplace.html">Marketplace packet</a><a href="payment-activation.html">Payment activation</a><a href="proof-monitor.html">Proof monitor</a><a href="#{h(TERMS_CSV)}">CSV</a></p>
        <section class="hero">
          <div>
            <h1>First $100 Product Bundle Terms and Acceptance</h1>
            <p class="muted">This is the close page for one $100 private product-bundle transfer. It tells the buyer exactly what to accept, tells the seller exactly what proof to save, and keeps confirmed money at $0 until external payment proof exists.</p>
          </div>
          <img src="assets/first-100-product-bundle-cover.png" alt="First $100 Product Bundle cover">
        </section>
      </header>

      <section class="metric-grid">
        <div class="metric"><span>Price</span><strong>$#{h(bundle["amount_usd"])}</strong></div>
        <div class="metric"><span>Components</span><strong>#{h(bundle["component_count"])}</strong></div>
        <div class="metric"><span>List value</span><strong>$#{h(bundle["component_list_value_usd"])}</strong></div>
        <div class="metric"><span>Money counted now $0</span><strong>$0</strong></div>
      </section>

      <section class="notice">
        <h2>What This Page Closes</h2>
        <p><strong>Money counted now $0.</strong> The product bundle can reach $100 with one verified transfer, but only after a real buyer accepts these terms, pays through a seller-owned external route, receives private delivery, and the payment is posted, released, payable, or cleared.</p>
      </section>

      <section class="panel" id="acceptance">
        <h2>Exact Buyer Acceptance Statement</h2>
        <p>Ask the buyer to send this sentence before payment. If the buyer changes it materially, treat terms as not accepted and clarify before sending a payment route.</p>
        <pre class="copybox">#{h(acceptance_statement)}</pre>
      </section>

      <section class="danger" id="proof">
        <h2>Money Gate</h2>
        <ol>
          <li>Public page, issue, PR, catalog row, release asset, route update, page view, download, star, fork, IndexNow response, and unpaid comment all count as $0.</li>
          <li>Payment Activation generates a message only; it is not a payment processor and not proof.</li>
          <li>Count money only after external payment proof exists, private delivery proof exists, and funds are posted, released, payable, or cleared.</li>
          <li>Save provider/platform, date, status, amount, buyer/order/reference id where available, delivery proof, and buyer acceptance or platform delivery status.</li>
        </ol>
      </section>

      <section class="panel">
        <h2>Private Bundle Seal</h2>
        <table>
          <thead><tr><th>Field</th><th>Value</th></tr></thead>
          <tbody>
            <tr><td data-label="Field">Private artifact</td><td data-label="Value"><code>#{h(bundle["artifact"])}</code></td></tr>
            <tr><td data-label="Field">Bytes</td><td data-label="Value">#{h(bundle["zip_bytes"])}</td></tr>
            <tr><td data-label="Field">SHA-256</td><td data-label="Value"><code>#{h(bundle["zip_sha256"])}</code></td></tr>
            <tr><td data-label="Field">Public manifest</td><td data-label="Value"><a href="first-100-product-bundle.csv">CSV</a> and <a href="first-100-product-bundle.json">JSON</a></td></tr>
            <tr><td data-label="Field">Public file policy</td><td data-label="Value">#{h(bundle["public_file_policy"])}</td></tr>
          </tbody>
        </table>
      </section>

      <section id="steps">
        <h2>Step Checklist</h2>
        <div class="grid">#{steps_html}</div>
      </section>

      <section id="templates">
        <h2>Copy Templates</h2>
        <h3>Buyer Reply</h3>
        <pre class="copybox">#{h(buyer_reply)}</pre>
        <h3>Seller Handoff</h3>
        <pre class="copybox">#{h(seller_handoff)}</pre>
      </section>

      <section id="components">
        <h2>Included Components</h2>
        <table>
          <thead><tr><th>Component</th><th>List price</th><th>Artifact</th><th>SHA-256</th></tr></thead>
          <tbody>#{component_rows}</tbody>
        </table>
      </section>
    </main>
  </body>
  </html>
HTML

File.write(File.join(DOCS, TERMS_HTML), html)

link_html = %(<a href="#{TERMS_HTML}">Terms and acceptance</a>)
absolute_link_html = %(<a href="#{TERMS_URL}">Terms and acceptance</a>)
link_targets = {
  "index.html" => [
    [%(<a href="first-100-product-bundle.html">First $100 Product Bundle</a>), link_html],
    [%(<a href="https://github.com/jaxassistant55/jax-micro-offer-studio/issues/25">First $100 board</a>), link_html]
  ],
  "first-100-product-bundle.html" => [
    [%(<a href="first-100-product-bundle-marketplace.html">Marketplace listing packet</a>), link_html],
    [%(<a href="https://github.com/jaxassistant55/jax-micro-offer-studio/issues/25">Order board #25</a>), link_html]
  ],
  "first-100-product-bundle-marketplace.html" => [
    [%(<a href="first-100-product-bundle.html">Product bundle</a>), link_html],
    [%(<a href="https://github.com/jaxassistant55/jax-micro-offer-studio/issues/25">Order board #25</a>), link_html]
  ],
  "ready-to-buy.html" => [
    [%(<a href="first-100-product-bundle.html">Open bundle page</a>), link_html],
    [%(<a href="first-100-product-bundle.html">First $100 Product Bundle</a>), link_html]
  ],
  "order-boards.html" => [
    [%(<a href="https://jaxassistant55.github.io/jax-micro-offer-studio/first-100-product-bundle.html">First $100 Product Bundle</a>), absolute_link_html],
    [%(<a href="first-100-product-bundle.html">First $100 Product Bundle</a>), link_html]
  ],
  "order-now.html" => [
    [%(<a href="first-100-product-bundle.html">First $100 Product Bundle</a>), link_html],
    [%(<a href="#{BUNDLE_URL}">First $100 Product Bundle</a>), absolute_link_html]
  ],
  "payment-activation.html" => [
    [%(<a href="#{MARKETPLACE_URL}">Ready route</a>), absolute_link_html],
    [%(<a href="service-invoice-drafts/first-100-product-bundle.html">Invoice draft</a>), absolute_link_html]
  ],
  "paid-offer-action-catalog.html" => [
    [%(<a href="#{BUNDLE_URL}">First $100 Product Bundle</a>), absolute_link_html]
  ],
  "buyer-response-playbook.html" => [
    [%(<a href="#{BUNDLE_URL}">First $100 Product Bundle</a>), absolute_link_html]
  ]
}
link_targets.each do |file, targets|
  path = File.join(DOCS, file)
  next unless File.exist?(path)

  text = File.read(path)
  updated = add_terms_link(text, targets.map(&:first), targets.first.last)
  File.write(path, updated) if updated != text
end

search_path = File.join(DOCS, "search-index.json")
search = JSON.parse(File.read(search_path))
search["generated_at_jst"] = STAMP
search["documents"] ||= []
search["documents"].reject! { |doc| doc["url"] == TERMS_URL || doc["url"] == TERMS_CSV_URL }
search["documents"].unshift(
  {
    "type" => "product-transfer-terms",
    "title" => "First $100 Product Bundle Terms and Acceptance",
    "url" => TERMS_URL,
    "description" => "Exact buyer acceptance statement, seller-owned payment gate, private delivery checklist, and proof requirements for the $100 product bundle.",
    "tags" => %w[first-100 product-bundle terms acceptance payment-proof private-delivery]
  },
  {
    "type" => "csv",
    "title" => "First $100 Product Bundle Terms CSV",
    "url" => TERMS_CSV_URL,
    "description" => "Step-by-step CSV for bundle acceptance, payment proof, private delivery, and money-counting gates.",
    "tags" => %w[first-100 product-bundle csv terms proof]
  }
)
write_json(search_path, search)

structured_path = File.join(DOCS, "structured-data.json")
structured = JSON.parse(File.read(structured_path))
graph = structured["@graph"] ||= []
graph.reject! { |node| node["url"] == TERMS_URL || node["url"] == TERMS_CSV_URL }
graph << {
  "@type" => "WebPage",
  "name" => "First $100 Product Bundle Terms and Acceptance",
  "url" => TERMS_URL,
  "description" => "Exact buyer acceptance statement, seller-owned payment gate, private delivery checklist, and proof requirements for the $100 product bundle.",
  "isPartOf" => { "@type" => "WebSite", "name" => "Micro Offer Studio", "url" => BASE_URL },
  "about" => { "@type" => "Product", "name" => "First $100 Product Bundle", "url" => BUNDLE_URL }
}
website = graph.find { |node| node["@type"] == "WebSite" }
if website
  website["hasPart"] ||= []
  website["hasPart"].reject! { |part| part["url"] == TERMS_URL }
  website["hasPart"] << { "@type" => "WebPage", "name" => "First $100 Product Bundle Terms and Acceptance", "url" => TERMS_URL }
end
write_json(structured_path, structured)

bundle["terms_url"] = TERMS_URL
bundle["terms_csv_url"] = TERMS_CSV_URL
bundle["acceptance_statement_template"] = acceptance_statement
bundle["money_count_rule"] = "Count $0 unless a real buyer accepts terms, pays through a seller-owned external route, receives private delivery, and funds are posted, released, payable, or cleared."
bundle["generated_at_jst"] = STAMP
write_json(BUNDLE_JSON_PATH, bundle)

sitemap_path = File.join(DOCS, "sitemap.xml")
sitemap_doc = REXML::Document.new(File.read(sitemap_path))
existing_locs = sitemap_doc.root.get_elements("url/loc").map { |loc| loc.text.to_s.strip }.reject(&:empty?)
sitemap_locs = (existing_locs + [TERMS_URL, TERMS_CSV_URL]).uniq
sitemap_xml = +"<?xml version='1.0' encoding='UTF-8'?>\n<urlset xmlns='http://www.sitemaps.org/schemas/sitemap/0.9'>\n"
sitemap_locs.each do |url|
  sitemap_xml << "  <url>\n    <loc>#{h(url)}</loc>\n  </url>\n"
end
sitemap_xml << "</urlset>\n"
File.write(sitemap_path, sitemap_xml)

urls_csv_path = File.join(DOCS, "indexnow_urls.csv")
urls = []
if File.exist?(urls_csv_path)
  CSV.foreach(urls_csv_path, headers: true) { |row| urls << row["url"].to_s }
end
urls.concat([TERMS_URL, TERMS_CSV_URL, BUNDLE_URL, MARKETPLACE_URL, PAYMENT_URL, PROOF_URL])
urls = urls.reject(&:empty?).uniq
CSV.open(urls_csv_path, "w") do |csv|
  csv << ["url"]
  urls.each { |url| csv << [url] }
end

payload_path = File.join(DOCS, "indexnow_payload.json")
payload = JSON.parse(File.read(payload_path))
payload["urlList"] = (payload["urlList"] + [TERMS_URL, TERMS_CSV_URL, BUNDLE_URL, MARKETPLACE_URL, PAYMENT_URL, PROOF_URL]).uniq
write_json(payload_path, payload)

llms_path = File.join(DOCS, "llms.txt")
llms = File.read(llms_path)
section = <<~TEXT.strip

  ## First $100 Product Bundle Terms
  - Terms and acceptance close page: #{TERMS_URL}
  - Terms CSV: #{TERMS_CSV_URL}
  - Exact buyer acceptance: #{acceptance_statement}
  - Boundary: count $0 unless a real buyer accepts terms, pays through a seller-owned external route, receives private delivery, and funds are posted, released, payable, or cleared.
TEXT
llms = llms.sub(/\n## First \$100 Product Bundle Terms\n.*?(?=\n## |\z)/m, "")
File.write(llms_path, "#{llms.rstrip}\n#{section}\n")

puts JSON.pretty_generate(
  generated_at_jst: STAMP,
  terms_html: File.join(DOCS, TERMS_HTML),
  terms_csv: File.join(DOCS, TERMS_CSV),
  rows: terms_rows.length,
  terms_url: TERMS_URL,
  terms_csv_url: TERMS_CSV_URL,
  money_confirmed_usd: 0
)
