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
BASE_URL = "https://jaxassistant55.github.io/jax-micro-offer-studio/"
STAMP = Time.now.strftime("%Y-%m-%d %H:%M:%S JST")

TERMS_SLUG = "first-100-fast-start-terms"
TERMS_HTML = "#{TERMS_SLUG}.html"
TERMS_CSV = "#{TERMS_SLUG}.csv"
TERMS_URL = "#{BASE_URL}#{TERMS_HTML}"
TERMS_CSV_URL = "#{BASE_URL}#{TERMS_CSV}"
FAST_HTML = "first-100-fast-start.html"
FAST_URL = "#{BASE_URL}#{FAST_HTML}"
FAST_CSV = "first_100_fast_start.csv"
FAST_CSV_URL = "#{BASE_URL}#{FAST_CSV}"
SAMPLE_ZIP_URL = "#{BASE_URL}first-100-sample-pack.zip"
FORM_URL = "https://github.com/jaxassistant55/jax-micro-offer-studio/issues/new?template=first-100-fast-start.yml"
ISSUE_URL = "https://github.com/jaxassistant55/jax-micro-offer-studio/issues/24"
PAYMENT_URL = "#{BASE_URL}payment-activation.html"
PROOF_URL = "#{BASE_URL}proof-monitor.html"

ACCEPTANCE = "I accept the First $100 Fast Start fixed-scope terms at $100. I understand work starts only after seller-owned external payment proof exists; I will provide only public or buyer-authorized non-sensitive inputs; the selected starter scope is limited to the deliverable described on the First $100 Fast Start page; and custom implementation, account login work, credential handling, regulated advice, paid ads, purchasing, ongoing support, or extra revisions are not included unless separately agreed before payment."

def h(value)
  CGI.escapeHTML(value.to_s)
end

def write_json(path, data)
  File.write(path, "#{JSON.pretty_generate(data)}\n")
end

def add_terms_link(text, needles, link_html)
  cleaned = text.gsub(%r{<a href="(?:#{Regexp.escape(TERMS_HTML)}|#{Regexp.escape(TERMS_URL)})">Fast Start terms</a>}, "")
  needles.each do |needle|
    next unless cleaned.include?(needle)

    return cleaned.sub(needle, "#{needle}#{link_html}")
  end
  cleaned
end

