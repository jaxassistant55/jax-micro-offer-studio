#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "csv"
require "json"
require "time"
require "uri"

ENV["TZ"] = "Asia/Tokyo"

LAUNCH_ROOT = File.expand_path("..", __dir__)
DOCS = File.join(LAUNCH_ROOT, "docs")
SITE = "https://jaxassistant55.github.io/jax-micro-offer-studio/"
PAGE = "#{SITE}buyer-response-playbook.html"
CSV_URL = "#{SITE}buyer-response-playbook.csv"
GENERATED_AT = Time.now.strftime("%Y-%m-%d %H:%M:%S JST")
FAST_START_TERMS = "#{SITE}first-100-fast-start-terms.html"
FAST_START_ACCEPTANCE = "I accept the First $100 Fast Start fixed-scope terms at $100. I understand work starts only after seller-owned external payment proof exists; I will provide only public or buyer-authorized non-sensitive inputs; the selected starter scope is limited to the deliverable described on the First $100 Fast Start page; and custom implementation, account login work, credential handling, regulated advice, paid ads, purchasing, ongoing support, or extra revisions are not included unless separately agreed before payment."
PRODUCT_BUNDLE_TERMS = "#{SITE}first-100-product-bundle-terms.html"
PRODUCT_BUNDLE_ACCEPTANCE = "I accept the First $100 Product Bundle Terms at $100. I understand the private ZIP is delivered only after seller-owned external payment proof exists; the bundle is for my internal or client-project use only; I will not resell, redistribute, sublicense, or post the paid files publicly; and custom implementation or support is not included unless separately agreed before payment."

def h(value)
  CGI.escapeHTML(value.to_s)
end

def read_csv(path)
  return [] unless File.exist?(path)

  CSV.read(path, headers: true).map(&:to_h)
end

def write_csv(path, headers, rows)
  CSV.open(path, "w", write_headers: true, headers: headers) do |csv|
    rows.each { |row| csv << headers.map { |header| row[header] } }
  end
end

def upsert_json_document(path, type, document)
  return unless File.exist?(path)

  data = JSON.parse(File.read(path))
  data["documents"] ||= []
  data["documents"].reject! { |row| row["type"] == type }
  data["documents"] << document
  File.write(path, JSON.pretty_generate(data))
end

def upsert_structured_page(path, additional_type, page)
  return unless File.exist?(path)

  data = JSON.parse(File.read(path))
  graph = data["@graph"] ||= []
  graph.reject! { |row| row["additionalType"] == additional_type }
  graph << page
  File.write(path, JSON.pretty_generate(data))
end

def add_url_to_sitemap(path, url)
  return unless File.exist?(path)

  body = File.read(path)
  return if body.include?("<loc>#{url}</loc>")

  File.write(path, body.sub("</urlset>", "  <url><loc>#{h(url)}</loc></url>\n</urlset>"))
end

def add_urls_to_indexnow(path, urls)
  return unless File.exist?(path)

  payload = JSON.parse(File.read(path))
  payload["urlList"] = (payload.fetch("urlList", []) + urls).uniq
  File.write(path, JSON.pretty_generate(payload))
end

def rewrite_indexnow_urls_csv(path, payload_path)
  return unless File.exist?(payload_path)

  payload = JSON.parse(File.read(payload_path))
  write_csv(path, ["url"], payload.fetch("urlList", []).map { |url| { "url" => url } })
end

def upsert_homepage_link(path)
  return unless File.exist?(path)

  body = File.read(path)
  return if body.include?('href="buyer-response-playbook.html"')

  body = body.sub(
    'href="delivery-acceptance.html">Delivery acceptance</a>',
    'href="delivery-acceptance.html">Delivery acceptance</a><a href="buyer-response-playbook.html">Buyer response autopilot</a>'
  )
  body = body.sub(
    'href="ready-to-buy.html">Open ready-to-buy routes</a>',
    'href="ready-to-buy.html">Open ready-to-buy routes</a><a href="buyer-response-playbook.html">Buyer response autopilot</a>'
  )
  File.write(path, body)
end

