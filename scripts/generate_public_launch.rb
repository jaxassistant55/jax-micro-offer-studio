#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "cgi"
require "fileutils"
require "json"
require "time"
require "uri"

ENV["TZ"] = "Asia/Tokyo"

RUN_ROOT = File.expand_path("../..", __dir__)
LAUNCH_ROOT = File.expand_path("..", __dir__)
DOCS = File.join(LAUNCH_ROOT, "docs")
GENERATED_AT = Time.now.strftime("%Y-%m-%d %H:%M:%S JST")
REPO_URL = ENV.fetch("PUBLIC_LAUNCH_REPO_URL", "https://github.com/jaxassistant55/jax-micro-offer-studio")
SITE_URL = ENV.fetch("PUBLIC_LAUNCH_SITE_URL", "https://jaxassistant55.github.io/jax-micro-offer-studio/")
ISSUE_URL = "#{REPO_URL}/issues/new?template=paid-inquiry.yml"

def h(value)
  CGI.escapeHTML(value.to_s)
end

def slug(value)
  value.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
end

def read_section(path, heading)
  return "" unless File.exist?(path)

  lines = File.readlines(path, chomp: true)
  start = lines.index { |line| line.strip == heading }
  return "" unless start

  collected = []
  lines[(start + 1)..]&.each do |line|
    break if line.start_with?("## ") && !collected.empty?

    collected << line
  end
  collected.join("\n").strip
end

def first_paragraph(path)
  return "" unless File.exist?(path)

  File.readlines(path, chomp: true).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }.first.to_s
end

def copy_if_exists(src, dest)
  return false unless File.exist?(src)

  FileUtils.mkdir_p(File.dirname(dest))
  FileUtils.cp(src, dest)
  true
end