routes = CSV.read(File.join(DOCS, FAST_CSV), headers: true).map(&:to_h)
rows = [
  {
    "step_id" => "01_choose_fixed_scope",
    "step_title" => "Choose one exact $100 starter",
    "actor" => "buyer",
    "exact_action" => "Open #{FAST_URL} and choose exactly one starter scope: #{routes.map { |row| row["title"] }.join(", ")}.",
    "proof_required" => "Selected starter scope in the structured ready-to-pay form or issue #24.",
    "counts_as_money" => "no",
    "public_url" => FAST_URL
  },
  {
    "step_id" => "02_review_terms",
    "step_title" => "Review terms before payment",
    "actor" => "buyer",
    "exact_action" => "Open #{TERMS_URL} and read the fixed-scope, input-safety, payment, delivery, and money-counting rules.",
    "proof_required" => "Buyer uses the exact acceptance statement from this page.",
    "counts_as_money" => "no",
    "public_url" => TERMS_URL
  },
  {
    "step_id" => "03_paste_exact_acceptance",
    "step_title" => "Paste exact acceptance statement",
    "actor" => "buyer",
    "exact_action" => "Buyer posts or sends this exact acceptance statement: #{ACCEPTANCE}",
    "proof_required" => "Saved issue form body, buyer message, platform order note, or other dated acceptance record.",
    "counts_as_money" => "no",
    "public_url" => FORM_URL
  },
  {
    "step_id" => "04_keep_input_public_safe",
    "step_title" => "Keep public issue input safe",
    "actor" => "buyer",
    "exact_action" => "Provide only public URLs or non-sensitive buyer-authorized summaries in GitHub. Do not post passwords, credentials, payment cards, tax identifiers, private financial/medical/legal data, confidential files, payment screenshots, or private delivery links.",
    "proof_required" => "Issue body contains only public-safe scope facts and no secrets.",
    "counts_as_money" => "no",
    "public_url" => FORM_URL
  },
  {
    "step_id" => "05_confirm_acceptance_gate",
    "step_title" => "Confirm acceptance criterion",
    "actor" => "buyer",
    "exact_action" => "Write the concrete acceptance criterion: e.g. delivered CSV opens cleanly, audit covers listed public URL, blueprint includes current flow/risks/next actions, or snapshot covers the public business/profile.",
    "proof_required" => "Acceptance criterion in issue form or external order record.",
    "counts_as_money" => "no",
    "public_url" => FORM_URL
  },
  {
    "step_id" => "06_send_seller_owned_payment_route",
    "step_title" => "Use only a seller-owned external payment route",
    "actor" => "seller",
    "exact_action" => "After terms and scope are accepted, use #{PAYMENT_URL} to generate the buyer payment message from a seller-owned checkout, invoice, marketplace order, funded milestone, or payment request URL.",
    "proof_required" => "Seller-owned payment URL or external order reference plus accepted terms.",
    "counts_as_money" => "no",
    "public_url" => PAYMENT_URL
  },
  {
    "step_id" => "07_wait_for_payment_proof",
    "step_title" => "Wait for payment proof before work",
    "actor" => "seller",
    "exact_action" => "Do not start buyer-specific work until the external provider/platform shows payment posted, funded, released, payable, cleared, or otherwise saveable as proof.",
    "proof_required" => "Provider/platform, status, amount, date, buyer/order/reference id where available, and refund/hold status if visible.",
    "counts_as_money" => "yes_after_posted_released_payable_or_cleared",
    "public_url" => PAYMENT_URL
  },
  {
    "step_id" => "08_deliver_fixed_scope_output",
    "step_title" => "Deliver only the selected fixed-scope output",
    "actor" => "seller",
    "exact_action" => "Deliver the selected $100 starter output privately or through the accepted platform channel after payment proof exists. Do not expand into unsupported implementation or account-login work without a separate agreement before payment.",
    "proof_required" => "Delivery record and delivered file/link summary without secrets.",
    "counts_as_money" => "no_without_payment_proof",
    "public_url" => PROOF_URL
  },
  {
    "step_id" => "09_capture_acceptance",
    "step_title" => "Capture acceptance or completion status",
    "actor" => "buyer",
    "exact_action" => "Buyer confirms the fixed-scope output meets the acceptance criterion, or the platform/order marks delivery accepted or complete.",
    "proof_required" => "Buyer acceptance text, order completion, or delivery acceptance record.",
    "counts_as_money" => "yes_only_with_payment_proof",
    "public_url" => PROOF_URL
  },
  {
    "step_id" => "10_count_only_verified_money",
    "step_title" => "Record only verified money",
    "actor" => "seller",
    "exact_action" => "Keep money at $0 unless buyer acceptance, payment proof, delivery proof, and posted/released/payable/cleared payment status exist. Page views, sample downloads, issue comments, stars, forks, IndexNow responses, and unpaid draft requests count $0.",
    "proof_required" => "Payment proof, delivery proof, acceptance/completion proof, amount, date, provider/platform, and refund/hold/fee status where available.",
    "counts_as_money" => "yes",
    "public_url" => PROOF_URL
  }
]

CSV.open(File.join(DOCS, TERMS_CSV), "w") do |csv|
  csv << %w[generated_at_jst step_id step_title actor exact_action proof_required counts_as_money public_url]
  rows.each do |row|
    csv << [STAMP, row["step_id"], row["step_title"], row["actor"], row["exact_action"], row["proof_required"], row["counts_as_money"], row["public_url"]]
  end
end

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

route_rows = routes.map do |route|
  <<~HTML
    <tr>
      <td data-label="Scope">#{h(route["title"])}</td>
      <td data-label="Deliverable">#{h(route["deliverable"])}</td>
      <td data-label="Allowed input">#{h(route["allowed_input"])}</td>
      <td data-label="Acceptance">#{h(route["acceptance_gate"])}</td>
    </tr>
  HTML
end.join

buyer_reply = <<~TEXT.strip
  I can handle one First $100 Fast Start fixed-scope starter at $100.

  Please review #{TERMS_URL} and paste this exact acceptance statement before payment:
  "#{ACCEPTANCE}"

  Then confirm:
  1. Selected starter scope:
  2. Public URL or buyer-authorized non-sensitive input summary:
  3. Deadline:
  4. Acceptance criterion:
  5. Seller-owned external payment/proof route to use:

  Do not post passwords, payment screenshots, credentials, tax identifiers, confidential files, or private delivery links in a public GitHub issue.
TEXT