def upsert_llms(path)
  return unless File.exist?(path)

  body = File.read(path)
  line = "- Buyer response autopilot: #{PAGE}"
  return if body.include?(line)

  body = body.sub("## Ready-to-buy routes\n", "## Ready-to-buy routes\n#{line}\n")
  File.write(path, body)
end

def fast_start_route?(row)
  text = [row["catalog_row_id"], row["title"], row["primary_url"], row["structured_form_url"]].join("\n").downcase
  text.include?("first-100-fast-start") || text.include?("first $100 fast start")
end

def product_bundle_route?(row)
  text = [row["catalog_row_id"], row["title"], row["primary_url"], row["structured_form_url"]].join("\n").downcase
  text.include?("first-100-product-bundle") || text.include?("first $100 product bundle")
end

def route_terms_url(row)
  return FAST_START_TERMS if fast_start_route?(row)
  return PRODUCT_BUNDLE_TERMS if product_bundle_route?(row)

  ""
end

def route_acceptance_statement(row)
  return FAST_START_ACCEPTANCE if fast_start_route?(row)
  return PRODUCT_BUNDLE_ACCEPTANCE if product_bundle_route?(row)

  ""
end

def route_acceptance_gate(row)
  if fast_start_route?(row)
    "Buyer must choose exactly one $100 starter scope, paste the exact Fast Start acceptance statement, provide only public or buyer-authorized non-sensitive inputs, and wait for seller-owned external payment proof before work starts."
  elsif product_bundle_route?(row)
    "Buyer must paste the exact Product Bundle acceptance statement, accept the $100 private ZIP transfer terms, and wait for seller-owned external payment proof before private delivery."
  else
    "Buyer must accept the listed fixed scope or product-transfer terms before any seller-owned external payment route is sent."
  end
end

catalog_rows = read_csv(File.join(DOCS, "paid-offer-action-catalog.csv"))
playbook_rows = catalog_rows.map do |row|
  terms_url = route_terms_url(row)
  exact_acceptance = route_acceptance_statement(row)
  acceptance_gate = route_acceptance_gate(row)
  {
    "generated_at_jst" => GENERATED_AT,
    "catalog_row_id" => row["catalog_row_id"],
    "title" => row["title"],
    "price" => row["price"],
    "repo_url" => row["repo_url"],
    "structured_form_url" => row["structured_form_url"],
    "payment_activation_url" => row["payment_activation_url"],
    "terms_url" => terms_url,
    "exact_acceptance_statement" => exact_acceptance,
    "autonomous_response" => "If a non-assistant buyer opens a ready-to-pay or ready-to-buy issue, post the safe next-step checklist, label the issue, and route to payment activation only after accepted scope or transfer terms.",
    "route_specific_acceptance_gate" => acceptance_gate,
    "user_only_gate" => "Seller-owned external checkout, invoice, marketplace order, funded milestone, payout/tax setup, private delivery, and verified posted/released/payable/cleared money.",
    "money_rule" => row["proof_rule"]
  }
end

headers = %w[
  generated_at_jst
  catalog_row_id
  title
  price
  repo_url
  structured_form_url
  payment_activation_url
  terms_url
  exact_acceptance_statement
  autonomous_response
  route_specific_acceptance_gate
  user_only_gate
  money_rule
]
write_csv(File.join(DOCS, "buyer-response-playbook.csv"), headers, playbook_rows)

table_rows = playbook_rows.map do |row|
  <<~HTML
    <tr>
      <td data-label="Route">#{h(row["title"])}<br><span class="muted">#{h(row["catalog_row_id"])}</span></td>
      <td data-label="Price">#{h(row["price"])}</td>
      <td data-label="Repo"><a href="#{h(row["repo_url"])}">Open repo</a></td>
      <td data-label="Buyer form"><a href="#{h(row["structured_form_url"])}">Open form</a></td>
      <td data-label="Terms">#{row["terms_url"].to_s.empty? ? '<span class="muted">Use route scope terms</span>' : %(<a href="#{h(row["terms_url"])}">Open terms</a>)}</td>
      <td data-label="Autonomous response">#{h(row["autonomous_response"])}</td>
      <td data-label="Acceptance gate">#{h(row["route_specific_acceptance_gate"])}</td>
      <td data-label="User-only gate">#{h(row["user_only_gate"])}</td>
    </tr>
  HTML
end.join