def copy_preview_dependencies(src, dest_dir)
  html = File.read(src)
  html.scan(/(?:href|src)="([^"]+)"/).flatten.each do |ref|
    next if ref.start_with?("http://", "https://", "mailto:", "#", "data:")

    clean_ref = ref.sub(/#.*/, "")
    next if clean_ref.empty? || clean_ref.end_with?(".zip")

    copy_if_exists(File.join(File.dirname(src), clean_ref), File.join(dest_dir, clean_ref))
  end
end

PRODUCTS = [
  ["HTML5 Micro Game Kit", "html5_micro_game", "$19", "A complete browser-playable micro game kit with source, cover art, README, and listing copy.", "6 sales at $19 clears $100 gross.", "index.html"],
  ["Procedural SFX Pack", "procedural_sfx_pack", "$12", "Original WAV sound effects with preview page, README, license note, and listing copy.", "9 sales at $12 clears $100 gross.", "preview.html"],
  ["SVG Icon Pack", "svg_icon_pack", "$15", "A 24-file SVG icon pack with preview gallery, README, and listing copy.", "7 sales at $15 clears $100 gross.", "preview.html"],
  ["Printable Puzzle and Planner Pack", "printable_puzzle_planner_pack", "$14", "Printable planner pages, math worksheets, answer keys, cover art, and listing copy.", "8 sales at $14 clears $100 gross.", "weekly_planner.html"],
  ["Synthetic Mock Dataset Pack", "synthetic_mock_dataset_pack", "$19", "Synthetic CSV/JSON datasets with a preview dashboard and data dictionary.", "6 sales at $19 clears $100 gross.", "dashboard.html"],
  ["Browser Extension Template", "browser_extension_template", "$29", "Manifest V3 browser extension starter with popup UI, local storage, README, and listing copy.", "4 sales at $29 clears $100 gross.", "popup.html"],
  ["CSV CLI Toolkit", "csv_cli_toolkit", "$19", "Ruby CSV profiling and cleanup CLI with sample input, README, and listing copy.", "6 sales at $19 clears $100 gross.", nil],
  ["CSS Component Pack", "css_component_pack", "$19", "Reusable HTML/CSS components for cards, pricing tables, dashboards, and forms.", "6 sales at $19 clears $100 gross.", "components.html"],
  ["SVG Wallpaper Pattern Pack", "svg_wallpaper_pattern_pack", "$9", "Ten original SVG wallpapers and patterns with a gallery page and listing copy.", "12 sales at $9 clears $100 gross.", "gallery.html"],
  ["Anki-Ready Flashcard Deck", "anki_flashcard_deck", "$12", "Anki-ready CSV flashcard deck for spreadsheet and data-cleaning concepts.", "9 sales at $12 clears $100 gross.", nil],
  ["Mini Course Workbook", "mini_course_workbook", "$29", "Self-study workbook on building a simple digital product offer, with checklist and sales page.", "4 sales at $29 clears $100 gross.", "mini_course.html"],
  ["JSON Schema Fixture Pack", "json_schema_fixture_pack", "$15", "JSON schemas and valid/invalid fixtures for common SaaS objects.", "7 sales at $15 clears $100 gross.", nil]
].map do |title, dir, price, description, first_100, preview|
  product_root = File.join(RUN_ROOT, "non_bounty", "autonomous_products", dir)
  {
    type: "product",
    title: title,
    slug: slug(title),
    source_dir: "non_bounty/autonomous_products/#{dir}",
    price: price,
    description: description,
    first_100: first_100,
    cover: File.join(product_root, "cover.svg"),
    preview: preview && File.join(product_root, preview),
    listing_copy: File.join(product_root, "listing_copy.md"),
    readme: File.join(product_root, "README.md")
  }
end

SERVICES = [
  ["Website Audit Microservice", "website_audit_service", "$150", "Public website, landing-page, accessibility, mobile, copy, and QA quick-win audits.", "One accepted audit clears $100.", "sample_report.html"],
  ["Data Cleanup Sprint", "data_cleanup_service", "$125", "CSV/spreadsheet cleanup with normalized output, validation counts, and a short QA report.", "One completed sprint clears $100.", "cleanup_dashboard.html"],
  ["AI Workflow Tracker Sprint", "freelance_microservice", "$150", "A CSV-backed tracker and static HTML dashboard for interviews, leads, grants, or sales pipelines.", "One fixed-price order clears $100.", "demo/index.html"],
  ["Static Demo Site Customization", "static_demo_site", "$200", "A polished one-page starter site customized for a local service business.", "One starter site clears $100.", "demo_site.html"],
  ["Niche Quote Estimator", "niche_calculator", "$150", "A browser-only quote estimator customized for a simple service pricing model.", "One custom estimator clears $100.", "quote_estimator.html"],
  ["Automation Blueprint", "automation_blueprint", "$100", "Trigger, data field, step, failure-case, and test-plan blueprint for a repetitive workflow.", "One blueprint reaches $100.", "blueprint_dashboard.html"],
  ["Local SEO / GBP Audit", "local_seo_gbp", "$175", "Public local profile and citation audit with review-response and profile-copy suggestions.", "One audit clears $100.", "sample_public_audit.html"],
  ["Technical Docs Cleanup", "technical_docs_cleanup", "$150", "README, quickstart, API page, or SOP cleanup with audit rubric and before/after handoff.", "One docs sprint clears $100.", nil],
  ["Client Intake and SOP Package", "client_intake_sop", "$125", "Reusable intake question bank, SOP template, delivery checklist, and status dashboard.", "One package clears $100.", "sop_dashboard.html"],
  ["PDF/Table Extraction", "pdf_data_extraction", "$125", "Authorized PDF, screenshot, or messy table extraction into CSV plus a summary dashboard.", "One extraction package clears $100.", "data_dashboard.html"],
  ["Content Repurposing Sprint", "content_repurposing_service", "$100", "Newsletter, social posts, captions, hooks, and publishing checklist from one source asset.", "One repurposing sprint reaches $100.", "content_dashboard.html"],
  ["Resume / LinkedIn / Interview Pack", "career_services", "$125", "Truthful resume, LinkedIn, cover letter, and interview prep packet.", "One career packet clears $100.", nil]
].map do |title, dir, price, description, first_100, preview|
  service_root = File.join(RUN_ROOT, "non_bounty", dir)
  {
    type: "service",
    title: title,
    slug: slug(title),
    source_dir: "non_bounty/#{dir}",
    price: price,
    description: description,
    first_100: first_100,
    preview: preview && File.join(service_root, preview),
    offer: File.join(service_root, "offer.md"),
    listing_copy: File.join(service_root, "listing_copy.md"),
    sales_copy: File.join(service_root, "sales_copy.md")
  }
end

OFFERS = PRODUCTS + SERVICES

FileUtils.rm_rf(DOCS)
FileUtils.mkdir_p(File.join(DOCS, "assets", "covers"))
FileUtils.mkdir_p(File.join(DOCS, "previews"))
FileUtils.mkdir_p(File.join(LAUNCH_ROOT, ".github", "ISSUE_TEMPLATE"))

def card_html(offer)
  cover = "assets/covers/#{offer[:slug]}.svg"
  detail = "#{offer[:slug]}.html"
  issue = "#{ISSUE_URL}&title=#{CGI.escape("Inquiry: #{offer[:title]}")}"
  <<~HTML
    <article class="card #{h(offer[:type])}">
      #{File.exist?(File.join(DOCS, cover)) ? %(<img src="#{h(cover)}" alt="#{h(offer[:title])} cover">) : %(<div class="placeholder">#{h(offer[:type])}</div>)}
      <div>
        <span class="eyebrow">#{h(offer[:type])} / #{h(offer[:price])}</span>
        <h3>#{h(offer[:title])}</h3>
        <p>#{h(offer[:description])}</p>
        <p><strong>First $100 path:</strong> #{h(offer[:first_100])}</p>
        <p class="buttons"><a href="#{h(detail)}">Details</a><a href="#{h(issue)}">Request this</a></p>
      </div>
    </article>
  HTML
end

def page_shell(title, body)
  description = "Public previews and paid-inquiry pages for generated digital products and productized micro-services."
  <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="description" content="#{h(description)}">
      <meta property="og:title" content="#{h(title)}">
      <meta property="og:description" content="#{h(description)}">
      <meta property="og:type" content="website">
      <title>#{h(title)}</title>
      <style>
        :root{--ink:#17202a;--muted:#5d6875;--line:#d9dfeb;--panel:#f6f8fb;--accent:#075da8;--green:#17643a;--gold:#8a5a00}
        *{box-sizing:border-box}body{margin:0;color:var(--ink);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.45;background:#fff}main{width:min(1180px,calc(100% - 32px));margin:0 auto;padding:28px 0 48px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:20px}h1{margin:0 0 8px;font-size:clamp(1.8rem,4vw,2.75rem);letter-spacing:0}h2{margin:24px 0 10px;font-size:1.25rem;letter-spacing:0}h3{margin:0 0 6px;font-size:1.05rem;letter-spacing:0}p{margin:0 0 10px}a{color:var(--accent)}.muted{color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.card,.notice,.panel{border:1px solid var(--line);border-radius:8px;background:#fff;padding:12px;min-width:0;overflow-wrap:anywhere}.card{display:grid;grid-template-columns:180px 1fr;gap:14px}.card.product{border-left:6px solid var(--green)}.card.service{border-left:6px solid var(--accent)}img,.placeholder{width:100%;aspect-ratio:16/10;object-fit:cover;border:1px solid var(--line);border-radius:6px;background:var(--panel)}.placeholder{display:grid;place-items:center;color:var(--muted);font-weight:700;text-transform:uppercase}.eyebrow{display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.04em}.buttons{display:flex;gap:8px;flex-wrap:wrap}.buttons a{display:inline-block;border:1px solid var(--line);border-radius:8px;padding:8px 10px;background:#fff;text-decoration:none;font-weight:700}.notice{border-left:6px solid var(--gold);background:#fffaf0}.split{display:grid;grid-template-columns:minmax(0,1fr) 320px;gap:16px}.fact{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:10px;margin:0 0 10px}.fact span{display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.04em}.preview-frame{width:100%;min-height:520px;border:1px solid var(--line);border-radius:8px;background:#fff}ul{padding-left:20px}li{margin:6px 0}code{white-space:normal;overflow-wrap:anywhere}
        @media(max-width:900px){.grid,.card,.split{grid-template-columns:1fr}.buttons{display:grid}.buttons a{width:100%}}
      </style>
    </head>
    <body>
      <main>#{body}</main>
    </body>
    </html>
  HTML
end

OFFERS.each do |offer|
  if offer[:cover] && File.exist?(offer[:cover])
    copy_if_exists(offer[:cover], File.join(DOCS, "assets", "covers", "#{offer[:slug]}.svg"))
  end
  if offer[:preview] && File.exist?(offer[:preview])
    ext = File.extname(offer[:preview])
    preview_dest_dir = File.join(DOCS, "previews")
    copy_if_exists(offer[:preview], File.join(preview_dest_dir, "#{offer[:slug]}#{ext}"))
    copy_preview_dependencies(offer[:preview], preview_dest_dir) if ext == ".html"
    offer[:preview_public] = "previews/#{offer[:slug]}#{ext}"
  end
end

index_body = <<~HTML
  <header>
    <p class="buttons"><a href="products.html">Products</a><a href="services.html">Services</a><a href="#request">Request work</a><a href="source-notes.html">Source notes</a></p>
    <h1>Micro Offer Studio</h1>
    <p class="muted">A public launch page for generated digital products and productized micro-services prepared during the autonomous earning run. Checkout is not connected here; use the inquiry link for a paid request, custom scope, or storefront transfer.</p>
  </header>
  <section class="notice">
    <h2>Money Status</h2>
    <p>Confirmed earned money from this public launch package is $0 until an external buyer, payment, refund, credit, or payout proof exists. The autonomous work completed here is public packaging, discoverability, and inquiry infrastructure.</p>
  </section>
  <section>
    <h2>Fastest $100 Paths</h2>
    <div class="grid">
      #{(SERVICES.first(6) + PRODUCTS.values_at(5, 10, 4, 6)).compact.map { |offer| card_html(offer) }.join}
    </div>
  </section>
  <section id="request" class="panel">
    <h2>Request Work Or A Product Bundle</h2>
    <p>Open a GitHub issue with the offer name, desired scope, deadline, and proof/payment preference. Do not include private credentials, financial details, medical/legal information, or files you are not authorized to share.</p>
    <p class="buttons"><a href="#{h(ISSUE_URL)}">Open paid inquiry issue</a><a href="#{h(REPO_URL)}">View GitHub repo</a></p>
  </section>
HTML
File.write(File.join(DOCS, "index.html"), page_shell("Micro Offer Studio", index_body))

File.write(File.join(DOCS, "products.html"), page_shell("Products - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="services.html">Services</a><a href="source-notes.html">Source notes</a></p><h1>Digital Products</h1><p class="muted">Preview-only public listings. Full ZIP bundles remain local until a seller checkout or paid transfer is configured.</p></header>
  <section class="grid">#{PRODUCTS.map { |offer| card_html(offer) }.join}</section>
HTML

File.write(File.join(DOCS, "services.html"), page_shell("Services - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="products.html">Products</a><a href="source-notes.html">Source notes</a></p><h1>Productized Services</h1><p class="muted">Fixed-scope offers that can clear $100 with one accepted order. Buyer authorization and payment proof are still required.</p></header>
  <section class="grid">#{SERVICES.map { |offer| card_html(offer) }.join}</section>
HTML

OFFERS.each do |offer|
  issue = "#{ISSUE_URL}&title=#{CGI.escape("Inquiry: #{offer[:title]}")}"
  body = <<~HTML
    <header>
      <p class="buttons"><a href="index.html">Home</a><a href="#{offer[:type] == "product" ? "products.html" : "services.html"}">Back to #{h(offer[:type])}s</a><a href="#{h(issue)}">Request this</a></p>
      <h1>#{h(offer[:title])}</h1>
      <p class="muted">#{h(offer[:description])}</p>
    </header>
    <section class="split">
      <div>
        <section class="panel">
          <h2>Offer</h2>
          <p><strong>Suggested price:</strong> #{h(offer[:price])}</p>
          <p><strong>First $100 path:</strong> #{h(offer[:first_100])}</p>
          <p><strong>Public boundary:</strong> This page is a preview/inquiry page. It does not collect payment, create a contract, or prove earnings by itself.</p>
        </section>
        <section class="panel">
          <h2>Buyer Fit</h2>
          <ul>
            <li>Use this when the buyer can provide truthful scope, rights, files, account access decisions, or public inputs.</li>
            <li>Do not use this for regulated legal, medical, financial, tax, safety-critical, or deceptive claims.</li>
            <li>Count money only after buyer acceptance and released payment, posted checkout sale, or equivalent external proof.</li>
          </ul>
        </section>
        #{offer[:preview_public] ? %(<section class="panel"><h2>Preview</h2><iframe class="preview-frame" src="#{h(offer[:preview_public])}" title="#{h(offer[:title])} preview"></iframe></section>) : ""}
      </div>
      <aside>
        <div class="fact"><span>Type</span><strong>#{h(offer[:type])}</strong></div>
        <div class="fact"><span>Price</span><strong>#{h(offer[:price])}</strong></div>
        <div class="fact"><span>Source asset folder</span><code>#{h(offer[:source_dir])}</code></div>
        <div class="fact"><span>Inquiry</span><a href="#{h(issue)}">Open issue template</a></div>
      </aside>
    </section>
  HTML
  File.write(File.join(DOCS, "#{offer[:slug]}.html"), page_shell("#{offer[:title]} - Micro Offer Studio", body))
end

source_body = <<~HTML
  <header><p class="buttons"><a href="index.html">Home</a><a href="products.html">Products</a><a href="services.html">Services</a></p><h1>Source Notes</h1><p class="muted">Generated #{h(GENERATED_AT)} from local assets under <code>#{h(RUN_ROOT)}</code>.</p></header>
  <section class="notice"><h2>Public Safety Boundary</h2><p>The public launch package intentionally excludes private credentials, user financial data, buyer files, KYC/tax details, and full paid ZIP downloads. It publishes generated previews, offer pages, and an inquiry template only.</p></section>
  <section><h2>Included Offers</h2><ul>#{OFFERS.map { |offer| "<li>#{h(offer[:title])} - #{h(offer[:type])} - #{h(offer[:source_dir])}</li>" }.join}</ul></section>
HTML
File.write(File.join(DOCS, "source-notes.html"), page_shell("Source Notes - Micro Offer Studio", source_body))

CSV.open(File.join(LAUNCH_ROOT, "public_launch_manifest.csv"), "w", write_headers: true, headers: %w[generated_at_jst type title slug price source_dir public_detail preview_public first_100]) do |csv|
  OFFERS.each do |offer|
    csv << [GENERATED_AT, offer[:type], offer[:title], offer[:slug], offer[:price], offer[:source_dir], "docs/#{offer[:slug]}.html", offer[:preview_public].to_s, offer[:first_100]]
  end
end

File.write(File.join(LAUNCH_ROOT, "README.md"), <<~MD)
  # Micro Offer Studio

  Public launch package generated during the autonomous earning run.

  - Generated: #{GENERATED_AT}
  - Live site: #{SITE_URL}
  - Public site root: `docs/index.html`
  - Manifest: `public_launch_manifest.csv`
  - Inquiry path: #{ISSUE_URL}
  - Offers: #{PRODUCTS.length} digital products and #{SERVICES.length} productized services

  Confirmed earned money is still `$0` until external buyer/payment/payout proof exists. This repo publishes generated preview and inquiry material only; it does not include private credentials, KYC/tax/payment data, or private buyer files.

  ## Fastest $100 paths

  #{(SERVICES.first(6) + PRODUCTS.values_at(5, 10, 4, 6)).compact.map { |offer| "- #{offer[:title]} (#{offer[:price]}): #{offer[:first_100]}" }.join("\n")}

  ## Inquiry safety

  Use the paid inquiry issue template for legitimate paid requests only. Do not post passwords, payment cards, tax identifiers, medical/legal/financial private details, or files you are not authorized to share.
MD

File.write(File.join(LAUNCH_ROOT, ".github", "ISSUE_TEMPLATE", "paid-inquiry.yml"), <<~YAML)
  name: Paid inquiry
  description: Request a product bundle, custom service, or scoped paid handoff.
  title: "Inquiry: "
  labels: ["paid-inquiry"]
  body:
    - type: markdown
      attributes:
        value: |
          Use this for legitimate paid inquiries only. Do not paste passwords, payment cards, tax identifiers, medical/legal/financial private details, or files you are not authorized to share.
    - type: input
      id: offer
      attributes:
        label: Offer or product
        description: Which Micro Offer Studio item are you asking about?
      validations:
        required: true
    - type: textarea
      id: scope
      attributes:
        label: Scope
        description: What do you want delivered or transferred?
      validations:
        required: true
    - type: input
      id: budget
      attributes:
        label: Budget
        description: Expected budget or price range.
        placeholder: "$100+"
      validations:
        required: true
    - type: input
      id: deadline
      attributes:
        label: Deadline
        description: When do you need it?
      validations:
        required: false
    - type: textarea
      id: proof
      attributes:
        label: Acceptance and payment proof
        description: What external proof will show the work is accepted and payable?
      validations:
        required: true
YAML

File.write(File.join(LAUNCH_ROOT, ".gitignore"), <<~TXT)
  .DS_Store
TXT

File.write(File.join(DOCS, "offers.json"), JSON.pretty_generate(OFFERS.map do |offer|
  offer.slice(:type, :title, :slug, :source_dir, :price, :description, :first_100, :preview_public)
end))

urls = ["", "products.html", "services.html", "source-notes.html"] + OFFERS.map { |offer| "#{offer[:slug]}.html" }
File.write(File.join(DOCS, "sitemap.xml"), <<~XML)
  <?xml version="1.0" encoding="UTF-8"?>
  <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  #{urls.map { |path| "  <url><loc>#{h(URI.join(SITE_URL, path).to_s)}</loc></url>" }.join("\n")}
  </urlset>
XML

File.write(File.join(DOCS, "robots.txt"), <<~TXT)
  User-agent: *
  Allow: /
  Sitemap: #{SITE_URL}sitemap.xml
TXT

puts "Generated #{OFFERS.length} public offers in #{DOCS}"