html = <<~HTML
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Fixed-scope terms, exact acceptance statement, payment proof gate, and delivery checklist for the $100 First $100 Fast Start service.">
    <meta property="og:title" content="First $100 Fast Start Terms and Acceptance">
    <meta property="og:description" content="Exact buyer acceptance and seller proof steps for one $100 fixed-scope starter.">
    <meta property="og:type" content="article">
    <link rel="canonical" href="#{h(TERMS_URL)}">
    <link rel="alternate" type="text/csv" title="First $100 Fast Start terms CSV" href="#{h(TERMS_CSV)}">
    <title>First $100 Fast Start Terms and Acceptance</title>
    <style>
      :root{--ink:#17202a;--muted:#5d6875;--line:#d9dfeb;--panel:#f6f8fb;--accent:#075da8;--green:#17643a;--gold:#8a5a00;--red:#9b1c1c}
      *{box-sizing:border-box}body{margin:0;color:var(--ink);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.45;background:#fff}main{width:min(1180px,calc(100% - 32px));margin:0 auto;padding:28px 0 48px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:20px}h1{margin:0 0 8px;font-size:clamp(1.8rem,4vw,2.75rem);letter-spacing:0}h2{margin:24px 0 10px;font-size:1.25rem;letter-spacing:0}h3{margin:0 0 8px;font-size:1.04rem;letter-spacing:0}p{margin:0 0 10px;overflow-wrap:anywhere}a{color:var(--accent);overflow-wrap:anywhere}.muted{color:var(--muted)}.buttons{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0}.buttons a{display:inline-block;border:1px solid var(--line);border-radius:8px;padding:8px 10px;background:#fff;text-decoration:none;font-weight:700}.metric-grid,.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin:16px 0}.metric,.notice,.panel,.step-card{border:1px solid var(--line);border-radius:8px;background:#fff;padding:12px;min-width:0;overflow-wrap:anywhere}.metric{background:var(--panel)}.metric span,.eyebrow,dt{display:block;color:var(--muted);font-size:.72rem;font-weight:800;text-transform:uppercase;letter-spacing:.04em}.metric strong{display:block;margin-top:6px;font-size:1.15rem}.notice{border-left:6px solid var(--gold);background:#fffaf0}.danger{border-left:6px solid var(--red);background:#fff7f5}.panel,.step-card{border-left:6px solid var(--green)}.step-card dl{display:grid;grid-template-columns:1fr;gap:8px;margin:10px 0 0}.step-card dl div{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:9px}.step-card dd{margin:4px 0 0}.copybox{white-space:pre-wrap;border:1px solid var(--line);border-radius:8px;background:#101820;color:#f7fbff;padding:12px;overflow:auto;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.88rem}table{width:100%;border-collapse:collapse;border:1px solid var(--line);background:#fff}th,td{padding:9px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top;font-size:.9rem;overflow-wrap:anywhere}th{background:var(--panel);color:var(--muted);font-size:.74rem;text-transform:uppercase;letter-spacing:.04em}ol{margin:8px 0 0;padding-left:22px}li{margin:6px 0}
      @media(max-width:900px){.metric-grid,.grid{grid-template-columns:1fr}.buttons{display:grid}.buttons a{width:100%}table,thead,tbody,tr,th,td{display:block}thead{display:none}tr{border-bottom:1px solid var(--line);padding:8px 0}td{border-bottom:0;padding:6px 9px}td::before{content:attr(data-label);display:block;color:var(--muted);font-size:.72rem;font-weight:800;text-transform:uppercase}}
    </style>
    <script type="application/ld+json">#{JSON.pretty_generate({
      "@context" => "https://schema.org",
      "@type" => "WebPage",
      "name" => "First $100 Fast Start Terms and Acceptance",
      "url" => TERMS_URL,
      "isPartOf" => { "@type" => "WebSite", "name" => "Micro Offer Studio", "url" => BASE_URL },
      "about" => { "@type" => "Service", "name" => "First $100 Fast Start", "url" => FAST_URL, "offers" => { "@type" => "Offer", "priceCurrency" => "USD", "price" => 100 } }
    })}</script>
  </head>
  <body>
    <main>
      <header>
        <p class="buttons"><a href="#acceptance">Acceptance statement</a><a href="#proof">Proof gate</a><a href="#steps">Step checklist</a><a href="#scopes">Scopes</a><a href="#templates">Reply template</a><a href="#{h(FAST_HTML)}">Fast Start page</a><a href="#{h(FORM_URL)}">Ready-to-pay form</a><a href="payment-activation.html">Payment activation</a><a href="proof-monitor.html">Proof monitor</a><a href="#{h(TERMS_CSV)}">CSV</a></p>
        <h1>First $100 Fast Start Terms and Acceptance</h1>
        <p class="muted">This is the close page for one $100 fixed-scope starter. It tells the buyer exactly what to accept, what input is safe, what proof to save, and why confirmed money remains $0 until external payment proof exists.</p>
      </header>
      <section class="metric-grid">
        <div class="metric"><span>Price</span><strong>$100</strong></div>
        <div class="metric"><span>Scopes</span><strong>#{routes.size}</strong></div>
        <div class="metric"><span>Money counted now $0</span><strong>$0</strong></div>
        <div class="metric"><span>Private proof needed</span><strong>Yes</strong></div>
      </section>
      <section class="notice">
        <h2>Close Boundary</h2>
        <p><strong>Money counted now $0.</strong> One verified fixed-scope order can reach $100, but only after a real buyer accepts these terms, pays through a seller-owned external route, receives delivery, and the payment is posted, released, payable, or cleared.</p>
      </section>
      <section class="panel" id="acceptance">
        <h2>Exact Acceptance Statement</h2>
        <p>Ask the buyer to send this sentence before payment. If the buyer changes it materially, clarify before sending any payment route.</p>
        <pre class="copybox">#{h(ACCEPTANCE)}</pre>
      </section>
      <section class="danger" id="proof">
        <h2>Money Gate</h2>
        <ol>
          <li>GitHub intake, sample downloads, page views, IndexNow responses, and unpaid comments count $0.</li>
          <li>Payment Activation generates a message only; it is not a payment processor and not proof.</li>
          <li>Count money only after external payment proof exists, delivery proof exists, and funds are posted, released, payable, or cleared.</li>
          <li>Save provider/platform, date, status, amount, buyer/order/reference id where available, delivery proof, and buyer acceptance or platform delivery status.</li>
        </ol>
      </section>
      <section id="steps">
        <h2>Step Checklist</h2>
        <div class="grid">#{step_cards}</div>
      </section>
      <section id="scopes">
        <h2>Included Fixed Scopes</h2>
        <table>
          <thead><tr><th>Scope</th><th>Deliverable</th><th>Allowed input</th><th>Acceptance</th></tr></thead>
          <tbody>#{route_rows}</tbody>
        </table>
      </section>
      <section id="templates">
        <h2>Buyer Reply Template</h2>
        <pre class="copybox">#{h(buyer_reply)}</pre>
      </section>
    </main>
  </body>
  </html>