html = <<~HTML
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Buyer response autopilot for Micro Offer Studio ready-to-pay and ready-to-buy issues.">
    <title>Buyer Response Autopilot - Micro Offer Studio</title>
    <style>
      :root{--ink:#17202a;--muted:#5d6875;--line:#d9dfeb;--panel:#f6f8fb;--accent:#075da8;--green:#17643a;--gold:#8a5a00}
      *{box-sizing:border-box}body{margin:0;color:var(--ink);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.45;background:#fff}main{width:min(1180px,calc(100% - 32px));margin:0 auto;padding:28px 0 48px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:20px}h1{margin:0 0 8px;font-size:clamp(1.8rem,4vw,2.75rem);letter-spacing:0}h2{margin:24px 0 10px;font-size:1.2rem;letter-spacing:0}p{margin:0 0 10px}a{color:var(--accent)}.muted{color:var(--muted)}.buttons{display:flex;gap:8px;flex-wrap:wrap}.buttons a{display:inline-block;border:1px solid var(--line);border-radius:8px;padding:8px 10px;background:#fff;text-decoration:none;font-weight:700}.summary,.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.metric,.notice,.card{border:1px solid var(--line);border-radius:8px;background:#fff;padding:12px;min-width:0;overflow-wrap:anywhere}.metric{background:var(--panel)}.metric span,.eyebrow{display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.04em}.metric strong{display:block;margin-top:5px;font-size:1.25rem}.notice{border-left:6px solid var(--gold);background:#fffaf0}.card{border-left:6px solid var(--green)}.copybox{white-space:pre-wrap;border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:10px;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.9rem}table{width:100%;border-collapse:collapse;border:1px solid var(--line);background:#fff}th,td{padding:9px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top;font-size:.88rem;overflow-wrap:anywhere}th{background:var(--panel);color:var(--muted);font-size:.72rem;text-transform:uppercase;letter-spacing:.04em}
      @media(max-width:900px){.summary,.grid{grid-template-columns:1fr}.buttons{display:grid}.buttons a{width:100%}table,thead,tbody,tr,th,td{display:block}thead{display:none}tr{border-bottom:1px solid var(--line);padding:8px 0}td{border-bottom:0;padding:6px 9px}td::before{content:attr(data-label);display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase}}
    </style>
  </head>
  <body>
    <main>
      <header>
        <p class="buttons"><a href="index.html">Home</a><a href="paid-offer-action-catalog.html">Paid catalog</a><a href="first-100-fast-start-terms.html">Fast Start terms</a><a href="first-100-product-bundle-terms.html">Bundle terms</a><a href="payment-activation.html">Payment activation</a><a href="proof-monitor.html">Proof monitor</a><a href="buyer-response-playbook.csv">CSV</a></p>
        <h1>Buyer Response Autopilot</h1>
        <p class="muted">Generated #{h(GENERATED_AT)}. This is the safe owned-repo response path for legitimate ready-to-pay or ready-to-buy GitHub issues. It does not invoice, collect payment, impersonate a seller, or count money.</p>
      </header>

      <section class="summary">
        <article class="metric"><span>Catalog routes covered</span><strong>#{playbook_rows.length}</strong></article>
        <article class="metric"><span>Workflow trigger</span><strong>Ready issue</strong></article>
        <article class="metric"><span>Confirmed money</span><strong>$0</strong></article>
      </section>

      <section class="notice">
        <h2>What the workflow does</h2>
        <p>When a non-assistant buyer opens or reopens a ready-to-pay or ready-to-buy issue, the workflow checks the title and labels, rejects pull requests and bounty/wallet-style claims, posts one marked checklist comment, adds route-specific terms for Fast Start and Product Bundle issues, and labels the issue for seller review and payment-proof gating.</p>
      </section>

      <section class="grid">
        <article class="card"><span class="eyebrow">Autonomous</span><h2>Safe response</h2><p>Posts exact next steps, route-specific terms where available, payment activation link, proof monitor link, and privacy boundaries inside the buyer issue.</p></article>
        <article class="card"><span class="eyebrow">Autonomous</span><h2>Noise filter</h2><p>Skips assistant-authored issues, pull requests, already-responded issues, and bounty/wallet claim text.</p></article>
        <article class="card"><span class="eyebrow">External gate</span><h2>Money proof</h2><p>Money remains $0 until a real seller-owned external payment or payout is posted, released, payable, or cleared after accepted scope and delivery.</p></article>
      </section>

      <section>
        <h2>Comment Template</h2>
        <div class="copybox">&lt;!-- micro-offer-studio:buyer-response:v1 --&gt;
Thanks for opening a ready-to-pay or ready-to-buy request.

Exact next steps:
1. Keep the scope public-safe in this issue. Do not post passwords, payment cards, tax identifiers, private regulated details, confidential files, or screenshots of payment accounts.
2. Confirm the exact deliverable, deadline, acceptance proof, and any buyer-owned inputs that can safely be shared.
3. Use the payment activation page only after scope or transfer terms are accepted.
4. Payment must happen through a seller-owned external checkout, invoice, marketplace order, payment request, or funded milestone.
5. For Fast Start or Product Bundle routes, include the matching terms page and exact acceptance statement before payment.
6. After external payment is posted, released, payable, or cleared, the seller can deliver the private bundle or service output and record the proof.</div>
      </section>

      <section>
        <h2>Exact Acceptance Gates</h2>
        <div class="grid">
          <article class="card"><span class="eyebrow">Fast Start service</span><h2>First $100 Fast Start</h2><p><a href="first-100-fast-start-terms.html">Terms page</a></p><div class="copybox">#{h(FAST_START_ACCEPTANCE)}</div></article>
          <article class="card"><span class="eyebrow">Product transfer</span><h2>First $100 Product Bundle</h2><p><a href="first-100-product-bundle-terms.html">Terms page</a></p><div class="copybox">#{h(PRODUCT_BUNDLE_ACCEPTANCE)}</div></article>
        </div>
      </section>

      <section>
        <h2>Covered Paid Routes</h2>
        <table>
          <thead><tr><th>Route</th><th>Price</th><th>Repo</th><th>Buyer form</th><th>Terms</th><th>Autonomous response</th><th>Acceptance gate</th><th>User-only gate</th></tr></thead>
          <tbody>#{table_rows}</tbody>
        </table>
      </section>
    </main>
  </body>
  </html>
HTML

File.write(File.join(DOCS, "buyer-response-playbook.html"), html)
upsert_homepage_link(File.join(DOCS, "index.html"))
upsert_llms(File.join(DOCS, "llms.txt"))
upsert_json_document(File.join(DOCS, "search-index.json"), "buyer_response_autopilot", {
  "type" => "buyer_response_autopilot",
  "title" => "Buyer Response Autopilot",
  "slug" => "buyer-response-playbook",
  "url" => PAGE,
  "price" => "$0",
  "amount_usd" => 0,
  "description" => "Owned-repo workflow and playbook that posts safe next steps on legitimate ready-to-pay or ready-to-buy issues.",
  "first_100" => "Moves buyer issues closer to payment proof but counts $0 until external posted/released/payable money exists.",
  "start_order_url" => "#{SITE}paid-offer-action-catalog.html",
  "proof_rule" => "Counts $0 until external buyer/payment proof exists."
})
upsert_structured_page(File.join(DOCS, "structured-data.json"), "buyer_response_autopilot", {
  "@type" => "WebPage",
  "additionalType" => "buyer_response_autopilot",
  "name" => "Buyer Response Autopilot",
  "url" => PAGE,
  "description" => "Safe workflow and playbook for responding to legitimate paid buyer issues."
})
[PAGE, CSV_URL].each { |url| add_url_to_sitemap(File.join(DOCS, "sitemap.xml"), url) }
payload_path = File.join(DOCS, "indexnow_payload.json")
add_urls_to_indexnow(payload_path, [PAGE, CSV_URL, "#{SITE}index.html", "#{SITE}search-index.json", "#{SITE}llms.txt"])
rewrite_indexnow_urls_csv(File.join(DOCS, "indexnow_urls.csv"), payload_path)

puts "Wrote #{File.join(DOCS, "buyer-response-playbook.html")}"
puts "Wrote #{File.join(DOCS, "buyer-response-playbook.csv")}"
puts "covered_routes=#{playbook_rows.length}"