HTML

File.write(File.join(DOCS, TERMS_HTML), html)

link_html = %(<a href="#{TERMS_HTML}">Fast Start terms</a>)
absolute_link_html = %(<a href="#{TERMS_URL}">Fast Start terms</a>)
link_targets = {
  "index.html" => [[%(<a href="first-100-fast-start.html">First $100 Fast Start</a>), link_html]],
  "first-100-fast-start.html" => [[%(<a href="#{ISSUE_URL}">Open order board #24</a>), absolute_link_html], [%(<a href="payment-activation">Payment activation</a>), link_html]],
  "ready-to-buy.html" => [[%(<a href="first-100-fast-start.html">First $100 Fast Start</a>), link_html]],
  "order-boards.html" => [[%(<a href="first-100-fast-start.html">Open First $100 Fast Start</a>), link_html], [%(<a href="first-100-fast-start.html">First $100 Fast Start</a>), link_html]],
  "order-now.html" => [[%(<a href="first-100-fast-start.html">First $100 Fast Start</a>), link_html]],
  "payment-activation.html" => [[%(<a href="#{FAST_URL}">Ready route</a>), absolute_link_html], [%(<a href="first-100-fast-start.html">First $100 Fast Start</a>), link_html]],
  "paid-offer-action-catalog.html" => [[%(<a href="#{FAST_URL}">First $100 Fast Start</a>), absolute_link_html]],
  "buyer-response-playbook.html" => [[%(<a href="#{FAST_URL}">First $100 Fast Start</a>), absolute_link_html]]
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
search["documents"].reject! { |doc| [TERMS_URL, TERMS_CSV_URL].include?(doc["url"]) }
search["documents"].unshift(
  {
    "type" => "service-terms",
    "title" => "First $100 Fast Start Terms and Acceptance",
    "url" => TERMS_URL,
    "description" => "Exact buyer acceptance statement, seller-owned payment gate, fixed-scope delivery checklist, and proof requirements for the $100 Fast Start.",
    "tags" => %w[first-100 fast-start terms acceptance payment-proof service]
  },
  {
    "type" => "csv",
    "title" => "First $100 Fast Start Terms CSV",
    "url" => TERMS_CSV_URL,
    "description" => "Step-by-step CSV for fixed-scope acceptance, payment proof, delivery, and money-counting gates.",
    "tags" => %w[first-100 fast-start csv terms proof]
  }
)
write_json(search_path, search)

structured_path = File.join(DOCS, "structured-data.json")
structured = JSON.parse(File.read(structured_path))
graph = structured["@graph"] ||= []
graph.reject! { |node| [TERMS_URL, TERMS_CSV_URL].include?(node["url"]) }
graph << {
  "@type" => "WebPage",
  "name" => "First $100 Fast Start Terms and Acceptance",
  "url" => TERMS_URL,
  "description" => "Exact buyer acceptance statement, seller-owned payment gate, fixed-scope delivery checklist, and proof requirements for the $100 Fast Start.",
  "isPartOf" => { "@type" => "WebSite", "name" => "Micro Offer Studio", "url" => BASE_URL },
  "about" => { "@type" => "Service", "name" => "First $100 Fast Start", "url" => FAST_URL }
}
website = graph.find { |node| node["@type"] == "WebSite" }
if website
  website["hasPart"] ||= []
  website["hasPart"].reject! { |part| part["url"] == TERMS_URL }
  website["hasPart"] << { "@type" => "WebPage", "name" => "First $100 Fast Start Terms and Acceptance", "url" => TERMS_URL }
end
write_json(structured_path, structured)

sitemap_path = File.join(DOCS, "sitemap.xml")
sitemap_doc = REXML::Document.new(File.read(sitemap_path))
existing_locs = sitemap_doc.root.get_elements("url/loc").map { |loc| loc.text.to_s.strip }.reject(&:empty?)
sitemap_locs = (existing_locs + [TERMS_URL, TERMS_CSV_URL]).uniq
sitemap_xml = +"<?xml version='1.0' encoding='UTF-8'?>\n<urlset xmlns='http://www.sitemaps.org/schemas/sitemap/0.9'>\n"
sitemap_locs.each { |url| sitemap_xml << "  <url>\n    <loc>#{h(url)}</loc>\n  </url>\n" }
sitemap_xml << "</urlset>\n"
File.write(sitemap_path, sitemap_xml)

urls_csv_path = File.join(DOCS, "indexnow_urls.csv")
urls = []
CSV.foreach(urls_csv_path, headers: true) { |row| urls << row["url"].to_s } if File.exist?(urls_csv_path)
urls.concat([TERMS_URL, TERMS_CSV_URL, FAST_URL, FAST_CSV_URL, PAYMENT_URL, PROOF_URL])
urls = urls.reject(&:empty?).uniq
CSV.open(urls_csv_path, "w") do |csv|
  csv << ["url"]
  urls.each { |url| csv << [url] }
end

payload_path = File.join(DOCS, "indexnow_payload.json")
payload = JSON.parse(File.read(payload_path))
payload["urlList"] = (payload.fetch("urlList") + [TERMS_URL, TERMS_CSV_URL, FAST_URL, FAST_CSV_URL, PAYMENT_URL, PROOF_URL]).uniq
payload["urlList"].sort!
write_json(payload_path, payload)

llms_path = File.join(DOCS, "llms.txt")
llms = File.read(llms_path)
llms_block = <<~TEXT
  ## First $100 Fast Start Terms
  - Terms and acceptance close page: #{TERMS_URL}
  - Terms CSV: #{TERMS_CSV_URL}
  - Exact buyer acceptance: #{ACCEPTANCE}
  - Boundary: count $0 unless a real buyer accepts scope, pays through a seller-owned external route, receives delivery, and funds are posted, released, payable, or cleared.
TEXT
llms = if llms.include?("## First $100 Fast Start Terms")
  llms.sub(/## First \$100 Fast Start Terms\n.*?(?=\n## |\z)/m, llms_block.strip)
else
  "#{llms}\n#{llms_block}"
end
File.write(llms_path, llms)

puts JSON.pretty_generate(
  generated_at_jst: STAMP,
  terms_html: File.join(DOCS, TERMS_HTML),
  terms_csv: File.join(DOCS, TERMS_CSV),
  rows: rows.length,
  terms_url: TERMS_URL,
  terms_csv_url: TERMS_CSV_URL,
  money_confirmed_usd: 0
)
