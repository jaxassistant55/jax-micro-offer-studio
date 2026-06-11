#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "cgi"
require "digest"
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
INDEXNOW_KEY = ENV.fetch("PUBLIC_LAUNCH_INDEXNOW_KEY", "32ac58c2-053a-4ba2-ba9a-a6a92cdecf12")
INDEXNOW_KEY_FILE = "#{INDEXNOW_KEY}.txt"
INDEXNOW_KEY_LOCATION = URI.join(SITE_URL, INDEXNOW_KEY_FILE).to_s
ISSUE_URL = "#{REPO_URL}/issues/new?template=paid-inquiry.yml"
ISSUE_BOARD_URL = "#{REPO_URL}/issues/24"
NEW_ISSUE_URL = "#{REPO_URL}/issues/new"

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

def price_amount(offer)
  offer[:price].to_s.gsub(/[^\d.]/, "").to_f
end

def absolute_url(path = "")
  URI.join(SITE_URL, path).to_s
end

def jsonld_script(data)
  <<~HTML
    <script type="application/ld+json">
    #{JSON.pretty_generate(data)}
    </script>
  HTML
end

def prefilled_issue_url(offer, title_prefix: "Ready to pay")
  body = <<~BODY
    ## Ready-to-pay intake

    Offer: #{offer[:title]}
    Listed price: #{offer[:price]}
    Offer page: #{SITE_URL}#{offer[:slug]}.html
    Offer type: #{offer[:type]}

    Requested quantity or scope:
    Payment/proof route:
    Deadline:
    Acceptance proof:
    Delivery preference:

    Safety confirmation:
    - I will not post passwords, payment cards, tax identifiers, medical/legal/financial private details, or files I am not authorized to share.
    - I understand this issue is not payment by itself; money counts only after external payment or payout proof exists.
  BODY

  query = URI.encode_www_form(
    template: "ready-to-pay.md",
    title: "#{title_prefix}: #{offer[:title]}",
    labels: "paid-inquiry,ready-to-pay",
    body: body
  )
  "#{NEW_ISSUE_URL}?#{query}"
end

def template_issue_url(offer)
  template = offer[:type] == "product" ? "product-transfer.yml" : "service-scope.yml"
  title = offer[:type] == "product" ? "Product transfer: #{offer[:title]}" : "Service scope: #{offer[:title]}"
  "#{NEW_ISSUE_URL}?#{URI.encode_www_form(template: template, title: title)}"
end

def offer_schema(offer)
  {
    "@context" => "https://schema.org",
    "@type" => offer[:type] == "product" ? "Product" : "Service",
    "name" => offer[:title],
    "description" => offer[:description],
    "url" => absolute_url("#{offer[:slug]}.html"),
    "provider" => {
      "@type" => "Organization",
      "name" => "Micro Offer Studio",
      "url" => SITE_URL
    },
    "offers" => {
      "@type" => "Offer",
      "priceCurrency" => "USD",
      "price" => price_amount(offer),
      "availability" => "https://schema.org/InStock",
      "url" => prefilled_issue_url(offer)
    }
  }
end

def tool_schema(row)
  {
    "@context" => "https://schema.org",
    "@type" => "SoftwareApplication",
    "name" => row[:title],
    "applicationCategory" => "BusinessApplication",
    "operatingSystem" => "Any modern browser",
    "url" => absolute_url(row[:path]),
    "description" => "Free browser-only lead tool for #{row[:service]}.",
    "offers" => {
      "@type" => "Offer",
      "priceCurrency" => "USD",
      "price" => 0,
      "url" => absolute_url(row[:path])
    }
  }
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
  ["JSON Schema Fixture Pack", "json_schema_fixture_pack", "$15", "JSON schemas and valid/invalid fixtures for common SaaS objects.", "7 sales at $15 clears $100 gross.", nil],
  ["Invoice and Expense Tracker Template", "invoice_expense_tracker", "$19", "A lightweight CSV and local dashboard template for freelancers tracking invoices, expenses, status, and outstanding payments.", "6 sales at $19 clears $100 gross.", "dashboard.html"],
  ["Prompt Workflow Pack", "prompt_workflow_pack", "$19", "A local-service prompt library and workflow pack for intake replies, quote follow-ups, review responses, and internal summaries.", "6 sales at $19 clears $100 gross, or one $100 customized setup reaches $100.", "sales_page.html"],
  ["Sales Enablement Kit", "sales_enablement", "$29", "Proposal library, compliant outreach sequence, prospect tracker, profile checklist, case study template, and simple portfolio page for fixed-scope service sellers.", "4 sales at $29 clears $100 gross, or one $100 customized proposal/profile setup reaches $100.", "portfolio_page.html"]
].map do |title, dir, price, description, first_100, preview|
  source_prefix = %w[invoice_expense_tracker prompt_workflow_pack sales_enablement].include?(dir) ? "non_bounty" : "non_bounty/autonomous_products"
  product_root = File.join(RUN_ROOT, source_prefix, dir)
  {
    type: "product",
    title: title,
    slug: slug(title),
    source_dir: "#{source_prefix}/#{dir}",
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
  ["Resume / LinkedIn / Interview Pack", "career_services", "$125", "Truthful resume, LinkedIn, cover letter, and interview prep packet.", "One career packet clears $100.", nil],
  ["Resale Listing and Price Research Pack", "resale_listing_research", "$100", "Item-intake, photo checklist, comparable-price research template, listing drafts, pricing risk notes, and owner posting checklist for up to 10 owned items.", "One paid resale listing pack reaches $100.", nil],
  ["Translation and Localization Draft Pack", "translation_localization", "$100", "Review-ready localization intake, glossary notes, draft structure, locale choices, and QA checklist for up to 1,000 source words.", "One paid localization draft pack reaches $100.", nil],
  ["Subscription Audit and Savings Prep Pack", "subscription_audit", "$100", "Recurring-charge audit template, savings calculator, cancellation/downgrade scripts, risk controls, and proof checklist for finding avoidable subscription costs.", "One paid subscription-audit prep pack reaches $100; one verified $9/month downgrade can also prove $108/year in savings for the account owner.", "audit_dashboard.html"]
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

ZIP_BY_SLUG = {
  "html5-micro-game-kit" => "html5-micro-game-kit.zip",
  "procedural-sfx-pack" => "procedural-sfx-pack.zip",
  "svg-icon-pack" => "svg-icon-pack.zip",
  "printable-puzzle-and-planner-pack" => "printable-puzzle-planner-pack.zip",
  "synthetic-mock-dataset-pack" => "synthetic-mock-dataset-pack.zip",
  "browser-extension-template" => "browser-extension-template.zip",
  "csv-cli-toolkit" => "csv-cli-toolkit.zip",
  "css-component-pack" => "css-component-pack.zip",
  "svg-wallpaper-pattern-pack" => "svg-wallpaper-pattern-pack.zip",
  "anki-ready-flashcard-deck" => "anki-flashcard-deck.zip",
  "mini-course-workbook" => "mini-course-workbook.zip",
  "json-schema-fixture-pack" => "json-schema-fixture-pack.zip",
  "invoice-and-expense-tracker-template" => "invoice-expense-tracker-kit.zip",
  "prompt-workflow-pack" => "prompt-workflow-pack-kit.zip",
  "sales-enablement-kit" => "sales-enablement-kit.zip",
  "website-audit-microservice" => "website-audit-service-kit.zip",
  "data-cleanup-sprint" => "data-cleanup-service-kit.zip",
  "static-demo-site-customization" => "static-demo-site-kit.zip",
  "niche-quote-estimator" => "niche-calculator-kit.zip",
  "automation-blueprint" => "automation-blueprint-kit.zip",
  "local-seo-gbp-audit" => "local-seo-gbp-kit.zip",
  "technical-docs-cleanup" => "technical-docs-cleanup-kit.zip",
  "client-intake-and-sop-package" => "client-intake-sop-kit.zip",
  "pdf-table-extraction" => "pdf-data-extraction-kit.zip",
  "content-repurposing-sprint" => "content-repurposing-service-kit.zip",
  "resume-linkedin-interview-pack" => "career-services-kit.zip",
  "resale-listing-and-price-research-pack" => "resale-listing-research-kit.zip",
  "translation-and-localization-draft-pack" => "translation-localization-kit.zip",
  "subscription-audit-and-savings-prep-pack" => "subscription-audit-kit.zip"
}.freeze

OFFERS.each do |offer|
  zip_name = ZIP_BY_SLUG[offer[:slug]]
  next unless zip_name

  zip_path = File.join(RUN_ROOT, "non_bounty", zip_name)
  next unless File.exist?(zip_path)

  offer[:zip_name] = zip_name
  offer[:zip_bytes] = File.size(zip_path)
  offer[:zip_sha256] = Digest::SHA256.file(zip_path).hexdigest
end

ORDER_BOARDS_PATH = File.join(LAUNCH_ROOT, "order_boards.csv")
ORDER_BOARDS = File.exist?(ORDER_BOARDS_PATH) ? CSV.read(ORDER_BOARDS_PATH, headers: true).map(&:to_h) : []
PROOF_MONITOR_PATH = File.join(LAUNCH_ROOT, "proof_monitor.csv")
PROOF_MONITOR = File.exist?(PROOF_MONITOR_PATH) ? CSV.read(PROOF_MONITOR_PATH, headers: true).map(&:to_h) : []
GITHUB_LEADS_PATH = File.join(RUN_ROOT, "github_lead_repos", "github_lead_repos.csv")
GITHUB_LEADS = File.exist?(GITHUB_LEADS_PATH) ? CSV.read(GITHUB_LEADS_PATH, headers: true).map(&:to_h) : []

FileUtils.rm_rf(DOCS)
FileUtils.mkdir_p(File.join(DOCS, "assets", "covers"))
FileUtils.mkdir_p(File.join(DOCS, "previews"))
FileUtils.mkdir_p(File.join(DOCS, "samples"))
FileUtils.mkdir_p(File.join(LAUNCH_ROOT, ".github", "ISSUE_TEMPLATE"))

def card_html(offer)
  cover = "assets/covers/#{offer[:slug]}.svg"
  detail = "#{offer[:slug]}.html"
  issue = prefilled_issue_url(offer)
  <<~HTML
    <article class="card #{h(offer[:type])}">
      #{File.exist?(File.join(DOCS, cover)) ? %(<img src="#{h(cover)}" alt="#{h(offer[:title])} cover">) : %(<div class="placeholder">#{h(offer[:type])}</div>)}
      <div>
        <span class="eyebrow">#{h(offer[:type])} / #{h(offer[:price])}</span>
        <h3>#{h(offer[:title])}</h3>
        <p>#{h(offer[:description])}</p>
        <p><strong>First $100 path:</strong> #{h(offer[:first_100])}</p>
        <p class="buttons"><a href="#{h(detail)}">Details</a><a href="#{h(issue)}">Start order</a></p>
      </div>
    </article>
  HTML
end

def fulfillment_rows(offers)
  offers.map do |offer|
    if offer[:zip_name]
      status = "Local paid bundle ready"
      artifact = "#{offer[:zip_name]} (#{offer[:zip_bytes]} bytes)"
      checksum = offer[:zip_sha256]
    else
      status = "Source folder ready"
      artifact = offer[:source_dir]
      checksum = "N/A"
    end
    <<~HTML
      <tr>
        <td data-label="Offer"><a href="#{h(offer[:slug])}.html">#{h(offer[:title])}</a></td>
        <td data-label="Type">#{h(offer[:type])}</td>
        <td data-label="Price">#{h(offer[:price])}</td>
        <td data-label="Fulfillment status">#{h(status)}</td>
        <td data-label="Artifact">#{h(artifact)}</td>
        <td data-label="SHA-256">#{h(checksum)}</td>
      </tr>
    HTML
  end.join
end

def pricing_rows(offers)
  offers.map do |offer|
    issue = prefilled_issue_url(offer)
    <<~HTML
      <tr>
        <td data-label="Offer"><a href="#{h(offer[:slug])}.html">#{h(offer[:title])}</a></td>
        <td data-label="Type">#{h(offer[:type])}</td>
        <td data-label="Price">#{h(offer[:price])}</td>
        <td data-label="Path to $100">#{h(offer[:first_100])}</td>
        <td data-label="Ready state">#{h(offer[:zip_name] ? "Bundle checksum listed" : "Source folder listed")}</td>
        <td data-label="Inquiry"><a href="#{h(issue)}">Start order</a></td>
      </tr>
    HTML
  end.join
end

def case_study_cards(offers)
  offers.select { |offer| offer[:preview_public] }.first(12).map do |offer|
    issue = prefilled_issue_url(offer)
    <<~HTML
      <article class="panel">
        <h2>#{h(offer[:title])}</h2>
        <p>#{h(offer[:description])}</p>
        <p><strong>Commercial path:</strong> #{h(offer[:first_100])}</p>
        <p><strong>Fulfillment:</strong> #{h(offer[:zip_name] ? "Local paid bundle ready; checksum on fulfillment page." : "Source folder ready.")}</p>
        <p class="buttons"><a href="#{h(offer[:slug])}.html">Offer page</a><a href="#{h(offer[:preview_public])}">Open preview</a><a href="#{h(issue)}">Start order</a></p>
      </article>
    HTML
  end.join
end

def share_rows(offers)
  offers.first(16).map do |offer|
    text = "Ready-to-scope #{offer[:type]}: #{offer[:title]} (#{offer[:price]}). #{offer[:description]} Details: #{SITE_URL}#{offer[:slug]}.html"
    <<~HTML
      <tr>
        <td data-label="Offer">#{h(offer[:title])}</td>
        <td data-label="Price">#{h(offer[:price])}</td>
        <td data-label="Snippet"><div class="copybox">#{h(text)}</div></td>
      </tr>
    HTML
  end.join
end

def order_board_rows(rows)
  rows.map do |row|
    <<~HTML
      <tr>
        <td data-label="Issue"><a href="#{h(row["issue_url"])}">##{h(row["issue_number"])}</a></td>
        <td data-label="Offer"><a href="#{h(row["detail_url"])}">#{h(row["title"])}</a></td>
        <td data-label="Type">#{h(row["type"])}</td>
        <td data-label="Price">#{h(row["price"])}</td>
        <td data-label="Path to $100">#{h(row["first_100_path"])}</td>
        <td data-label="State">#{h(row["state"])}</td>
        <td data-label="Comments">#{h(row["comments"])}</td>
      </tr>
    HTML
  end.join
end

def proof_monitor_rows(rows)
  rows.map do |row|
    signal_url = row["url"].to_s.empty? ? row["issue_url"] : row["url"]
    signal_id = row["signal_id"].to_s.empty? ? "##{row["issue_number"]}" : row["signal_id"]
    comments = row["issue_comments"].to_s.empty? ? row["comments"] : row["issue_comments"]
    downloads = row["release_downloads"].to_s.empty? ? "0" : row["release_downloads"]
    <<~HTML
      <tr>
        <td data-label="Signal"><a href="#{h(signal_url)}">#{h(signal_id)}</a><br><span class="muted">#{h(row["repo"])}</span></td>
        <td data-label="Kind">#{h(row["kind"])}</td>
        <td data-label="Title">#{h(row["title"])}</td>
        <td data-label="Price">#{h(row["price"])}</td>
        <td data-label="State">#{h(row["state"])}</td>
        <td data-label="Issue comments">#{h(comments)}</td>
        <td data-label="Release downloads">#{h(downloads)}</td>
        <td data-label="Proof status">#{h(row["proof_status"])}</td>
        <td data-label="Next paid step"><a href="#{h(row["next_paid_step"])}">Open</a></td>
        <td data-label="Money">#{h(row["money_confirmed_usd"])}</td>
      </tr>
    HTML
  end.join
end

def github_lead_rows(rows)
  rows.map do |row|
    repo_order = row["repo_order_issue_url"].to_s
    repo_order_link = repo_order.empty? ? "" : %(<br><a href="#{h(repo_order)}">Repo order board ##{h(row["repo_order_issue_number"])}</a>)
    landing = row["standalone_index_url"].to_s
    landing_link = landing.empty? ? "" : %(<a href="#{h(landing)}">Landing page</a><br>)
    inquiry_link = landing.empty? ? "" : %(<a href="#{h(landing)}inquiry.html">Prefilled inquiry</a><br>)
    <<~HTML
      <tr>
        <td data-label="Lead repo"><a href="#{h(row["repo_url"])}">#{h(row["title"])}</a><br><span class="muted">#{h(row["type"])}</span></td>
        <td data-label="Price">#{h(row["price"])}</td>
        <td data-label="Path to $100">#{h(row["first_100_path"])}</td>
        <td data-label="Preview">#{landing_link}<a href="#{h(row["pages_url"])}">Pages preview</a><br><span class="muted">#{h(row["pages_status"])}</span></td>
        <td data-label="Conversion">#{inquiry_link}<a href="#{h(row["issue_template_url"])}">Paid inquiry template</a>#{repo_order_link}<br><a href="#{h(row["order_issue_url"])}">Main order board</a></td>
        <td data-label="Release"><a href="#{h(row["release_url"])}">preview-v1</a><br><a href="#{h(row["asset_url"])}">ZIP asset</a></td>
        <td data-label="Proof rule">#{h(row["proof_rule"])}</td>
      </tr>
    HTML
  end.join
end

def direct_order_rows(rows)
  rows.select { |row| !row["repo_order_issue_url"].to_s.empty? }.sort_by { |row| -row["price"].to_s.gsub(/[^\d.]/, "").to_f }.map do |row|
    landing = row["standalone_index_url"].to_s
    landing_link = landing.empty? ? "" : %(<a href="#{h(landing)}">Landing</a><br>)
    inquiry_link = landing.empty? ? "" : %(<br><a href="#{h(landing)}inquiry.html">Prefilled inquiry</a>)
    <<~HTML
      <tr>
        <td data-label="Offer"><a href="#{h(row["repo_order_issue_url"])}">#{h(row["title"])}</a><br><span class="muted">#{h(row["type"])}</span></td>
        <td data-label="Price">#{h(row["price"])}</td>
        <td data-label="Buyer action">Open the prefilled inquiry or comment on repo order board ##{h(row["repo_order_issue_number"])} with scope, deadline, and safe non-sensitive inputs.#{inquiry_link}</td>
        <td data-label="Preview">#{landing_link}<a href="#{h(row["pages_url"])}">Preview</a><br><a href="#{h(row["repo_url"])}">Repo</a></td>
        <td data-label="Proof">#{h(row["proof_rule"])}</td>
      </tr>
    HTML
  end.join
end

def write_sample_pack(offers)
  samples_dir = File.join(DOCS, "samples")
  FileUtils.mkdir_p(samples_dir)
  sample_files = []

  sample_files << ["README.md", <<~MD]
    # Micro Offer Studio Sample Pack

    This free sample pack demonstrates the type of public, low-risk material available from Micro Offer Studio. It is not the full paid product bundle and is not proof of earnings.

    Full fulfillment ledger: #{SITE_URL}fulfillment.html
    First $100 Fast Start board: #{ISSUE_BOARD_URL}
  MD

  sample_files << ["pricing_sample.csv", CSV.generate do |csv|
    csv << %w[type title price first_100_path detail_url]
    offers.first(10).each do |offer|
      csv << [offer[:type], offer[:title], offer[:price], offer[:first_100], "#{SITE_URL}#{offer[:slug]}.html"]
    end
  end]

  sample_files << ["proof_rules_sample.md", <<~MD]
    # Proof Rules Sample

    Count money only when external proof exists:

    - paid order
    - cleared invoice
    - funded milestone
    - payable balance
    - posted refund or credit
    - next-bill reduction

    Do not count public pages, issues, estimates, draft listings, unaccepted work, or pending requests.
  MD

  sample_files << ["buyer_brief_template.md", <<~MD]
    # Buyer Brief Template

    Offer:
    Budget/payment route:
    Deadline:
    Public URL or authorized input:
    Acceptance proof:
    Delivery preference:

    Do not include passwords, payment cards, tax identifiers, regulated private information, or files you are not authorized to share.
  MD

  sample_files.each do |name, content|
    File.write(File.join(samples_dir, name), content)
  end

  zip_path = File.join(DOCS, "micro-offer-studio-sample-pack.zip")
  FileUtils.rm_f(zip_path)
  sample_root = File.join(samples_dir, "micro-offer-studio-sample-pack")
  FileUtils.rm_rf(sample_root)
  FileUtils.mkdir_p(sample_root)
  sample_files.each do |name, _|
    FileUtils.cp(File.join(samples_dir, name), File.join(sample_root, name))
  end
  system("zip", "-qr", zip_path, "micro-offer-studio-sample-pack", chdir: samples_dir) || raise("failed to create sample pack")

  {
    path: zip_path,
    bytes: File.size(zip_path),
    sha256: Digest::SHA256.file(zip_path).hexdigest,
    files: sample_files.map(&:first)
  }
end

def page_shell(title, body, head_extra = "")
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
      <link rel="alternate" type="application/rss+xml" title="Micro Offer Studio updates" href="feed.xml">
      <link rel="search" type="application/json" title="Micro Offer Studio search index" href="search-index.json">
      <title>#{h(title)}</title>
      <style>
        :root{--ink:#17202a;--muted:#5d6875;--line:#d9dfeb;--panel:#f6f8fb;--accent:#075da8;--green:#17643a;--gold:#8a5a00}
        *{box-sizing:border-box}body{margin:0;color:var(--ink);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.45;background:#fff}main{width:min(1180px,calc(100% - 32px));margin:0 auto;padding:28px 0 48px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:20px}h1{margin:0 0 8px;font-size:clamp(1.8rem,4vw,2.75rem);letter-spacing:0}h2{margin:24px 0 10px;font-size:1.25rem;letter-spacing:0}h3{margin:0 0 6px;font-size:1.05rem;letter-spacing:0}p{margin:0 0 10px}a{color:var(--accent)}.muted{color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.card,.notice,.panel{border:1px solid var(--line);border-radius:8px;background:#fff;padding:12px;min-width:0;overflow-wrap:anywhere}.card{display:grid;grid-template-columns:180px 1fr;gap:14px}.card.product{border-left:6px solid var(--green)}.card.service{border-left:6px solid var(--accent)}img,.placeholder{width:100%;aspect-ratio:16/10;object-fit:cover;border:1px solid var(--line);border-radius:6px;background:var(--panel)}.placeholder{display:grid;place-items:center;color:var(--muted);font-weight:700;text-transform:uppercase}.eyebrow{display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.04em}.buttons{display:flex;gap:8px;flex-wrap:wrap}.buttons a{display:inline-block;border:1px solid var(--line);border-radius:8px;padding:8px 10px;background:#fff;text-decoration:none;font-weight:700}.notice{border-left:6px solid var(--gold);background:#fffaf0}.split{display:grid;grid-template-columns:minmax(0,1fr) 320px;gap:16px}.fact{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:10px;margin:0 0 10px}.fact span{display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.04em}.preview-frame{width:100%;min-height:520px;border:1px solid var(--line);border-radius:8px;background:#fff}ul{padding-left:20px}li{margin:6px 0}code{white-space:normal;overflow-wrap:anywhere}
        table{width:100%;border-collapse:collapse;border:1px solid var(--line);background:#fff}th,td{padding:9px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top;font-size:.9rem;overflow-wrap:anywhere}th{background:var(--panel);color:var(--muted);font-size:.74rem;text-transform:uppercase;letter-spacing:.04em}.copybox{white-space:pre-wrap;border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:12px;margin:10px 0;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.9rem}label{display:block;font-weight:700;margin:10px 0 4px}input,select,textarea{width:100%;min-height:40px;border:1px solid var(--line);border-radius:8px;padding:8px 10px;font:inherit;background:#fff}textarea{min-height:100px}.total{font-size:1.4rem;font-weight:800}
        @media(max-width:900px){.grid,.card,.split{grid-template-columns:1fr}.buttons{display:grid}.buttons a{width:100%}table,thead,tbody,tr,th,td{display:block}thead{display:none}tr{border-bottom:1px solid var(--line);padding:8px 0}td{border-bottom:0;padding:6px 9px}td::before{content:attr(data-label);display:block;color:var(--muted);font-size:.72rem;font-weight:700;text-transform:uppercase}}
      </style>
      #{head_extra}
    </head>
    <body>
      <main>#{body}</main>
    </body>
    </html>
  HTML
end

def share_meta(title:, description:, url:)
  <<~HTML
    <link rel="canonical" href="#{h(url)}">
    <meta property="og:url" content="#{h(url)}">
    <meta property="og:site_name" content="Micro Offer Studio">
    <meta name="twitter:card" content="summary">
    <meta name="twitter:title" content="#{h(title)}">
    <meta name="twitter:description" content="#{h(description)}">
    <meta name="robots" content="index,follow">
  HTML
end

READY_TO_BUY_SLUGS = %w[
  static-demo-site-customization
  local-seo-gbp-audit
  niche-quote-estimator
  website-audit-microservice
  ai-workflow-tracker-sprint
  technical-docs-cleanup
  resume-linkedin-interview-pack
  pdf-table-extraction
  client-intake-and-sop-package
  data-cleanup-sprint
  automation-blueprint
  content-repurposing-sprint
].freeze

GITHUB_LEAD_TITLE_BY_OFFER_SLUG = {
  "static-demo-site-customization" => "Static Service Site Starter",
  "local-seo-gbp-audit" => "Local SEO GBP Audit Starter",
  "niche-quote-estimator" => "Niche Quote Estimator Starter",
  "website-audit-microservice" => "Website Audit Microservice Starter",
  "ai-workflow-tracker-sprint" => "Workflow Tracker Dashboard Starter",
  "technical-docs-cleanup" => "Technical Docs Cleanup Starter",
  "resume-linkedin-interview-pack" => "Career Packet Starter",
  "pdf-table-extraction" => "PDF Table Extraction Starter",
  "client-intake-and-sop-package" => "Client Intake SOP Starter",
  "data-cleanup-sprint" => "Data Cleanup Sprint Starter",
  "automation-blueprint" => "Automation Blueprint Starter",
  "content-repurposing-sprint" => "Content Repurposing Sprint Starter"
}.freeze

def github_lead_for_offer(offer)
  lead_title = GITHUB_LEAD_TITLE_BY_OFFER_SLUG[offer[:slug]]
  return {} unless lead_title

  GITHUB_LEADS.find { |row| row["title"] == lead_title } || {}
end

def ready_to_buy_path(offer)
  "ready-to-buy-#{offer[:slug]}.html"
end

def ready_to_buy_inquiry_url(offer, lead)
  landing = lead["standalone_index_url"].to_s
  return "#{landing}inquiry.html" unless landing.empty?

  prefilled_issue_url(offer, title_prefix: "Ready to buy")
end

def ready_to_buy_links(offer)
  lead = github_lead_for_offer(offer)
  landing = lead["standalone_index_url"].to_s
  links = [
    ["Start prefilled inquiry", ready_to_buy_inquiry_url(offer, lead)],
    ["Offer page", "#{offer[:slug]}.html"],
    ["Standalone landing", landing],
    ["Live preview", lead["pages_url"].to_s.empty? ? offer[:preview_public] : lead["pages_url"]],
    ["Repo order board", lead["repo_order_issue_url"]],
    ["GitHub repo", lead["repo_url"]]
  ].reject { |_, url| url.to_s.empty? }

  links.map { |label, url| %(<a href="#{h(url)}">#{h(label)}</a>) }.join
end

def ready_to_buy_card(offer)
  lead = github_lead_for_offer(offer)
  proof = lead["proof_rule"].to_s.empty? ? "External paid order, accepted scope, delivery proof, and posted/released/payable payment proof." : lead["proof_rule"]
  <<~HTML
    <article class="panel">
      <span class="eyebrow">Ready-to-buy route / #{h(offer[:price])}</span>
      <h2><a href="#{h(ready_to_buy_path(offer))}">#{h(offer[:title])}</a></h2>
      <p>#{h(offer[:description])}</p>
      <p><strong>Closest $100 path:</strong> #{h(offer[:first_100])}</p>
      <p><strong>Proof rule:</strong> #{h(proof)}</p>
      <p class="buttons">#{ready_to_buy_links(offer)}</p>
    </article>
  HTML
end

def ready_to_buy_share_rows(offers)
  offers.map do |offer|
    url = absolute_url(ready_to_buy_path(offer))
    snippet = "Ready-to-scope #{offer[:title]} at #{offer[:price]}: #{offer[:description]} Start from the buyer route: #{url}"
    <<~HTML
      <tr>
        <td data-label="Route"><a href="#{h(ready_to_buy_path(offer))}">#{h(offer[:title])}</a></td>
        <td data-label="Price">#{h(offer[:price])}</td>
        <td data-label="Ready URL"><a href="#{h(url)}">#{h(url)}</a></td>
        <td data-label="Snippet"><div class="copybox">#{h(snippet)}</div></td>
      </tr>
    HTML
  end.join
end

def buyer_intent_rows(offers)
  intent_by_slug = {
    "static-demo-site-customization" => ["I need a simple service website or landing page", "Business name, service area, approved contact link, service list, proof/testimonials if available"],
    "local-seo-gbp-audit" => ["My local business profile or citations need a quick audit", "Public business profile URL, target service area, canonical phone/site/hours"],
    "website-audit-microservice" => ["My website is not converting or has obvious UX/content issues", "Public website URL, target audience, primary conversion goal"],
    "ai-workflow-tracker-sprint" => ["I need a lightweight tracker/dashboard for leads, interviews, grants, or work", "CSV columns, workflow stages, sample non-sensitive rows"],
    "niche-quote-estimator" => ["I need a browser quote estimator for a simple service", "Pricing variables, minimum price, add-ons, exclusions"],
    "technical-docs-cleanup" => ["My README, quickstart, SOP, or docs need cleanup", "Public repo/docs URL or authorized text, target reader, broken sections"],
    "pdf-table-extraction" => ["I need tables extracted from PDFs/screenshots into CSV", "Authorized files, target columns, output format"],
    "client-intake-and-sop-package" => ["I need intake questions, SOP, and delivery checklist", "Workflow steps, required client fields, delivery/status rules"],
    "data-cleanup-sprint" => ["I need a CSV/spreadsheet cleaned and validated", "Authorized CSV/spreadsheet, cleanup rules, desired output"],
    "automation-blueprint" => ["I need an automation plan before building in Zapier/Make/scripts", "Trigger, source/destination apps, fields, failure cases"],
    "content-repurposing-sprint" => ["I need one source asset turned into newsletter/social/captions", "Authorized source asset, audience, channels, tone constraints"],
    "resume-linkedin-interview-pack" => ["I need truthful career materials polished", "Accurate work history, target role, achievements, constraints"]
  }

  offers.map do |offer|
    intent, safe_inputs = intent_by_slug[offer[:slug]]
    next unless intent

    lead = github_lead_for_offer(offer)
    {
      slug: offer[:slug],
      intent: intent,
      offer: offer[:title],
      price: offer[:price],
      safe_inputs: safe_inputs,
      ready_url: absolute_url(ready_to_buy_path(offer)),
      inquiry_url: ready_to_buy_inquiry_url(offer, lead),
      proof_rule: lead["proof_rule"].to_s.empty? ? "External payment and delivery proof required." : lead["proof_rule"]
    }
  end.compact
end

def buyer_intent_table(rows)
  rows.map do |row|
    <<~HTML
      <tr>
        <td data-label="Buyer problem">#{h(row[:intent])}</td>
        <td data-label="Best route"><a href="#{h(row[:ready_url])}">#{h(row[:offer])}</a><br><span class="muted">#{h(row[:price])}</span></td>
        <td data-label="Safe inputs">#{h(row[:safe_inputs])}</td>
        <td data-label="Start"><a href="#{h(row[:inquiry_url])}">Prefilled inquiry</a></td>
        <td data-label="Proof">#{h(row[:proof_rule])}</td>
      </tr>
    HTML
  end.join
end

def ready_to_buy_detail(offer)
  lead = github_lead_for_offer(offer)
  proof = lead["proof_rule"].to_s.empty? ? "External paid order, accepted scope, delivery proof, and posted/released/payable payment proof." : lead["proof_rule"]
  preview_url = lead["pages_url"].to_s.empty? ? offer[:preview_public] : lead["pages_url"]
  body = <<~HTML
    <header>
      <p class="buttons"><a href="index.html">Home</a><a href="ready-to-buy.html">Ready-to-buy routes</a><a href="order-now.html">Order now</a><a href="github-leads.html">GitHub leads</a><a href="proof.html">Proof rules</a></p>
      <h1>Ready To Buy: #{h(offer[:title])}</h1>
      <p class="muted">This page removes catalog browsing and routes a buyer straight to a scoped inquiry for a #{h(offer[:price])} #{h(offer[:type])}. It still does not process payment; payment must move through a seller-controlled external route after scope is accepted.</p>
    </header>
    <section class="split">
      <article>
        <section class="notice">
          <h2>Use This When</h2>
          <p>A buyer wants #{h(offer[:description].downcase)} and can provide public or authorized non-sensitive inputs for scoping.</p>
        </section>
        <section class="panel">
          <h2>Buyer Steps</h2>
          <ol>
            <li>Open the prefilled inquiry and confirm the requested scope, deadline, delivery preference, and acceptance proof.</li>
            <li>Use only public, synthetic, or authorized input. Do not post credentials, private payment data, tax identifiers, customer files, or regulated private details.</li>
            <li>Wait for seller acceptance of the fixed scope and payment/proof route before expecting paid delivery.</li>
            <li>Pay only through an external seller-controlled checkout, invoice, marketplace order, funded milestone, or payment account.</li>
            <li>Count the work as money only after the payment is posted, released, payable, or cleared.</li>
          </ol>
        </section>
        <section class="panel">
          <h2>Delivery Boundary</h2>
          <p>Prepared public pages and sample previews are not the full paid delivery. Paid custom work or paid bundle transfer starts only after scope and payment are accepted.</p>
          <p><strong>Proof required:</strong> #{h(proof)}</p>
        </section>
      </article>
      <aside>
        <div class="fact"><span>Price</span><strong>#{h(offer[:price])}</strong></div>
        <div class="fact"><span>First $100 path</span><strong>#{h(offer[:first_100])}</strong></div>
        <div class="fact"><span>Prepared state</span><strong>#{h(offer[:zip_name] ? "Local bundle and checksum ready" : "Source folder and public preview ready")}</strong></div>
        <div class="fact"><span>Preview</span><strong>#{preview_url.to_s.empty? ? "No preview URL recorded" : %(<a href="#{h(preview_url)}">Open preview</a>)}</strong></div>
        <p class="buttons">#{ready_to_buy_links(offer)}</p>
      </aside>
    </section>
  HTML
  schema = {
    "@context" => "https://schema.org",
    "@type" => "WebPage",
    "name" => "Ready To Buy: #{offer[:title]}",
    "url" => absolute_url(ready_to_buy_path(offer)),
    "about" => offer_schema(offer),
    "potentialAction" => {
      "@type" => "AskAction",
      "target" => ready_to_buy_inquiry_url(offer, lead),
      "name" => "Start prefilled paid inquiry"
    }
  }
  title = "Ready To Buy #{offer[:title]} - Micro Offer Studio"
  description = "#{offer[:price]} buyer route for #{offer[:title]} with prefilled inquiry, preview, proof rule, and payment boundary."
  head = share_meta(title: title, description: description, url: absolute_url(ready_to_buy_path(offer))) + jsonld_script(schema)
  page_shell(title, body, head)
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

sample_pack = write_sample_pack(OFFERS)
ready_to_buy_offers = READY_TO_BUY_SLUGS.map { |offer_slug| OFFERS.find { |offer| offer[:slug] == offer_slug } }.compact
buyer_intents = buyer_intent_rows(ready_to_buy_offers)
ready_to_buy_schema = {
  "@context" => "https://schema.org",
  "@type" => "CollectionPage",
  "name" => "Ready To Buy Routes",
  "url" => absolute_url("ready-to-buy.html"),
  "description" => "High-intent buyer routes for one-sale service offers that can reach at least $100 before fees and refunds.",
  "hasPart" => ready_to_buy_offers.map { |offer| { "@type" => "WebPage", "name" => offer[:title], "url" => absolute_url(ready_to_buy_path(offer)) } }
}

CSV.open(File.join(DOCS, "buyer-intent-router.csv"), "w", write_headers: true, headers: %w[intent offer price safe_inputs ready_url inquiry_url proof_rule]) do |csv|
  buyer_intents.each do |row|
    csv << [row[:intent], row[:offer], row[:price], row[:safe_inputs], row[:ready_url], row[:inquiry_url], row[:proof_rule]]
  end
end

buyer_router_title = "Buyer Intent Router - Micro Offer Studio"
buyer_router_description = "Map a buyer problem to the closest ready-to-buy service route, safe inputs, prefilled inquiry, and proof rule."
buyer_router_schema = {
  "@context" => "https://schema.org",
  "@type" => "ItemList",
  "name" => "Buyer intent router",
  "url" => absolute_url("buyer-intent-router.html"),
  "itemListElement" => buyer_intents.each_with_index.map do |row, index|
    {
      "@type" => "ListItem",
      "position" => index + 1,
      "name" => row[:intent],
      "url" => row[:ready_url]
    }
  end
}
File.write(File.join(DOCS, "buyer-intent-router.html"), page_shell(buyer_router_title, <<~HTML, share_meta(title: buyer_router_title, description: buyer_router_description, url: absolute_url("buyer-intent-router.html")) + jsonld_script(buyer_router_schema)))
  <header>
    <p class="buttons"><a href="index.html">Home</a><a href="ready-to-buy.html">Ready to buy</a><a href="buyer-intent-router.csv">CSV</a><a href="share-kit.html">Share kit</a><a href="proof.html">Proof rules</a></p>
    <h1>Buyer Intent Router</h1>
    <p class="muted">Choose the buyer problem first, then open the closest ready-to-buy route. This page is for legitimate buyer conversations only; it does not process payment.</p>
  </header>
  <section class="notice"><h2>Money Boundary</h2><p>Routing a buyer to a page or opening an issue is not payment. Count money only after accepted scope, external payment proof, delivery proof, and posted/released/payable payout status exist.</p></section>
  <section><h2>Problem To Paid Route</h2><table><thead><tr><th>Buyer problem</th><th>Best route</th><th>Safe inputs</th><th>Start</th><th>Proof</th></tr></thead><tbody>#{buyer_intent_table(buyer_intents)}</tbody></table></section>
HTML

ready_to_buy_index_title = "Ready To Buy Routes - Micro Offer Studio"
ready_to_buy_index_description = "High-intent buyer routes for one-sale service offers that can reach at least $100 before fees and refunds."
File.write(File.join(DOCS, "ready-to-buy.html"), page_shell(ready_to_buy_index_title, <<~HTML, share_meta(title: ready_to_buy_index_title, description: ready_to_buy_index_description, url: absolute_url("ready-to-buy.html")) + jsonld_script(ready_to_buy_schema)))
  <header>
    <p class="buttons"><a href="index.html">Home</a><a href="buyer-intent-router.html">Buyer intent router</a><a href="order-now.html">Order now</a><a href="github-leads.html">GitHub leads</a><a href="pricing.html">Pricing</a><a href="proof.html">Proof rules</a></p>
    <h1>Ready To Buy Routes</h1>
    <p class="muted">High-intent pages for the closest one-sale paths to $100+. Each route sends a buyer to a prefilled inquiry, preview, order board, and proof rule. These pages still do not process payment.</p>
  </header>
  <section class="notice">
    <h2>Payment Boundary</h2>
    <p>Start here only when a real buyer is ready to scope a paid request. GitHub issues, page views, previews, stars, and downloads count as $0. Count money only after external payment is posted, released, payable, or cleared.</p>
  </section>
  <section class="grid">#{ready_to_buy_offers.map { |offer| ready_to_buy_card(offer) }.join}</section>
HTML

ready_to_buy_offers.each do |offer|
  File.write(File.join(DOCS, ready_to_buy_path(offer)), ready_to_buy_detail(offer))
end

index_body = <<~HTML
  <header>
    <p class="buttons"><a href="first-100-fast-start.html">First $100 Fast Start</a><a href="buyer-intent-router.html">Buyer intent router</a><a href="ready-to-buy.html">Ready to buy</a><a href="close-service-order.html">Close order</a><a href="delivery-acceptance.html">Delivery acceptance</a><a href="buyer-response-playbook.html">Buyer response autopilot</a><a href="products.html">Products</a><a href="services.html">Services</a><a href="pricing.html">Pricing</a><a href="tools.html">Free tools</a><a href="order-now.html">Order now</a><a href="payment-activation">Payment activation</a><a href="github-leads.html">GitHub leads</a><a href="download-followup.html">Download follow-up</a><a href="hot-download-close-local-seo-gbp-audit-starter.html">Hot Local SEO close</a><a href="hot-download-close-pdf-table-extraction-starter.html">Hot PDF close</a><a href="start-order.html">Start order</a><a href="case-studies.html">Case studies</a><a href="samples.html">Samples</a><a href="order-boards.html">Order boards</a><a href="proof-monitor.html">Proof monitor</a><a href="fulfillment.html">Fulfillment</a><a href="proof.html">Proof rules</a><a href="proposals.html">Proposal copy</a><a href="buyer-faq.html">Buyer FAQ</a><a href="share-kit.html">Share kit</a><a href="#request">Request work</a><a href="#{h(ISSUE_BOARD_URL)}">First $100 board</a><a href="source-notes.html">Source notes</a></p>
    <h1>Micro Offer Studio</h1>
    <p class="muted">A public launch page for generated digital products and productized micro-services prepared during the autonomous earning run. Checkout is not connected here; use the inquiry link for a paid request, custom scope, or storefront transfer.</p>
  </header>
  <section class="notice">
    <h2>Money Status</h2>
    <p>Confirmed earned money from this public launch package is $0 until an external buyer, payment, refund, credit, or payout proof exists. The autonomous work completed here is public packaging, discoverability, and inquiry infrastructure.</p>
  </section>
  <section class="notice">
    <h2>Observed Hot Routes</h2>
    <p>Two preview ZIPs have download interest. Downloads still count as $0, but these are the shortest current paths from observed interest to a fixed-scope paid inquiry.</p>
    <p class="buttons"><a href="hot-download-close-local-seo-gbp-audit-starter.html">Local SEO / GBP Audit close room - $175</a><a href="hot-download-close-pdf-table-extraction-starter.html">PDF/Table Extraction close room - $125</a><a href="download-followup.html">Download follow-up evidence</a><a href="proof-monitor.html">Proof monitor</a></p>
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
    <p class="buttons"><a href="buyer-intent-router.html">Choose by buyer problem</a><a href="ready-to-buy.html">Open ready-to-buy routes</a><a href="buyer-response-playbook.html">Buyer response autopilot</a><a href="order-now.html">Open direct order boards</a><a href="start-order.html">Build ready-to-pay issue</a><a href="github-leads.html">Open GitHub lead repos</a><a href="#{h(ISSUE_BOARD_URL)}">Open first $100 request board</a><a href="order-boards.html">Open focused order boards</a><a href="#{h(ISSUE_URL)}">Open paid inquiry issue</a><a href="samples.html">Download samples</a><a href="fulfillment.html">See fulfillment ledger</a><a href="#{h(REPO_URL)}">View GitHub repo</a></p>
  </section>
HTML
site_schema = {
  "@context" => "https://schema.org",
  "@type" => "WebSite",
  "name" => "Micro Offer Studio",
  "url" => SITE_URL,
  "description" => "Public previews, free tools, and paid-inquiry pages for generated digital products and productized micro-services.",
  "potentialAction" => {
    "@type" => "SearchAction",
    "target" => "#{SITE_URL}search-index.json?q={search_term_string}",
    "query-input" => "required name=search_term_string"
  },
  "hasPart" => (SERVICES.first(6) + PRODUCTS.values_at(5, 10, 4, 6)).compact.map do |offer|
    {
      "@type" => offer[:type] == "product" ? "Product" : "Service",
      "name" => offer[:title],
      "url" => absolute_url("#{offer[:slug]}.html"),
      "offers" => {
        "@type" => "Offer",
        "priceCurrency" => "USD",
        "price" => price_amount(offer)
      }
    }
  end
}
File.write(File.join(DOCS, "index.html"), page_shell("Micro Offer Studio", index_body, jsonld_script(site_schema)))

File.write(File.join(DOCS, "products.html"), page_shell("Products - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="services.html">Services</a><a href="fulfillment.html">Fulfillment</a><a href="source-notes.html">Source notes</a></p><h1>Digital Products</h1><p class="muted">Preview-only public listings. Full ZIP bundles remain local until a seller checkout or paid transfer is configured.</p></header>
  <section class="grid">#{PRODUCTS.map { |offer| card_html(offer) }.join}</section>
HTML

File.write(File.join(DOCS, "services.html"), page_shell("Services - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="ready-to-buy.html">Ready to buy</a><a href="products.html">Products</a><a href="fulfillment.html">Fulfillment</a><a href="source-notes.html">Source notes</a></p><h1>Productized Services</h1><p class="muted">Fixed-scope offers that can clear $100 with one accepted order. Buyer authorization and payment proof are still required.</p></header>
  <section class="grid">#{SERVICES.map { |offer| card_html(offer) }.join}</section>
HTML

File.write(File.join(DOCS, "pricing.html"), page_shell("Pricing - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="products.html">Products</a><a href="services.html">Services</a><a href="fulfillment.html">Fulfillment</a></p><h1>Pricing</h1><p class="muted">Every row includes a concrete path to $100 and an inquiry link. These are suggested fixed prices; final work still requires accepted scope and external payment proof.</p></header>
  <section><table><thead><tr><th>Offer</th><th>Type</th><th>Price</th><th>Path to $100</th><th>Ready state</th><th>Inquiry</th></tr></thead><tbody>#{pricing_rows(OFFERS)}</tbody></table></section>
HTML

File.write(File.join(DOCS, "case-studies.html"), page_shell("Case Studies - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="pricing.html">Pricing</a><a href="fulfillment.html">Fulfillment</a><a href="proof.html">Proof rules</a></p><h1>Case Studies And Previews</h1><p class="muted">Selected public previews and sample outputs from the prepared work. These demonstrate scope and quality without exposing private buyer files or full paid ZIP bundles.</p></header>
  <section class="grid">#{case_study_cards(OFFERS)}</section>
HTML

File.write(File.join(DOCS, "samples.html"), page_shell("Samples - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="pricing.html">Pricing</a><a href="case-studies.html">Case studies</a><a href="#{h(ISSUE_BOARD_URL)}">First $100 board</a></p><h1>Samples</h1><p class="muted">Free sample files that demonstrate format and proof discipline without giving away full paid bundles.</p></header>
  <section class="notice"><h2>Sample boundary</h2><p>The sample ZIP is public and free. It is not a paid product bundle and is not proof of earnings. Full bundles remain local until accepted scope and payment/proof exist.</p></section>
  <section class="panel"><h2>Download</h2><p><strong>Sample ZIP:</strong> <a href="micro-offer-studio-sample-pack.zip">micro-offer-studio-sample-pack.zip</a></p><p><strong>Size:</strong> #{sample_pack[:bytes]} bytes</p><p><strong>SHA-256:</strong> <code>#{h(sample_pack[:sha256])}</code></p><p><strong>Files:</strong> #{h(sample_pack[:files].join(", "))}</p></section>
  <section class="grid">
    <article class="panel"><h2>What it proves</h2><p>The sample shows offer table format, buyer brief fields, and proof rules. It helps a buyer decide whether to open a paid inquiry.</p></article>
    <article class="panel"><h2>What it does not include</h2><p>No full paid product ZIP, no private buyer data, no credentials, no payment setup, and no claim that money has been earned.</p></article>
  </section>
HTML

if GITHUB_LEADS.any?
  CSV.open(File.join(DOCS, "github_lead_repos.csv"), "w", write_headers: true, headers: GITHUB_LEADS.first.keys) do |csv|
    GITHUB_LEADS.each { |row| csv << row.values_at(*GITHUB_LEADS.first.keys) }
  end
  leads_schema = {
    "@context" => "https://schema.org",
    "@type" => "CollectionPage",
    "name" => "GitHub lead repositories",
    "url" => absolute_url("github-leads.html"),
    "description" => "Standalone public GitHub lead repositories and live previews for the strongest Micro Offer Studio conversion paths.",
    "hasPart" => GITHUB_LEADS.map do |row|
      {
        "@type" => "WebPage",
        "name" => row["title"],
        "url" => row["repo_url"],
        "about" => row["first_100_path"]
      }
    end
  }
  File.write(File.join(DOCS, "github-leads.html"), page_shell("GitHub Leads - Micro Offer Studio", <<~HTML, jsonld_script(leads_schema)))
    <header><p class="buttons"><a href="index.html">Home</a><a href="pricing.html">Pricing</a><a href="tools.html">Free tools</a><a href="order-boards.html">Order boards</a><a href="proof.html">Proof rules</a><a href="github_lead_repos.csv">CSV</a></p><h1>GitHub Lead Repositories</h1><p class="muted">Standalone public repositories, Pages previews, release ZIPs, and paid-inquiry issue templates for the strongest current paths to $100. These are discovery and conversion surfaces, not payment proof.</p></header>
    <section class="notice"><h2>Money boundary</h2><p>GitHub stars, forks, release downloads, Pages views, and issue drafts count as $0. Count money only after a real buyer accepts scope or transfer terms and external payment is posted, released, payable, or cleared.</p></section>
    <section><h2>Lead repo table</h2><table><thead><tr><th>Lead repo</th><th>Price</th><th>Path to $100</th><th>Preview</th><th>Conversion</th><th>Release</th><th>Proof rule</th></tr></thead><tbody>#{github_lead_rows(GITHUB_LEADS)}</tbody></table></section>
    <section class="grid">
      <article class="panel"><h2>Fastest service lead</h2><p>The $200 Static Service Site Starter and $150 Workflow Tracker Dashboard Starter can each clear $100 with one externally paid order.</p></article>
      <article class="panel"><h2>Fastest product lead</h2><p>The $29 Browser Extension Template Preview needs four paid transfers to gross at least $100 before fees or refunds.</p></article>
    </section>
  HTML
  File.write(File.join(DOCS, "order-now.html"), page_shell("Order Now - Micro Offer Studio", <<~HTML))
    <header><p class="buttons"><a href="index.html">Home</a><a href="github-leads.html">All GitHub leads</a><a href="pricing.html">Pricing</a><a href="proof.html">Proof rules</a><a href="github_lead_repos.csv">CSV</a></p><h1>Order Now</h1><p class="muted">Direct repo-level order boards for the closest one-sale paths to $100+. These public issue threads are intake only; they do not process payment.</p></header>
    <section class="notice"><h2>Payment boundary</h2><p>Commenting on an order board is not payment. Paid work or paid bundle transfer starts only after scope is accepted and payment is made through a seller-controlled external route. Confirmed money remains $0 until payment is posted, released, payable, or cleared.</p></section>
    <section><h2>Direct Order Boards</h2><table><thead><tr><th>Offer</th><th>Price</th><th>Buyer action</th><th>Preview</th><th>Proof</th></tr></thead><tbody>#{direct_order_rows(GITHUB_LEADS)}</tbody></table></section>
  HTML
else
  File.write(File.join(DOCS, "github-leads.html"), page_shell("GitHub Leads - Micro Offer Studio", <<~HTML))
    <header><p class="buttons"><a href="index.html">Home</a><a href="pricing.html">Pricing</a></p><h1>GitHub Lead Repositories</h1><p class="muted">No standalone GitHub lead repositories have been published yet.</p></header>
  HTML
  File.write(File.join(DOCS, "order-now.html"), page_shell("Order Now - Micro Offer Studio", <<~HTML))
    <header><p class="buttons"><a href="index.html">Home</a><a href="pricing.html">Pricing</a></p><h1>Order Now</h1><p class="muted">No direct repo order boards have been published yet.</p></header>
  HTML
end

data_cleanup_offer = OFFERS.find { |offer| offer[:slug] == "data-cleanup-sprint" }
website_audit_offer = OFFERS.find { |offer| offer[:slug] == "website-audit-microservice" }
automation_offer = OFFERS.find { |offer| offer[:slug] == "automation-blueprint" }
ai_workflow_offer = OFFERS.find { |offer| offer[:slug] == "ai-workflow-tracker-sprint" }
static_demo_offer = OFFERS.find { |offer| offer[:slug] == "static-demo-site-customization" }
niche_estimator_offer = OFFERS.find { |offer| offer[:slug] == "niche-quote-estimator" }
local_seo_offer = OFFERS.find { |offer| offer[:slug] == "local-seo-gbp-audit" }
client_intake_offer = OFFERS.find { |offer| offer[:slug] == "client-intake-and-sop-package" }
career_offer = OFFERS.find { |offer| offer[:slug] == "resume-linkedin-interview-pack" }
content_repurposing_offer = OFFERS.find { |offer| offer[:slug] == "content-repurposing-sprint" }
technical_docs_offer = OFFERS.find { |offer| offer[:slug] == "technical-docs-cleanup" }
pdf_extraction_offer = OFFERS.find { |offer| offer[:slug] == "pdf-table-extraction" }
invoice_tracker_offer = OFFERS.find { |offer| offer[:slug] == "invoice-and-expense-tracker-template" }
prompt_workflow_offer = OFFERS.find { |offer| offer[:slug] == "prompt-workflow-pack" }
sales_enablement_offer = OFFERS.find { |offer| offer[:slug] == "sales-enablement-kit" }
resale_listing_offer = OFFERS.find { |offer| offer[:slug] == "resale-listing-and-price-research-pack" }
translation_localization_offer = OFFERS.find { |offer| offer[:slug] == "translation-and-localization-draft-pack" }
subscription_audit_offer = OFFERS.find { |offer| offer[:slug] == "subscription-audit-and-savings-prep-pack" }

tool_rows = [
  {
    slug: "csv-cleaner-lite",
    title: "CSV Cleaner Lite",
    service: data_cleanup_offer[:title],
    price: data_cleanup_offer[:price],
    path: "csv-cleaner-lite.html",
    paid_path: prefilled_issue_url(data_cleanup_offer),
    proof_rule: "Counts $0 until a buyer requests the full Data Cleanup Sprint and external payment proof exists."
  },
  {
    slug: "website-audit-lite",
    title: "Website Audit Lite",
    service: website_audit_offer[:title],
    price: website_audit_offer[:price],
    path: "website-audit-lite.html",
    paid_path: prefilled_issue_url(website_audit_offer),
    proof_rule: "Counts $0 until a buyer requests the full Website Audit Microservice and external payment proof exists."
  },
  {
    slug: "workflow-blueprint-lite",
    title: "Workflow Blueprint Lite",
    service: automation_offer[:title],
    price: automation_offer[:price],
    path: "workflow-blueprint-lite.html",
    paid_path: prefilled_issue_url(automation_offer),
    proof_rule: "Counts $0 until a buyer requests the full Automation Blueprint and external payment proof exists."
  },
  {
    slug: "ai-workflow-tracker-brief-builder",
    title: "AI Workflow Tracker Brief Builder",
    service: ai_workflow_offer[:title],
    price: ai_workflow_offer[:price],
    path: "ai-workflow-tracker-brief-builder.html",
    paid_path: prefilled_issue_url(ai_workflow_offer),
    proof_rule: "Counts $0 until a buyer requests the AI Workflow Tracker Sprint and external payment proof exists."
  },
  {
    slug: "static-demo-site-brief-builder",
    title: "Static Demo Site Brief Builder",
    service: static_demo_offer[:title],
    price: static_demo_offer[:price],
    path: "static-demo-site-brief-builder.html",
    paid_path: prefilled_issue_url(static_demo_offer),
    proof_rule: "Counts $0 until a buyer requests the Static Demo Site Customization and external payment proof exists."
  },
  {
    slug: "quote-estimator-scope-builder",
    title: "Quote Estimator Scope Builder",
    service: niche_estimator_offer[:title],
    price: niche_estimator_offer[:price],
    path: "quote-estimator-scope-builder.html",
    paid_path: prefilled_issue_url(niche_estimator_offer),
    proof_rule: "Counts $0 until a buyer requests the Niche Quote Estimator and external payment proof exists."
  },
  {
    slug: "local-seo-gbp-brief-builder",
    title: "Local SEO/GBP Brief Builder",
    service: local_seo_offer[:title],
    price: local_seo_offer[:price],
    path: "local-seo-gbp-brief-builder.html",
    paid_path: prefilled_issue_url(local_seo_offer),
    proof_rule: "Counts $0 until a buyer requests the Local SEO / GBP Audit and external payment proof exists."
  },
  {
    slug: "client-intake-sop-builder",
    title: "Client Intake/SOP Builder",
    service: client_intake_offer[:title],
    price: client_intake_offer[:price],
    path: "client-intake-sop-builder.html",
    paid_path: prefilled_issue_url(client_intake_offer),
    proof_rule: "Counts $0 until a buyer requests the Client Intake and SOP Package and external payment proof exists."
  },
  {
    slug: "career-packet-brief-builder",
    title: "Career Packet Brief Builder",
    service: career_offer[:title],
    price: career_offer[:price],
    path: "career-packet-brief-builder.html",
    paid_path: prefilled_issue_url(career_offer),
    proof_rule: "Counts $0 until a buyer requests the Resume / LinkedIn / Interview Pack and external payment proof exists."
  },
  {
    slug: "invoice-expense-snapshot",
    title: "Invoice/Expense Snapshot",
    service: invoice_tracker_offer[:title],
    price: invoice_tracker_offer[:price],
    path: "invoice-expense-snapshot.html",
    paid_path: prefilled_issue_url(invoice_tracker_offer),
    proof_rule: "Counts $0 until a buyer requests the full tracker template or a paid transfer and external payment proof exists."
  },
  {
    slug: "prompt-workflow-brief-builder",
    title: "Prompt Workflow Brief Builder",
    service: prompt_workflow_offer[:title],
    price: prompt_workflow_offer[:price],
    path: "prompt-workflow-brief-builder.html",
    paid_path: prefilled_issue_url(prompt_workflow_offer),
    proof_rule: "Counts $0 until a buyer requests the Prompt Workflow Pack or a $100 custom setup and external payment proof exists."
  },
  {
    slug: "resale-listing-draft-builder",
    title: "Resale Listing Draft Builder",
    service: resale_listing_offer[:title],
    price: resale_listing_offer[:price],
    path: "resale-listing-draft-builder.html",
    paid_path: prefilled_issue_url(resale_listing_offer),
    proof_rule: "Counts $0 until a buyer requests the Resale Listing and Price Research Pack and external payment proof exists."
  },
  {
    slug: "proposal-profile-builder",
    title: "Proposal/Profile Builder",
    service: sales_enablement_offer[:title],
    price: sales_enablement_offer[:price],
    path: "proposal-profile-builder.html",
    paid_path: prefilled_issue_url(sales_enablement_offer),
    proof_rule: "Counts $0 until a buyer requests the Sales Enablement Kit or a $100 customized proposal/profile setup and external payment proof exists."
  },
  {
    slug: "localization-qa-brief-builder",
    title: "Localization QA Brief Builder",
    service: translation_localization_offer[:title],
    price: translation_localization_offer[:price],
    path: "localization-qa-brief-builder.html",
    paid_path: prefilled_issue_url(translation_localization_offer),
    proof_rule: "Counts $0 until a buyer requests the Translation and Localization Draft Pack and external payment proof exists."
  },
  {
    slug: "subscription-savings-calculator",
    title: "Subscription Savings Calculator",
    service: subscription_audit_offer[:title],
    price: subscription_audit_offer[:price],
    path: "subscription-savings-calculator.html",
    paid_path: prefilled_issue_url(subscription_audit_offer),
    proof_rule: "Counts $0 until a buyer requests the Subscription Audit and Savings Prep Pack or account-owner savings are externally verified."
  },
  {
    slug: "content-repurposing-brief-builder",
    title: "Content Repurposing Brief Builder",
    service: content_repurposing_offer[:title],
    price: content_repurposing_offer[:price],
    path: "content-repurposing-brief-builder.html",
    paid_path: prefilled_issue_url(content_repurposing_offer),
    proof_rule: "Counts $0 until a buyer requests the Content Repurposing Sprint and external payment proof exists."
  },
  {
    slug: "technical-docs-audit-brief-builder",
    title: "Technical Docs Audit Brief Builder",
    service: technical_docs_offer[:title],
    price: technical_docs_offer[:price],
    path: "technical-docs-audit-brief-builder.html",
    paid_path: prefilled_issue_url(technical_docs_offer),
    proof_rule: "Counts $0 until a buyer requests the Technical Docs Cleanup sprint and external payment proof exists."
  },
  {
    slug: "pdf-table-intake-builder",
    title: "PDF/Table Intake Builder",
    service: pdf_extraction_offer[:title],
    price: pdf_extraction_offer[:price],
    path: "pdf-table-intake-builder.html",
    paid_path: prefilled_issue_url(pdf_extraction_offer),
    proof_rule: "Counts $0 until a buyer requests the PDF/Table Extraction package and external payment proof exists."
  }
]

existing_product_tool_services = [
  invoice_tracker_offer[:title],
  prompt_workflow_offer[:title],
  sales_enablement_offer[:title]
]
product_preview_tool_offers = PRODUCTS.reject { |offer| existing_product_tool_services.include?(offer[:title]) }
product_preview_tool_rows = product_preview_tool_offers.map do |offer|
  {
    slug: "#{offer[:slug]}-preview-builder",
    title: "#{offer[:title]} Preview Builder",
    service: offer[:title],
    price: offer[:price],
    path: "#{offer[:slug]}-preview-builder.html",
    paid_path: prefilled_issue_url(offer),
    proof_rule: "Counts $0 until a buyer requests the #{offer[:title]} transfer and external payment proof exists."
  }
end
tool_rows.concat(product_preview_tool_rows)

CSV.open(File.join(DOCS, "tool_manifest.csv"), "w", write_headers: true, headers: %w[slug title service price path paid_path proof_rule]) do |csv|
  tool_rows.each do |row|
    csv << row.values_at(:slug, :title, :service, :price, :path, :paid_path, :proof_rule)
  end
end

tool_cards = tool_rows.map do |row|
  <<~HTML
    <article class="panel">
      <h2>#{h(row[:title])}</h2>
      <p>Free browser-only utility that creates a useful preview without uploading private data. The paid path is #{h(row[:service])} at #{h(row[:price])}.</p>
      <p><strong>Proof rule:</strong> #{h(row[:proof_rule])}</p>
      <p class="buttons"><a href="#{h(row[:path])}">Open tool</a><a href="#{h(row[:paid_path])}">Start paid order</a></p>
    </article>
  HTML
end.join

tools_schema = {
  "@context" => "https://schema.org",
  "@type" => "ItemList",
  "name" => "Micro Offer Studio free tools",
  "url" => absolute_url("tools.html"),
  "itemListElement" => tool_rows.map.with_index(1) do |row, idx|
    {
      "@type" => "ListItem",
      "position" => idx,
      "item" => tool_schema(row)
    }
  end
}
File.write(File.join(DOCS, "tools.html"), page_shell("Free Tools - Micro Offer Studio", <<~HTML, jsonld_script(tools_schema)))
  <header><p class="buttons"><a href="index.html">Home</a><a href="start-order.html">Start order</a><a href="tool_manifest.csv">Tool CSV</a><a href="proof.html">Proof rules</a></p><h1>Free Tools</h1><p class="muted">Small browser-only utilities that give buyers a useful preview and a direct path to a paid fixed-scope order. They do not upload files or process payment.</p></header>
  <section class="notice"><h2>Money boundary</h2><p>These tools are public lead magnets. They count as $0 until a real buyer opens a paid inquiry and external payment or payout proof exists.</p></section>
  <section class="grid">#{tool_cards}</section>
HTML

scope_tool_specs = [
  {
    slug: "ai-workflow-tracker-brief-builder",
    title: "AI Workflow Tracker Brief Builder",
    offer: ai_workflow_offer,
    intro: "Turn workflow notes into a scope-ready CSV tracker and dashboard brief for the $150 AI Workflow Tracker Sprint.",
    boundary: "Use only public, synthetic, or buyer-approved workflow notes. Do not paste private customer records, credentials, payment data, regulated records, or files you are not authorized to process.",
    fields: [
      { id: "workflowName", label: "Workflow name", value: "customer interview pipeline" },
      { id: "fields", label: "Required fields", value: "lead name\nstatus\nowner\nnext action\npotential value\nlast contact date" },
      { id: "statuses", label: "Statuses", value: "new\nactive\nblocked\ndone" },
      { id: "sampleRows", label: "Starter rows or examples", value: "3 active interview leads\n2 blocked leads waiting on scheduling\n1 completed call needing notes" },
      { id: "metrics", label: "Dashboard metrics", value: "total items\nactive items\nblocked items\npotential value" },
      { id: "constraints", label: "Constraints and private data to avoid", value: "no CRM login\nno scraping\nno customer email addresses in public samples\nlocal files only" }
    ],
    sections: ["Tracker scope brief", "CSV schema draft", "Dashboard metrics", "Status filter plan", "Starter-row import notes", "Buyer questions", "Delivery checklist"],
    proof_rule: "Count $0 until a buyer requests the AI Workflow Tracker Sprint and external payment proof exists."
  },
  {
    slug: "static-demo-site-brief-builder",
    title: "Static Demo Site Brief Builder",
    offer: static_demo_offer,
    intro: "Turn local-service business facts into a scope-ready one-page site brief for the $200 Static Demo Site Customization.",
    boundary: "Use only buyer-approved business names, services, proof, images, and contact destinations. Do not imply endorsement, invent testimonials, publish a real business page, or use copyrighted assets without permission.",
    fields: [
      { id: "businessType", label: "Business type or niche", value: "home cleaning and organizing" },
      { id: "sections", label: "Page sections", value: "hero\nservices\nprocess\nproof or FAQ\ncontact" },
      { id: "services", label: "Service blocks", value: "standard visit\ndeep reset\nrecurring plan" },
      { id: "cta", label: "CTA and contact route", value: "Request a quote\napproved contact email or form URL needed" },
      { id: "proofAssets", label: "Proof, brand, and asset notes", value: "buyer-owned logo optional\nbuyer-approved photos required before publishing\nno fake reviews" },
      { id: "constraints", label: "Constraints", value: "handoff only unless buyer approves host\nno payment processing\nno legal/medical/financial claims" }
    ],
    sections: ["Demo site customization brief", "Approved fact checklist", "Page section plan", "Service block map", "CTA and contact requirements", "Asset checklist", "Buyer approval gates"],
    proof_rule: "Count $0 until a buyer requests Static Demo Site Customization and external payment proof exists."
  },
  {
    slug: "quote-estimator-scope-builder",
    title: "Quote Estimator Scope Builder",
    offer: niche_estimator_offer,
    intro: "Turn service pricing assumptions into a scope-ready calculator brief for the $150 Niche Quote Estimator.",
    boundary: "Use only buyer-approved pricing assumptions. This is for non-binding estimates only, not legal, medical, tax, financial, insurance, or regulated advice.",
    fields: [
      { id: "serviceType", label: "Service type", value: "home cleaning quote estimator" },
      { id: "inputs", label: "Estimator inputs", value: "rooms\nservice level\npets\ntravel zone" },
      { id: "pricing", label: "Pricing assumptions", value: "$35 per room\n1.35x deep reset multiplier\n$15 pet add-on\n$20 outer zone add-on" },
      { id: "rangeRule", label: "Estimate range rule", value: "show low/high range with 20% buffer\nround to nearest $5" },
      { id: "disclaimer", label: "Disclaimer and approval notes", value: "non-binding estimate\nfinal quote depends on buyer review\nbuyer approves all numbers before publishing" },
      { id: "constraints", label: "Constraints", value: "no payment processing\nno CRM integration\nno regulated estimates\nhandoff-only unless publishing is approved" }
    ],
    sections: ["Quote estimator scope brief", "Input map", "Pricing assumption table", "Estimate logic", "Disclaimer and approvals", "Delivery checklist", "Buyer questions"],
    proof_rule: "Count $0 until a buyer requests the Niche Quote Estimator and external payment proof exists."
  }
]

def write_scope_brief_tool(spec, tool_rows)
  tool_row = tool_rows.find { |row| row[:slug] == spec[:slug] }
  config = {
    title: spec[:title],
    service: spec[:offer][:title],
    price: spec[:offer][:price],
    sections: spec[:sections],
    fields: spec[:fields],
    proofRule: spec[:proof_rule],
    paidPath: prefilled_issue_url(spec[:offer]),
    toolUrl: absolute_url("#{spec[:slug]}.html")
  }
  fields_html = spec[:fields].map do |field|
    %(<label for="#{h(field[:id])}">#{h(field[:label])}</label><textarea id="#{h(field[:id])}">#{h(field[:value])}</textarea>)
  end.join("\n")

  File.write(File.join(DOCS, "#{spec[:slug]}.html"), page_shell("#{spec[:title]} - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(tool_row))))
    <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(spec[:offer]))}">Start #{h(spec[:offer][:price])} paid scope</a></p><h1>#{h(spec[:title])}</h1><p class="muted">#{h(spec[:intro])} Everything runs in the browser; nothing is uploaded or stored by this page.</p></header>
    <section class="notice"><h2>Boundary</h2><p>#{h(spec[:boundary])}</p></section>
    <section class="split">
      <div class="panel">
        <h2>Scope inputs</h2>
        #{fields_html}
        <p class="buttons"><a href="#" class="buildScopeBtn">Build scope brief</a><a href="#" class="downloadScopeBtn">Download brief</a><a href="#{h(prefilled_issue_url(spec[:offer]))}" class="paidScopeBtn">Start paid order</a></p>
        <div class="copybox scopeOutput"></div>
      </div>
      <aside>
        <div class="fact"><span>Paid service</span><strong>#{h(spec[:offer][:title])} - #{h(spec[:offer][:price])}</strong></div>
        <div class="fact"><span>First $100</span><strong>One paid order clears $100.</strong></div>
        <div class="fact"><span>Proof rule</span><strong>#{h(spec[:proof_rule])}</strong></div>
        <div class="fact"><span>Privacy</span><strong>Browser-only; do not paste secrets or private records.</strong></div>
      </aside>
    </section>
    <script>
      const scopeConfig = #{JSON.generate(config)};
      function lines(id){
        return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
      }
      function buildScopeBrief(){
        const values = scopeConfig.fields.map(field => ({ label: field.label, value: document.getElementById(field.id).value.trim(), lines: lines(field.id) }));
        const fieldBlocks = values.map(item => [item.label + ':', ...(item.lines.length ? item.lines.map((line, idx) => (idx + 1) + '. ' + line) : ['[buyer to provide]'])].join('\\n')).join('\\n\\n');
        const brief = [
          scopeConfig.sections[0],
          '',
          'Paid service: ' + scopeConfig.service + ' - ' + scopeConfig.price,
          'Tool source: ' + scopeConfig.toolUrl,
          '',
          'Buyer-provided scope inputs:',
          fieldBlocks,
          '',
          scopeConfig.sections[1] + ':',
          '- Convert the approved inputs into the paid deliverable only after scope and payment are confirmed.',
          '- Keep private buyer files out of public issues and public previews.',
          '',
          scopeConfig.sections[2] + ':',
          '- Use the fields above as the initial acceptance checklist.',
          '- Ask the buyer to mark anything that is missing, sensitive, or not approved for use.',
          '',
          scopeConfig.sections[3] + ':',
          '- Paid work starts only after buyer acceptance, delivery expectations, and payment route are clear.',
          '- Drafts, generated briefs, public issues, and page views count as $0.',
          '',
          'Paid next step:',
          scopeConfig.service + ' (' + scopeConfig.price + ')',
          '',
          'Proof rule: ' + scopeConfig.proofRule
        ].join('\\n');
        document.querySelector('.scopeOutput').textContent = brief;
        const issueBody = [
          '## Ready-to-pay intake',
          '',
          'Offer: ' + scopeConfig.service,
          'Listed price: ' + scopeConfig.price,
          'Tool source: ' + scopeConfig.toolUrl,
          '',
          'Requested quantity or scope:',
          brief,
          '',
          'Payment/proof route:',
          '[buyer to fill]',
          '',
          'Acceptance proof:',
          '[buyer to fill]',
          '',
          'Safety confirmation:',
          'Buyer confirms the inputs are approved for this fixed-scope service and no secrets, payment data, credentials, or unauthorized private files are being posted publicly.'
        ].join('\\n');
        const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: ' + scopeConfig.service, labels: 'paid-inquiry,ready-to-pay', body: issueBody });
        document.querySelector('.paidScopeBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
        return brief;
      }
      document.querySelectorAll('textarea').forEach(el => el.addEventListener('input', buildScopeBrief));
      document.querySelector('.buildScopeBtn').addEventListener('click', event => { event.preventDefault(); buildScopeBrief(); });
      document.querySelector('.downloadScopeBtn').addEventListener('click', event => {
        event.preventDefault();
        const brief = buildScopeBrief();
        const blob = new Blob([brief], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url; a.download = scopeConfig.title.toLowerCase().replace(/[^a-z0-9]+/g, '-') + '.txt'; a.click();
        URL.revokeObjectURL(url);
      });
      buildScopeBrief();
    </script>
  HTML
end

scope_tool_specs.each { |spec| write_scope_brief_tool(spec, tool_rows) }

def write_product_preview_tool(offer, tool_rows)
  tool_row = tool_rows.find { |row| row[:service] == offer[:title] && row[:slug].end_with?("-preview-builder") }
  config = {
    title: tool_row[:title],
    product: offer[:title],
    price: offer[:price],
    first100: offer[:first_100],
    productUrl: absolute_url("#{offer[:slug]}.html"),
    toolUrl: absolute_url(tool_row[:path]),
    paidPath: prefilled_issue_url(offer),
    proofRule: tool_row[:proof_rule],
    artifact: offer[:zip_name] || offer[:source_dir],
    sha256: offer[:zip_sha256].to_s
  }
  File.write(File.join(DOCS, tool_row[:path]), page_shell("#{tool_row[:title]} - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(tool_row))))
    <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h("#{offer[:slug]}.html")}">Product page</a><a href="#{h(prefilled_issue_url(offer))}">Start #{h(offer[:price])} transfer</a></p><h1>#{h(tool_row[:title])}</h1><p class="muted">Create a buyer-ready transfer brief for #{h(offer[:title])}. This free page does not include the paid ZIP, process payment, grant a license, or prove revenue.</p></header>
    <section class="notice"><h2>Product transfer boundary</h2><p>The paid product bundle stays private until accepted scope and external payment proof exist. Do not post secrets, buyer private files, payment details, tax identifiers, or support promises you cannot honor. Page views, generated briefs, and unpaid issues count as $0.</p></section>
    <section class="split">
      <div class="panel">
        <h2>Buyer transfer inputs</h2>
        <label for="buyerUseCase">Buyer use case</label><textarea id="buyerUseCase">I want to evaluate whether this bundle fits my project before requesting the paid transfer.</textarea>
        <label for="wantedAssets">Assets or files the buyer cares about</label><textarea id="wantedAssets">README and setup notes
example files
license/support notes
full paid ZIP after payment proof</textarea>
        <label for="deliveryNeeds">Delivery route and deadline</label><textarea id="deliveryNeeds">private download link or attachment after payment
delivery within 24 hours after confirmed payment
buyer confirms preferred transfer channel</textarea>
        <label for="licenseNotes">License and support expectations</label><textarea id="licenseNotes">single-buyer project use
no resale of the bundle as-is
basic setup clarification only
refund/support terms confirmed before payment</textarea>
        <label for="proofRoute">Payment/proof route</label><textarea id="proofRoute">checkout receipt, invoice paid status, funded milestone, payable balance, or other external payment proof</textarea>
        <p class="buttons"><a href="#" id="buildProductBriefBtn">Build transfer brief</a><a href="#" id="downloadProductBriefBtn">Download brief</a><a href="#{h(prefilled_issue_url(offer))}" id="productOrderBtn">Start paid transfer</a></p>
        <div class="copybox" id="productBriefOutput"></div>
      </div>
      <aside>
        <div class="fact"><span>Paid product</span><strong>#{h(offer[:title])} - #{h(offer[:price])}</strong></div>
        <div class="fact"><span>First $100</span><strong>#{h(offer[:first_100])}</strong></div>
        <div class="fact"><span>Private artifact</span><code>#{h(offer[:zip_name] || offer[:source_dir])}</code></div>
        <div class="fact"><span>SHA-256</span><code>#{h(offer[:zip_sha256] || "N/A")}</code></div>
      </aside>
    </section>
    <script>
      const productConfig = #{JSON.generate(config)};
      function productLines(id){
        return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
      }
      function numbered(lines){
        return lines.length ? lines.map((line, idx) => (idx + 1) + '. ' + line) : ['1. [buyer to provide]'];
      }
      function buildProductBrief(){
        const useCase = productLines('buyerUseCase');
        const assets = productLines('wantedAssets');
        const delivery = productLines('deliveryNeeds');
        const license = productLines('licenseNotes');
        const proof = productLines('proofRoute');
        const brief = [
          'Product Transfer Brief',
          '',
          'Product: ' + productConfig.product,
          'Price: ' + productConfig.price,
          'Product page: ' + productConfig.productUrl,
          'Tool source: ' + productConfig.toolUrl,
          'Private artifact: ' + productConfig.artifact,
          'Artifact SHA-256: ' + (productConfig.sha256 || 'N/A'),
          '',
          'Buyer use case:',
          ...numbered(useCase),
          '',
          'Requested/expected assets:',
          ...numbered(assets),
          '',
          'Delivery checklist:',
          ...numbered(delivery),
          '',
          'License and support notes:',
          ...numbered(license),
          '',
          'Payment/proof route:',
          ...numbered(proof),
          '',
          'Acceptance checklist:',
          '1. Buyer confirms the product and price.',
          '2. Seller confirms payment route and support/refund terms.',
          '3. Full paid bundle transfers only after external payment proof exists.',
          '4. Buyer confirms receipt and the delivered artifact hash/version if needed.',
          '',
          'First $100 path: ' + productConfig.first100,
          'Proof rule: ' + productConfig.proofRule
        ].join('\\n');
        document.getElementById('productBriefOutput').textContent = brief;
        const issueBody = [
          '## Ready-to-pay intake',
          '',
          'Offer: ' + productConfig.product,
          'Listed price: ' + productConfig.price,
          'Tool source: ' + productConfig.toolUrl,
          '',
          'Requested quantity or scope:',
          brief,
          '',
          'Payment/proof route:',
          '[buyer to fill]',
          '',
          'Acceptance proof:',
          '[buyer to fill]',
          '',
          'Safety confirmation:',
          'Buyer understands the full paid bundle is transferred privately only after external payment proof exists. No secrets, payment data, tax identifiers, or unauthorized private files are posted here.'
        ].join('\\n');
        const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: ' + productConfig.product, labels: 'paid-inquiry,ready-to-pay', body: issueBody });
        document.getElementById('productOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
        return brief;
      }
      ['buyerUseCase','wantedAssets','deliveryNeeds','licenseNotes','proofRoute'].forEach(id => document.getElementById(id).addEventListener('input', buildProductBrief));
      document.getElementById('buildProductBriefBtn').addEventListener('click', event => { event.preventDefault(); buildProductBrief(); });
      document.getElementById('downloadProductBriefBtn').addEventListener('click', event => {
        event.preventDefault();
        const brief = buildProductBrief();
        const blob = new Blob([brief], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url; a.download = productConfig.product.toLowerCase().replace(/[^a-z0-9]+/g, '-') + '-transfer-brief.txt'; a.click();
        URL.revokeObjectURL(url);
      });
      buildProductBrief();
    </script>
  HTML
end

product_preview_tool_offers.each { |offer| write_product_preview_tool(offer, tool_rows) }

csv_tool_row = tool_rows.find { |row| row[:slug] == "csv-cleaner-lite" }
File.write(File.join(DOCS, "csv-cleaner-lite.html"), page_shell("CSV Cleaner Lite - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(csv_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(data_cleanup_offer))}">Start $125 cleanup sprint</a></p><h1>CSV Cleaner Lite</h1><p class="muted">Paste a small CSV sample to profile rows, columns, duplicate rows, blank cells, and a trimmed preview. Everything runs in the browser; nothing is uploaded.</p></header>
  <section class="notice"><h2>Private data rule</h2><p>Use public, synthetic, or low-risk snippets only. Do not paste secrets, payment data, medical/legal/financial private details, or files you are not authorized to process.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Input</h2>
      <label for="csvInput">CSV sample</label>
      <textarea id="csvInput">name,email,status
Alice, alice@example.com ,active
Bob,,inactive
Alice, alice@example.com ,active</textarea>
      <p class="buttons"><a href="#" id="analyzeBtn">Analyze CSV</a><a href="#" id="downloadBtn">Download cleaned preview</a><a href="#{h(prefilled_issue_url(data_cleanup_offer))}" id="orderBtn">Start full cleanup sprint</a></p>
      <div class="copybox" id="cleanPreview"></div>
    </div>
    <aside>
      <div class="fact"><span>Rows</span><strong id="rowCount">0</strong></div>
      <div class="fact"><span>Columns</span><strong id="colCount">0</strong></div>
      <div class="fact"><span>Blank cells</span><strong id="blankCount">0</strong></div>
      <div class="fact"><span>Duplicate rows</span><strong id="duplicateCount">0</strong></div>
      <div class="fact"><span>Paid path</span><strong>Data Cleanup Sprint - $125</strong></div>
    </aside>
  </section>
  <script>
    function parseCsv(text){
      const rows = [];
      let row = [], cell = '', quoted = false;
      for(let i = 0; i < text.length; i++){
        const ch = text[i], next = text[i + 1];
        if(ch === '"' && quoted && next === '"'){ cell += '"'; i++; }
        else if(ch === '"'){ quoted = !quoted; }
        else if(ch === ',' && !quoted){ row.push(cell); cell = ''; }
        else if((ch === '\\n' || ch === '\\r') && !quoted){
          if(ch === '\\r' && next === '\\n') i++;
          row.push(cell); rows.push(row); row = []; cell = '';
        } else { cell += ch; }
      }
      row.push(cell); rows.push(row);
      return rows.filter(r => r.some(c => c.trim() !== ''));
    }
    function csvEscape(value){
      const text = String(value ?? '').trim();
      return /[",\\n\\r]/.test(text) ? '"' + text.replace(/"/g, '""') + '"' : text;
    }
    function analyze(){
      const rows = parseCsv(document.getElementById('csvInput').value);
      const headers = rows[0] || [];
      const body = rows.slice(1);
      const normalized = rows.map(r => headers.map((_, i) => (r[i] || '').trim()));
      const seen = new Set();
      let duplicates = 0, blanks = 0;
      normalized.slice(1).forEach(r => {
        blanks += r.filter(c => c === '').length;
        const key = JSON.stringify(r);
        if(seen.has(key)) duplicates++;
        seen.add(key);
      });
      const cleaned = normalized.map(r => r.map(csvEscape).join(',')).join('\\n');
      document.getElementById('rowCount').textContent = String(body.length);
      document.getElementById('colCount').textContent = String(headers.length);
      document.getElementById('blankCount').textContent = String(blanks);
      document.getElementById('duplicateCount').textContent = String(duplicates);
      document.getElementById('cleanPreview').textContent = cleaned;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Data Cleanup Sprint',
        'Listed price: $125',
        'Tool source: #{SITE_URL}csv-cleaner-lite.html',
        'Rows in sample: ' + body.length,
        'Columns in sample: ' + headers.length,
        'Blank cells detected: ' + blanks,
        'Duplicate rows detected: ' + duplicates,
        '',
        'Requested quantity or scope:',
        'Full CSV cleanup sprint based on authorized input.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Cleaned CSV, profile summary, and QA notes accepted by buyer.'
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Data Cleanup Sprint', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('orderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return cleaned;
    }
    document.getElementById('analyzeBtn').addEventListener('click', event => { event.preventDefault(); analyze(); });
    document.getElementById('downloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const cleaned = analyze();
      const blob = new Blob([cleaned], { type: 'text/csv' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'cleaned-preview.csv'; a.click();
      URL.revokeObjectURL(url);
    });
    analyze();
  </script>
HTML

local_seo_tool_row = tool_rows.find { |row| row[:slug] == "local-seo-gbp-brief-builder" }
File.write(File.join(DOCS, "local-seo-gbp-brief-builder.html"), page_shell("Local SEO/GBP Brief Builder - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(local_seo_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(local_seo_offer))}">Start $175 local SEO audit</a></p><h1>Local SEO/GBP Brief Builder</h1><p class="muted">Create a scope-ready public local SEO and Google Business Profile audit brief from buyer-approved business facts. Everything runs in the browser; this page does not log into, claim, edit, scrape private dashboards, or submit changes to any profile.</p></header>
  <section class="notice"><h2>Profile and review boundary</h2><p>Use only public facts or details the business owner is authorized to share. Do not create fake reviews, review incentives, review gating, keyword stuffing, duplicate profiles, paid-ad claims, ranking guarantees, or edits to a Google Business Profile without the verified owner. Do not paste private customer data, login credentials, payment data, tax IDs, or precise non-public owner information.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Business facts</h2>
      <label for="businessName">Business name</label><input id="businessName" value="Example Plumbing Co.">
      <label for="category">Primary category or service</label><input id="category" value="residential plumber">
      <label for="serviceArea">Address or service area</label><input id="serviceArea" value="Austin, TX service area">
      <label for="websiteUrl">Public website or profile URL</label><input id="websiteUrl" value="https://example.com">
      <label for="phoneHours">Phone, hours, and contact notes</label><textarea id="phoneHours">(555) 010-1234
Mon-Fri 8am-6pm
Emergency calls by appointment</textarea>
      <label for="services">Services to verify</label><textarea id="services">water heater repair
drain cleaning
leak detection
fixture installation</textarea>
      <label for="citationRisks">Known citation or listing risks</label><textarea id="citationRisks">old phone number appears on one directory
service area is inconsistent
hours missing on public profile
website footer uses old brand name</textarea>
      <label for="reviewScenario">Review-response scenario</label><textarea id="reviewScenario">recent review mentions slow callback but positive repair quality</textarea>
      <label for="landingPageGaps">Public landing-page gaps</label><textarea id="landingPageGaps">no city/service-area section
no emergency service explanation
weak proof section
unclear quote request CTA</textarea>
      <p class="buttons"><a href="#" id="localSeoBuildBtn">Build audit brief</a><a href="#" id="localSeoDownloadBtn">Download brief</a><a href="#{h(prefilled_issue_url(local_seo_offer))}" id="localSeoOrderBtn">Start paid local SEO audit</a></p>
      <div class="copybox" id="localSeoOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Paid service</span><strong>Local SEO / GBP Audit - $175</strong></div>
      <div class="fact"><span>First $100</span><strong>One paid audit clears $100.</strong></div>
      <div class="fact"><span>Owner-only actions</span><strong>Profile claiming, edits, verification, and review replies require the business owner.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <script>
    function localSeoLines(id){
      return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
    }
    function buildLocalSeoBrief(){
      const businessName = document.getElementById('businessName').value.trim();
      const category = document.getElementById('category').value.trim();
      const serviceArea = document.getElementById('serviceArea').value.trim();
      const websiteUrl = document.getElementById('websiteUrl').value.trim();
      const phoneHours = localSeoLines('phoneHours');
      const services = localSeoLines('services');
      const citationRisks = localSeoLines('citationRisks');
      const reviewScenario = document.getElementById('reviewScenario').value.trim();
      const landingPageGaps = localSeoLines('landingPageGaps');
      const brief = [
        'Local SEO / GBP Audit Brief',
        '',
        'Business: ' + (businessName || '[buyer to provide]'),
        'Primary category/service: ' + (category || '[buyer to provide]'),
        'Address or service area: ' + (serviceArea || '[buyer to provide]'),
        'Public website/profile URL: ' + (websiteUrl || '[buyer to provide public URL]'),
        '',
        'Name, address, phone, hours check:',
        ...(phoneHours.length ? phoneHours.map((item, i) => (i + 1) + '. ' + item + ' - verify against website, profile, and major citations') : ['1. [add public NAP/hours facts]']),
        '',
        'Services/categories to verify:',
        ...(services.length ? services.map((item, i) => (i + 1) + '. ' + item + ' - map to profile category, service description, and landing page copy') : ['1. [add owner-approved services]']),
        '',
        'Citation cleanup queue:',
        ...(citationRisks.length ? citationRisks.map((item, i) => (i + 1) + '. ' + item + ' - document source URL, current value, desired owner-approved value, and owner action needed') : ['1. No known citation risks entered; still check major public directories.']),
        '',
        'Review-response guidance:',
        reviewScenario || '[add public, non-private review scenario]',
        'Draft response rules: thank the reviewer, address the public issue briefly, avoid private details, avoid incentives, avoid arguing, and move sensitive follow-up to an owner-controlled support channel.',
        '',
        'Landing-page improvement queue:',
        ...(landingPageGaps.length ? landingPageGaps.map((item, i) => (i + 1) + '. ' + item + ' - write owner-approved recommendation') : ['1. [add public page gaps]']),
        '',
        'Owner action checklist:',
        '1. Verified owner confirms official business name, address/service area, phone, hours, categories, and services.',
        '2. Owner approves any profile description, service snippets, photo suggestions, and review-response copy.',
        '3. Owner claims, verifies, edits, or submits profile/listing corrections from their own account.',
        '4. No fake reviews, incentives, review gating, duplicate profiles, keyword stuffing, scraping private dashboards, or ranking guarantees.',
        '5. Save paid order, delivered audit, owner acceptance, and payout proof before counting money.',
        '',
        'Paid next step:',
        'Local SEO / GBP Audit ($175): public profile/citation review, NAP and category consistency checklist, citation cleanup tracker, owner-approved update copy, service snippets, landing-page quick wins, and safe review-response templates.',
        '',
        'Proof rule: count $0 until buyer requests the Local SEO / GBP Audit and external payment proof exists.'
      ].join('\\n');
      document.getElementById('localSeoOutput').textContent = brief;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Local SEO / GBP Audit',
        'Listed price: $175',
        'Tool source: #{SITE_URL}local-seo-gbp-brief-builder.html',
        '',
        'Requested quantity or scope:',
        'Public local SEO and Google Business Profile audit using buyer-approved business facts, citation checks, safe review-response guidance, and owner-action checklist.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Audit brief, citation tracker, update-copy suggestions, review-response templates, and owner-action list accepted by buyer.',
        '',
        'Safety confirmation:',
        'Buyer confirms they are the business owner or authorized representative and will not request fake reviews, profile edits without owner approval, private dashboard scraping, keyword stuffing, or ranking guarantees.',
        '',
        'Brief:',
        brief
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Local SEO / GBP Audit', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('localSeoOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return brief;
    }
    ['businessName','category','serviceArea','websiteUrl','phoneHours','services','citationRisks','reviewScenario','landingPageGaps'].forEach(id => document.getElementById(id).addEventListener('input', buildLocalSeoBrief));
    document.getElementById('localSeoBuildBtn').addEventListener('click', event => { event.preventDefault(); buildLocalSeoBrief(); });
    document.getElementById('localSeoDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const brief = buildLocalSeoBrief();
      const blob = new Blob([brief], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'local-seo-gbp-audit-brief.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildLocalSeoBrief();
  </script>
HTML

client_intake_tool_row = tool_rows.find { |row| row[:slug] == "client-intake-sop-builder" }
File.write(File.join(DOCS, "client-intake-sop-builder.html"), page_shell("Client Intake/SOP Builder - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(client_intake_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(client_intake_offer))}">Start $125 intake/SOP package</a></p><h1>Client Intake/SOP Builder</h1><p class="muted">Turn one repeatable service workflow into a scope-ready intake question bank, SOP outline, delivery checklist, and confirmation email draft. Everything runs in the browser; this page does not create forms, store data, connect accounts, or publish anything.</p></header>
  <section class="notice"><h2>Data and compliance boundary</h2><p>Use only public, synthetic, or buyer-approved workflow facts. Do not paste client private data, credentials, payment cards, tax IDs, medical/legal/financial regulated details, confidential contracts, or employee records. The buyer must approve required questions, data retention, consent language, compliance needs, form hosting, and where completed intake records will be stored.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Workflow facts</h2>
      <label for="businessType">Business type</label><input id="businessType" value="small design studio">
      <label for="workflowName">Workflow name</label><input id="workflowName" value="new client website refresh request">
      <label for="trigger">Trigger</label><textarea id="trigger">new prospect asks for a website refresh quote</textarea>
      <label for="requiredInputs">Required intake inputs</label><textarea id="requiredInputs">business name
current website URL
main goal
deadline
budget range
decision maker
brand assets available
approval constraints</textarea>
      <label for="steps">Delivery steps</label><textarea id="steps">review intake
confirm scope and missing facts
build first-page recommendations
send quote or proposal
capture approval
archive final brief</textarea>
      <label for="qualityChecks">Quality checks</label><textarea id="qualityChecks">scope matches request
names, URLs, deadlines, and prices are verified
private information removed from shared docs
owner approval recorded
handoff folder named consistently</textarea>
      <label for="riskRules">Risk, permission, and stop rules</label><textarea id="riskRules">pause if buyer asks for regulated advice
pause if credentials are requested
pause if scope changes after quote
pause if required approval is missing
do not store private files in public links</textarea>
      <label for="confirmationTone">Confirmation email tone</label><input id="confirmationTone" value="clear, concise, professional">
      <p class="buttons"><a href="#" id="sopBuildBtn">Build intake/SOP brief</a><a href="#" id="sopDownloadBtn">Download brief</a><a href="#{h(prefilled_issue_url(client_intake_offer))}" id="sopOrderBtn">Start paid intake/SOP package</a></p>
      <div class="copybox" id="sopOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Paid service</span><strong>Client Intake and SOP Package - $125</strong></div>
      <div class="fact"><span>First $100</span><strong>One paid package clears $100.</strong></div>
      <div class="fact"><span>Owner approval</span><strong>Buyer must approve fields, retention, compliance, and form hosting.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <script>
    function sopLines(id){
      return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
    }
    function buildSopBrief(){
      const businessType = document.getElementById('businessType').value.trim();
      const workflowName = document.getElementById('workflowName').value.trim();
      const trigger = document.getElementById('trigger').value.trim();
      const inputs = sopLines('requiredInputs');
      const steps = sopLines('steps');
      const checks = sopLines('qualityChecks');
      const risks = sopLines('riskRules');
      const tone = document.getElementById('confirmationTone').value.trim();
      const brief = [
        'Client Intake and SOP Brief',
        '',
        'Business type: ' + (businessType || '[buyer to provide]'),
        'Workflow name: ' + (workflowName || '[buyer to provide]'),
        'Trigger: ' + (trigger || '[buyer to provide]'),
        '',
        'Intake question bank:',
        ...(inputs.length ? inputs.map((item, i) => (i + 1) + '. ' + item + ' - required unless buyer marks optional') : ['1. [add required intake input]']),
        '',
        'SOP outline:',
        'Workflow name: ' + (workflowName || '[workflow]'),
        'Trigger: ' + (trigger || '[trigger]'),
        'Inputs: see question bank above.',
        'Steps:',
        ...(steps.length ? steps.map((item, i) => (i + 1) + '. ' + item) : ['1. Confirm intake is complete', '2. Run quality checklist', '3. Send for client approval']),
        '',
        'Delivery checklist:',
        ...(checks.length ? checks.map((item, i) => (i + 1) + '. ' + item) : ['1. Scope matches request', '2. Owner approval recorded']),
        '',
        'Risk and stop rules:',
        ...(risks.length ? risks.map((item, i) => (i + 1) + '. ' + item) : ['1. Pause if authorization or compliance requirements are unclear']),
        '',
        'Client-facing confirmation email draft:',
        'Subject: Intake received for ' + (workflowName || '[workflow]'),
        'Thanks for sending the intake details. I will review the scope, confirm any missing information, and reply with next steps before work starts. Please do not send passwords, payment details, regulated private information, or files you are not authorized to share. Tone target: ' + (tone || 'clear and professional') + '.',
        '',
        'Buyer approval checklist:',
        '1. Required and optional fields approved by buyer.',
        '2. Data retention, consent, storage location, and access rules approved by buyer.',
        '3. Legal, compliance, privacy, and regulated-data requirements identified before form use.',
        '4. Form hosting and notification owner selected by buyer.',
        '5. Scope, delivery deadline, support expectations, and acceptance proof approved before paid work starts.',
        '',
        'Paid next step:',
        'Client Intake and SOP Package ($125): intake question bank, SOP template for one workflow, delivery checklist, status dashboard, and client-facing confirmation email draft.',
        '',
        'Proof rule: count $0 until buyer requests the Client Intake and SOP Package and external payment proof exists.'
      ].join('\\n');
      document.getElementById('sopOutput').textContent = brief;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Client Intake and SOP Package',
        'Listed price: $125',
        'Tool source: #{SITE_URL}client-intake-sop-builder.html',
        '',
        'Requested quantity or scope:',
        'Build a client intake question bank, SOP outline, delivery checklist, status dashboard, and confirmation email draft for one buyer-approved workflow.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Intake questions, SOP, checklist, dashboard, and confirmation email draft accepted by buyer.',
        '',
        'Safety confirmation:',
        'Buyer confirms required fields, retention, privacy/compliance needs, form hosting, and workflow facts are authorized and approved. No credentials, payment cards, tax IDs, regulated private details, or confidential client records will be posted publicly.',
        '',
        'Brief:',
        brief
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Client Intake and SOP Package', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('sopOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return brief;
    }
    ['businessType','workflowName','trigger','requiredInputs','steps','qualityChecks','riskRules','confirmationTone'].forEach(id => document.getElementById(id).addEventListener('input', buildSopBrief));
    document.getElementById('sopBuildBtn').addEventListener('click', event => { event.preventDefault(); buildSopBrief(); });
    document.getElementById('sopDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const brief = buildSopBrief();
      const blob = new Blob([brief], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'client-intake-sop-brief.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildSopBrief();
  </script>
HTML

career_tool_row = tool_rows.find { |row| row[:slug] == "career-packet-brief-builder" }
File.write(File.join(DOCS, "career-packet-brief-builder.html"), page_shell("Career Packet Brief Builder - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(career_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(career_offer))}">Start $125 career packet</a></p><h1>Career Packet Brief Builder</h1><p class="muted">Turn truthful work-history facts into a scope-ready resume, LinkedIn, cover-letter, and interview-prep brief. Everything runs in the browser; this page does not submit applications, contact employers, log into accounts, or store personal data.</p></header>
  <section class="notice"><h2>Truth and privacy boundary</h2><p>Use only facts the client can truthfully verify. Do not fabricate credentials, employers, dates, degrees, certifications, metrics, references, endorsements, work authorization, security clearance, portfolio ownership, or job outcomes. Do not paste sensitive identifiers, full addresses, private references, salary history, protected-class details, medical/legal/financial private information, or job-account credentials. The client must approve every claim and submit any application themselves.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Career facts</h2>
      <label for="targetRole">Target role</label><input id="targetRole" value="operations coordinator">
      <label for="targetIndustry">Target industry</label><input id="targetIndustry" value="health and wellness services">
      <label for="experienceFacts">Verified work history and projects</label><textarea id="experienceFacts">coordinated weekly client scheduling for a 12-person team
maintained spreadsheet tracker for 200+ appointments per month
prepared onboarding checklist for new contractors
supported customer email triage during seasonal campaign</textarea>
      <label for="metrics">Verified metrics or evidence</label><textarea id="metrics">reduced missed appointment follow-ups by 18%
handled 40-60 customer emails per week
kept contractor onboarding checklist current for 8 new hires</textarea>
      <label for="jobPostingKeywords">Target posting keywords</label><textarea id="jobPostingKeywords">scheduling
CRM
client communication
process documentation
cross-functional coordination</textarea>
      <label for="constraints">Constraints and claims to avoid</label><textarea id="constraints">do not claim management title
do not claim Salesforce certification
avoid salary details
client does not want relocation roles</textarea>
      <label for="storyPrompts">Interview stories or situations</label><textarea id="storyPrompts">solved a scheduling conflict between two departments
improved a handoff checklist after repeated missing fields
handled an upset client and escalated correctly</textarea>
      <p class="buttons"><a href="#" id="careerBuildBtn">Build career packet brief</a><a href="#" id="careerDownloadBtn">Download brief</a><a href="#{h(prefilled_issue_url(career_offer))}" id="careerOrderBtn">Start paid career packet</a></p>
      <div class="copybox" id="careerOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Paid service</span><strong>Resume / LinkedIn / Interview Pack - $125</strong></div>
      <div class="fact"><span>First $100</span><strong>One paid career packet clears $100.</strong></div>
      <div class="fact"><span>Client approval</span><strong>Every claim must be truthful and client-approved before use.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <script>
    function careerLines(id){
      return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
    }
    function buildCareerBrief(){
      const targetRole = document.getElementById('targetRole').value.trim();
      const targetIndustry = document.getElementById('targetIndustry').value.trim();
      const facts = careerLines('experienceFacts');
      const metrics = careerLines('metrics');
      const keywords = careerLines('jobPostingKeywords');
      const constraints = careerLines('constraints');
      const stories = careerLines('storyPrompts');
      const primaryKeyword = keywords[0] || 'target role';
      const brief = [
        'Career Packet Brief',
        '',
        'Target role: ' + (targetRole || '[client to provide]'),
        'Target industry: ' + (targetIndustry || '[client to provide]'),
        '',
        'Truth audit:',
        '1. Client must approve every employer, title, date, degree, certification, metric, tool, portfolio item, and claim before use.',
        '2. Missing metrics must stay qualitative; do not invent numbers.',
        '3. Applications, LinkedIn updates, profile messages, and employer contacts are client-only actions.',
        '',
        'Resume bullet map:',
        ...(facts.length ? facts.map((fact, i) => {
          const metric = metrics[i % Math.max(metrics.length, 1)] || 'verified outcome or scope';
          return (i + 1) + '. ' + fact + ' -> Draft bullet: Improved ' + primaryKeyword + ' by ' + metric + ' while supporting ' + (targetRole || 'target-role') + ' responsibilities. Client must verify wording.';
        }) : ['1. [add truthful work-history fact] -> Draft only after client verifies evidence']),
        '',
        'LinkedIn headline/about draft:',
        'Headline: ' + (targetRole || '[target role]') + ' | ' + (primaryKeyword || 'process support') + ' | ' + (targetIndustry || '[target industry]'),
        'About: I help teams stay organized through clear communication, reliable follow-through, and documented processes. Current target: ' + (targetRole || '[target role]') + ' roles in ' + (targetIndustry || '[target industry]') + '. Claims and metrics must be verified by the client before publishing.',
        '',
        'Cover letter outline:',
        '1. Name the target role and why the verified experience fits.',
        '2. Use one evidence-backed accomplishment from the resume bullet map.',
        '3. Connect one target posting keyword to a real project or responsibility.',
        '4. Close with a concise interview request. Client submits only after review.',
        '',
        'Keyword alignment map:',
        ...(keywords.length ? keywords.map((keyword, i) => (i + 1) + '. ' + keyword + ' - map to a truthful resume bullet, LinkedIn phrase, or interview story') : ['1. [add target posting keyword]']),
        '',
        'Interview prep prompts:',
        ...(stories.length ? stories.map((story, i) => (i + 1) + '. Situation: ' + story + ' | Task/Action/Result: client fills with truthful details and verified outcome') : ['1. [add truthful interview story]']),
        '',
        'Claims to avoid:',
        ...(constraints.length ? constraints.map((item, i) => (i + 1) + '. ' + item) : ['1. Do not invent credentials, metrics, employment, or outcomes.']),
        '',
        'Paid next step:',
        'Resume / LinkedIn / Interview Pack ($125): resume structure and bullet rewrite, LinkedIn headline/about draft, one role-targeted cover letter, interview story prep worksheet, and keyword alignment map.',
        '',
        'Proof rule: count $0 until buyer requests the Resume / LinkedIn / Interview Pack and external payment proof exists.'
      ].join('\\n');
      document.getElementById('careerOutput').textContent = brief;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Resume / LinkedIn / Interview Pack',
        'Listed price: $125',
        'Tool source: #{SITE_URL}career-packet-brief-builder.html',
        '',
        'Requested quantity or scope:',
        'Build a truthful resume, LinkedIn, cover-letter, keyword, and interview-prep packet from client-approved work-history facts.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Resume structure/bullets, LinkedIn headline/about draft, cover letter, keyword map, and interview worksheet accepted by buyer.',
        '',
        'Safety confirmation:',
        'Buyer confirms all work-history facts, dates, credentials, metrics, projects, and target role details are truthful and approved. No fake credentials, ghost applications, account login, sensitive identifiers, or employer contact will be requested here.',
        '',
        'Brief:',
        brief
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Resume / LinkedIn / Interview Pack', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('careerOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return brief;
    }
    ['targetRole','targetIndustry','experienceFacts','metrics','jobPostingKeywords','constraints','storyPrompts'].forEach(id => document.getElementById(id).addEventListener('input', buildCareerBrief));
    document.getElementById('careerBuildBtn').addEventListener('click', event => { event.preventDefault(); buildCareerBrief(); });
    document.getElementById('careerDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const brief = buildCareerBrief();
      const blob = new Blob([brief], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'career-packet-brief.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildCareerBrief();
  </script>
HTML

invoice_tool_row = tool_rows.find { |row| row[:slug] == "invoice-expense-snapshot" }
File.write(File.join(DOCS, "invoice-expense-snapshot.html"), page_shell("Invoice/Expense Snapshot - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(invoice_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(invoice_tracker_offer))}">Start $19 tracker transfer</a></p><h1>Invoice/Expense Snapshot</h1><p class="muted">Paste a small invoice/expense CSV to summarize income, expenses, unpaid invoices, and net. Everything runs in the browser; nothing is uploaded.</p></header>
  <section class="notice"><h2>Advice boundary</h2><p>This is a record organizer and product preview, not tax, accounting, legal, or financial advice. Use public, synthetic, or low-risk snippets only; do not paste bank exports, tax identifiers, payment details, or private client data.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Input</h2>
      <p class="muted">Expected columns: <code>date,type,client_or_vendor,description,category,invoice_id,amount_usd,tax_relevant,status,payment_due,payment_received,notes</code>.</p>
      <label for="invoiceCsvInput">Invoice/expense CSV sample</label>
      <textarea id="invoiceCsvInput">date,type,client_or_vendor,description,category,invoice_id,amount_usd,tax_relevant,status,payment_due,payment_received,notes
2026-06-01,income,Acme Studio,Website audit package,services,INV-001,150.00,yes,sent,2026-06-15,,Example income row
2026-06-02,expense,Hosting Provider,Static site hosting,software,,12.00,yes,paid,,2026-06-02,Example expense row
2026-06-04,income,Beta Research,CSV cleanup sprint,services,INV-002,125.00,yes,paid,2026-06-18,2026-06-08,Example paid income
2026-06-05,expense,Marketplace,Platform fees,fees,,8.75,yes,paid,,2026-06-05,Example fee</textarea>
      <p class="buttons"><a href="#" id="invoiceAnalyzeBtn">Build snapshot</a><a href="#" id="invoiceDownloadBtn">Download summary</a><a href="#{h(prefilled_issue_url(invoice_tracker_offer))}" id="invoiceOrderBtn">Start paid tracker request</a></p>
      <div class="copybox" id="invoiceSummary"></div>
    </div>
    <aside>
      <div class="fact"><span>Income</span><strong id="invoiceIncome">$0</strong></div>
      <div class="fact"><span>Expenses</span><strong id="invoiceExpenses">$0</strong></div>
      <div class="fact"><span>Net</span><strong id="invoiceNet">$0</strong></div>
      <div class="fact"><span>Unpaid invoices</span><strong id="invoiceUnpaid">$0</strong></div>
      <div class="fact"><span>Paid path</span><strong>Invoice and Expense Tracker Template - $19</strong></div>
    </aside>
  </section>
  <script>
    function parseInvoiceCsv(text){
      const rows = [];
      let row = [], cell = '', quoted = false;
      for(let i = 0; i < text.length; i++){
        const ch = text[i], next = text[i + 1];
        if(ch === '"' && quoted && next === '"'){ cell += '"'; i++; }
        else if(ch === '"'){ quoted = !quoted; }
        else if(ch === ',' && !quoted){ row.push(cell); cell = ''; }
        else if((ch === '\\n' || ch === '\\r') && !quoted){
          if(ch === '\\r' && next === '\\n') i++;
          row.push(cell); rows.push(row); row = []; cell = '';
        } else { cell += ch; }
      }
      row.push(cell); rows.push(row);
      return rows.filter(r => r.some(c => c.trim() !== ''));
    }
    function asMoney(value){ return '$' + Number(value || 0).toFixed(2); }
    function buildInvoiceSnapshot(){
      const rows = parseInvoiceCsv(document.getElementById('invoiceCsvInput').value);
      const headers = (rows[0] || []).map(h => h.trim());
      const records = rows.slice(1).map(r => Object.fromEntries(headers.map((h, i) => [h, (r[i] || '').trim()])));
      const amount = r => Number(String(r.amount_usd || '0').replace(/[^0-9.-]/g, '')) || 0;
      const income = records.filter(r => r.type === 'income').reduce((sum, r) => sum + amount(r), 0);
      const expenses = records.filter(r => r.type === 'expense').reduce((sum, r) => sum + amount(r), 0);
      const unpaid = records.filter(r => r.type === 'income' && r.status !== 'paid').reduce((sum, r) => sum + amount(r), 0);
      const net = income - expenses;
      const overdueRows = records.filter(r => r.type === 'income' && r.status !== 'paid' && r.payment_due);
      const summary = [
        'Invoice/Expense Snapshot',
        '',
        'Rows reviewed: ' + records.length,
        'Income: ' + asMoney(income),
        'Expenses: ' + asMoney(expenses),
        'Net: ' + asMoney(net),
        'Unpaid invoices: ' + asMoney(unpaid),
        'Open invoice count: ' + records.filter(r => r.type === 'income' && r.status !== 'paid').length,
        'Rows with due dates to review: ' + overdueRows.length,
        '',
        'Suggested paid next step:',
        'Invoice and Expense Tracker Template ($19) for a local CSV tracker, dashboard, listing copy, and support FAQ.',
        '',
        'Proof rule: count $0 until buyer accepts the product transfer or setup scope and external payment proof exists.',
        'Advice boundary: this is not tax, accounting, legal, or financial advice.'
      ].join('\\n');
      document.getElementById('invoiceIncome').textContent = asMoney(income);
      document.getElementById('invoiceExpenses').textContent = asMoney(expenses);
      document.getElementById('invoiceNet').textContent = asMoney(net);
      document.getElementById('invoiceUnpaid').textContent = asMoney(unpaid);
      document.getElementById('invoiceSummary').textContent = summary;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Invoice and Expense Tracker Template',
        'Listed price: $19',
        'Tool source: #{SITE_URL}invoice-expense-snapshot.html',
        '',
        'Requested quantity or scope:',
        'Tracker template transfer or setup based on authorized invoice/expense records.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Template transferred or setup accepted by buyer.',
        '',
        'Snapshot:',
        summary
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Invoice and Expense Tracker Template', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('invoiceOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return summary;
    }
    document.getElementById('invoiceAnalyzeBtn').addEventListener('click', event => { event.preventDefault(); buildInvoiceSnapshot(); });
    document.getElementById('invoiceDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const summary = buildInvoiceSnapshot();
      const blob = new Blob([summary], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'invoice-expense-snapshot.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildInvoiceSnapshot();
  </script>
HTML

prompt_tool_row = tool_rows.find { |row| row[:slug] == "prompt-workflow-brief-builder" }
File.write(File.join(DOCS, "prompt-workflow-brief-builder.html"), page_shell("Prompt Workflow Brief Builder - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(prompt_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(prompt_workflow_offer))}">Start $19 prompt pack transfer</a></p><h1>Prompt Workflow Brief Builder</h1><p class="muted">Draft a safe, buyer-ready prompt workflow brief for a local service business. Everything runs in the browser; nothing is uploaded.</p></header>
  <section class="notice"><h2>Safety boundary</h2><p>Use only public, synthetic, or buyer-approved facts. Do not paste private customer data, emergency instructions, legal/medical/financial advice requests, fake reviews, or prices/policies the business owner has not approved.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Inputs</h2>
      <label for="businessType">Business type</label><input id="businessType" value="local home-service business">
      <label for="workflowType">Workflow</label>
      <select id="workflowType">
        <option value="new lead reply">New lead reply</option>
        <option value="quote follow-up">Quote follow-up</option>
        <option value="public review response">Public review response</option>
        <option value="internal customer-thread summary">Internal customer-thread summary</option>
      </select>
      <label for="knownFacts">Approved facts to use</label><textarea id="knownFacts">Service requested: gutter cleaning
Location: west side of town
Timing: next week preferred
Known constraint: customer asked for a written estimate</textarea>
      <label for="tone">Approved tone</label><input id="tone" value="clear, polite, concise">
      <p class="buttons"><a href="#" id="promptBuildBtn">Build prompt brief</a><a href="#" id="promptDownloadBtn">Download brief</a><a href="#{h(prefilled_issue_url(prompt_workflow_offer))}" id="promptOrderBtn">Start paid prompt pack request</a></p>
      <div class="copybox" id="promptOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Paid product</span><strong>Prompt Workflow Pack - $19</strong></div>
      <div class="fact"><span>Custom setup path</span><strong>$100 setup reaches $100 with one paid order</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <script>
    function buildPromptWorkflow(){
      const businessType = document.getElementById('businessType').value.trim();
      const workflowType = document.getElementById('workflowType').value;
      const knownFacts = document.getElementById('knownFacts').value.trim();
      const tone = document.getElementById('tone').value.trim();
      const brief = [
        'Prompt Workflow Brief',
        '',
        'Business type: ' + businessType,
        'Workflow: ' + workflowType,
        'Approved tone: ' + tone,
        '',
        'Approved facts:',
        knownFacts || '[buyer to provide approved facts]',
        '',
        'Reusable prompt:',
        'You are drafting a ' + workflowType + ' for a ' + businessType + '. Use only the approved facts below. Do not invent prices, policies, availability, claims, private details, or promises. If a required fact is missing, ask a concise clarifying question. Match this tone: ' + tone + '.',
        '',
        'Approved facts to use:',
        knownFacts || '[buyer to provide approved facts]',
        '',
        'Output requirements:',
        '1. Keep the draft concise.',
        '2. Ask for missing scope details when needed.',
        '3. Include one clear next step.',
        '4. Preserve customer privacy.',
        '5. Require business-owner review before sending.',
        '',
        'Suggested paid next step:',
        'Prompt Workflow Pack ($19) for prompt library, usage guide, evaluation checklist, sales page, and support FAQ; or $100 customized setup for one buyer workflow.',
        '',
        'Proof rule: count $0 until buyer accepts the product transfer or custom setup scope and external payment proof exists.'
      ].join('\\n');
      document.getElementById('promptOutput').textContent = brief;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Prompt Workflow Pack',
        'Listed price: $19 product / $100 custom setup',
        'Tool source: #{SITE_URL}prompt-workflow-brief-builder.html',
        '',
        'Requested quantity or scope:',
        'Prompt pack transfer or custom setup based on buyer-approved workflow facts.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Product transferred or custom workflow accepted by buyer.',
        '',
        'Brief:',
        brief
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Prompt Workflow Pack', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('promptOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return brief;
    }
    ['businessType','workflowType','knownFacts','tone'].forEach(id => document.getElementById(id).addEventListener('input', buildPromptWorkflow));
    document.getElementById('workflowType').addEventListener('change', buildPromptWorkflow);
    document.getElementById('promptBuildBtn').addEventListener('click', event => { event.preventDefault(); buildPromptWorkflow(); });
    document.getElementById('promptDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const brief = buildPromptWorkflow();
      const blob = new Blob([brief], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'prompt-workflow-brief.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildPromptWorkflow();
  </script>
HTML

resale_tool_row = tool_rows.find { |row| row[:slug] == "resale-listing-draft-builder" }
File.write(File.join(DOCS, "resale-listing-draft-builder.html"), page_shell("Resale Listing Draft Builder - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(resale_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(resale_listing_offer))}">Start $100 resale listing pack</a></p><h1>Resale Listing Draft Builder</h1><p class="muted">Draft safe listing copy, condition notes, and owner review checks for an item the seller already owns. Everything runs in the browser; nothing is uploaded.</p></header>
  <section class="notice"><h2>Ownership and safety boundary</h2><p>Use only items the seller owns and can legally sell. This tool does not authenticate luxury goods, buy inventory, post to marketplace accounts, negotiate with buyers, handle shipping, or guarantee sale price. Do not include serial numbers, private addresses, payment data, or buyer messages.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Item facts</h2>
      <label for="itemType">Item type</label><input id="itemType" value="desk lamp">
      <label for="brandModel">Brand/model</label><input id="brandModel" value="unknown brand">
      <label for="condition">Condition</label><select id="condition"><option>Used - good</option><option>New/open box</option><option>Used - fair</option><option>For parts or repair</option></select>
      <label for="features">Verified features</label><textarea id="features">18 inches tall
working switch
warm metal finish
standard bulb socket</textarea>
      <label for="defects">Known defects</label><textarea id="defects">small scratch on base</textarea>
      <label for="included">Included accessories</label><input id="included" value="lamp only">
      <label for="comps">Comparable prices or notes</label><textarea id="comps">similar used desk lamps: $35, $45, $50</textarea>
      <p class="buttons"><a href="#" id="resaleBuildBtn">Build listing draft</a><a href="#" id="resaleDownloadBtn">Download draft</a><a href="#{h(prefilled_issue_url(resale_listing_offer))}" id="resaleOrderBtn">Start paid resale pack</a></p>
      <div class="copybox" id="resaleOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Paid service</span><strong>Resale Listing and Price Research Pack - $100</strong></div>
      <div class="fact"><span>First $100</span><strong>One paid pack reaches $100.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <script>
    function lines(id){
      return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
    }
    function extractPrices(text){
      return (text.match(/\\$?\\d+(?:\\.\\d{1,2})?/g) || []).map(v => Number(v.replace(/[^0-9.]/g, ''))).filter(v => Number.isFinite(v) && v > 0);
    }
    function money(n){ return '$' + Number(n || 0).toFixed(2).replace(/\\.00$/, ''); }
    function buildResaleDraft(){
      const itemType = document.getElementById('itemType').value.trim();
      const brandModel = document.getElementById('brandModel').value.trim();
      const condition = document.getElementById('condition').value;
      const features = lines('features');
      const defects = lines('defects');
      const included = document.getElementById('included').value.trim();
      const comps = document.getElementById('comps').value.trim();
      const prices = extractPrices(comps);
      const low = prices.length ? Math.max(1, Math.floor(Math.min(...prices) * 0.85)) : '';
      const high = prices.length ? Math.ceil(Math.max(...prices) * 1.05) : '';
      const title = [brandModel, itemType, condition.replace('Used - ', '').replace('New/', 'New ').replace(' or repair', '')].filter(Boolean).join(' - ');
      const draft = [
        'Resale Listing Draft',
        '',
        'Title:',
        title,
        '',
        'Description:',
        'Selling a ' + condition.toLowerCase() + ' ' + itemType + (brandModel ? ' (' + brandModel + ')' : '') + '. Features verified by the owner: ' + (features.join('; ') || '[add verified features]') + '. Included: ' + (included || '[add included items]') + '.',
        '',
        'Condition notes:',
        defects.length ? defects.map((d, i) => (i + 1) + '. ' + d).join('\\n') : 'No defects listed by owner; verify before posting.',
        '',
        'Comparable-price notes:',
        comps || '[add sold/listed comparable examples]',
        '',
        'Suggested draft price range:',
        prices.length ? money(low) + ' - ' + money(high) + ' before marketplace fees, shipping, refunds, and negotiation.' : 'Not enough comparable prices entered.',
        '',
        'Owner review checklist:',
        '1. Confirm ownership and legal right to sell.',
        '2. Confirm authenticity for brand-sensitive goods.',
        '3. Confirm condition, defects, measurements, accessories, and photos.',
        '4. Review marketplace fees, shipping cost, returns, and local pickup risk.',
        '5. Post only from the owner marketplace account.',
        '6. Save buyer messages, tracking, payment status, and net proceeds separately.',
        '',
        'Proof rule: count $0 until a buyer requests the paid resale listing pack and external payment proof exists.'
      ].join('\\n');
      document.getElementById('resaleOutput').textContent = draft;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Resale Listing and Price Research Pack',
        'Listed price: $100',
        'Tool source: #{SITE_URL}resale-listing-draft-builder.html',
        '',
        'Requested quantity or scope:',
        'Listing drafts and price research for owned items using buyer-approved facts/photos.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Listing drafts, price notes, and posting checklist accepted by buyer.',
        '',
        'Draft:',
        draft
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Resale Listing and Price Research Pack', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('resaleOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return draft;
    }
    ['itemType','brandModel','condition','features','defects','included','comps'].forEach(id => document.getElementById(id).addEventListener('input', buildResaleDraft));
    document.getElementById('condition').addEventListener('change', buildResaleDraft);
    document.getElementById('resaleBuildBtn').addEventListener('click', event => { event.preventDefault(); buildResaleDraft(); });
    document.getElementById('resaleDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const draft = buildResaleDraft();
      const blob = new Blob([draft], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'resale-listing-draft.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildResaleDraft();
  </script>
HTML

proposal_tool_row = tool_rows.find { |row| row[:slug] == "proposal-profile-builder" }
File.write(File.join(DOCS, "proposal-profile-builder.html"), page_shell("Proposal/Profile Builder - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(proposal_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(sales_enablement_offer))}">Start $29 sales kit transfer</a></p><h1>Proposal/Profile Builder</h1><p class="muted">Draft truthful fixed-scope profile copy, a proposal paragraph, and a compliant one-to-one outreach note from buyer-entered facts. Everything runs in the browser; nothing is uploaded or sent.</p></header>
  <section class="notice"><h2>Truth and anti-spam boundary</h2><p>Use only real services, verified samples, approved prices, and public prospect facts. Do not claim credentials, client results, endorsements, availability, or prior relationships that are not true. Do not send bulk spam or contact people where outreach is not allowed.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Seller facts</h2>
      <label for="sellerName">Seller or business name</label><input id="sellerName" value="Micro service seller">
      <label for="serviceName">Fixed-scope service</label><input id="serviceName" value="Website audit sprint">
      <label for="pricePoint">Approved price</label><input id="pricePoint" value="$150">
      <label for="proofAssets">Truthful proof assets</label><textarea id="proofAssets">public sample report
QA checklist
before/after demo file</textarea>
      <label for="targetBuyer">Target buyer</label><input id="targetBuyer" value="local service business owner">
      <label for="publicObservation">Specific public observation</label><textarea id="publicObservation">homepage has no clear pricing or service-area signal</textarea>
      <label for="deliveryScope">Delivery scope</label><textarea id="deliveryScope">review up to 5 public pages and deliver a ranked quick-win report</textarea>
      <p class="buttons"><a href="#" id="proposalBuildBtn">Build sales snippets</a><a href="#" id="proposalDownloadBtn">Download snippets</a><a href="#{h(prefilled_issue_url(sales_enablement_offer))}" id="proposalOrderBtn">Start paid sales kit request</a></p>
      <div class="copybox" id="proposalOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Paid product</span><strong>Sales Enablement Kit - $29</strong></div>
      <div class="fact"><span>Custom setup path</span><strong>$100 setup reaches $100 with one paid order.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <script>
    function cleanLines(id){
      return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
    }
    function buildProposalProfile(){
      const sellerName = document.getElementById('sellerName').value.trim();
      const serviceName = document.getElementById('serviceName').value.trim();
      const pricePoint = document.getElementById('pricePoint').value.trim();
      const proofAssets = cleanLines('proofAssets');
      const targetBuyer = document.getElementById('targetBuyer').value.trim();
      const publicObservation = document.getElementById('publicObservation').value.trim();
      const deliveryScope = document.getElementById('deliveryScope').value.trim();
      const proofText = proofAssets.length ? proofAssets.join('; ') : '[add truthful proof assets]';
      const snippets = [
        'Proposal/Profile Builder Output',
        '',
        'Profile headline:',
        sellerName + ' - fixed-scope ' + serviceName + ' for ' + targetBuyer,
        '',
        'Profile summary:',
        'I provide a fixed-scope ' + serviceName + ' for ' + targetBuyer + '. Scope: ' + deliveryScope + '. Price: ' + pricePoint + '. Proof assets available for review: ' + proofText + '. I do not claim outcomes, credentials, or endorsements that are not verified.',
        '',
        'Proposal paragraph:',
        'Based on the public observation "' + (publicObservation || '[specific public observation]') + '", I can deliver a ' + serviceName + ' with this scope: ' + deliveryScope + '. Fixed price: ' + pricePoint + '. Acceptance proof can be the delivered report, checklist, or agreed handoff file reviewed by the buyer.',
        '',
        'Compliant one-to-one outreach note:',
        'Hi [name], I noticed this public detail: ' + (publicObservation || '[specific public observation]') + '. I offer a fixed-scope ' + serviceName + ' for ' + pricePoint + ' that covers ' + deliveryScope + '. If useful, I can send the exact scope and proof assets before you decide. Thanks, ' + sellerName,
        '',
        'Prospect tracker fields:',
        'company, website, fit_reason, public_contact_source, service_angle, personalization_note, status',
        '',
        'Owner review checklist:',
        '1. Confirm the seller identity and service claims are true.',
        '2. Confirm the price and scope are approved before posting or sending.',
        '3. Personalize only from public facts.',
        '4. Respect opt-outs and site/community rules.',
        '5. Do not send bulk spam or imply prior relationship.',
        '6. Save buyer acceptance and payment proof before counting money.',
        '',
        'Suggested paid next step:',
        'Sales Enablement Kit ($29) for proposal library, outreach sequence, prospect tracker, profile checklist, case study template, and portfolio page; or $100 customized proposal/profile setup.',
        '',
        'Proof rule: count $0 until buyer accepts the product transfer or custom setup scope and external payment proof exists.'
      ].join('\\n');
      document.getElementById('proposalOutput').textContent = snippets;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Sales Enablement Kit',
        'Listed price: $29 product / $100 custom setup',
        'Tool source: #{SITE_URL}proposal-profile-builder.html',
        '',
        'Requested quantity or scope:',
        'Sales kit transfer or custom proposal/profile setup based on buyer-approved facts.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Product transferred or custom snippets accepted by buyer.',
        '',
        'Snippets:',
        snippets
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Sales Enablement Kit', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('proposalOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return snippets;
    }
    ['sellerName','serviceName','pricePoint','proofAssets','targetBuyer','publicObservation','deliveryScope'].forEach(id => document.getElementById(id).addEventListener('input', buildProposalProfile));
    document.getElementById('proposalBuildBtn').addEventListener('click', event => { event.preventDefault(); buildProposalProfile(); });
    document.getElementById('proposalDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const snippets = buildProposalProfile();
      const blob = new Blob([snippets], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'proposal-profile-snippets.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildProposalProfile();
  </script>
HTML

localization_tool_row = tool_rows.find { |row| row[:slug] == "localization-qa-brief-builder" }
File.write(File.join(DOCS, "localization-qa-brief-builder.html"), page_shell("Localization QA Brief Builder - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(localization_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(translation_localization_offer))}">Start $100 localization pack</a></p><h1>Localization QA Brief Builder</h1><p class="muted">Create a review-ready localization intake, glossary starter, risk notes, and QA checklist from buyer-approved source facts. Everything runs in the browser; nothing is uploaded.</p></header>
  <section class="notice"><h2>Language and regulated-content boundary</h2><p>Use only languages the seller can truthfully review or where a qualified reviewer is involved. Do not use this for certified, legal, medical, immigration, safety-critical, or high-stakes content without appropriate professional review. Do not paste private customer data, unreleased product claims, secrets, or content you are not authorized to process.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Localization facts</h2>
      <label for="sourceLanguage">Source language</label><input id="sourceLanguage" value="English">
      <label for="targetLocale">Target language/locale</label><input id="targetLocale" value="Spanish (Mexico)">
      <label for="contentType">Content type</label><input id="contentType" value="landing page copy">
      <label for="wordCount">Approximate source word count</label><input id="wordCount" type="number" min="1" step="1" value="850">
      <label for="audience">Audience and tone</label><textarea id="audience">small-business owners; clear, friendly, direct</textarea>
      <label for="terms">Terms to preserve or review</label><textarea id="terms">brand name
checkout
pickup
money-back guarantee</textarea>
      <label for="localeChoices">Locale choices</label><textarea id="localeChoices">dates: local numeric format
currency: MXN with USD fallback if needed
measurements: metric
formality: usted unless buyer requests informal tone</textarea>
      <label for="riskItems">Risk items</label><textarea id="riskItems">marketing claims need owner approval
support-policy wording must match actual policy
slogans may need transcreation instead of literal translation</textarea>
      <p class="buttons"><a href="#" id="localizationBuildBtn">Build localization brief</a><a href="#" id="localizationDownloadBtn">Download brief</a><a href="#{h(prefilled_issue_url(translation_localization_offer))}" id="localizationOrderBtn">Start paid localization pack</a></p>
      <div class="copybox" id="localizationOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Paid service</span><strong>Translation and Localization Draft Pack - $100</strong></div>
      <div class="fact"><span>First $100</span><strong>One paid pack reaches $100.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <script>
    function localizationLines(id){
      return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
    }
    function buildLocalizationBrief(){
      const sourceLanguage = document.getElementById('sourceLanguage').value.trim();
      const targetLocale = document.getElementById('targetLocale').value.trim();
      const contentType = document.getElementById('contentType').value.trim();
      const wordCount = document.getElementById('wordCount').value.trim();
      const audience = document.getElementById('audience').value.trim();
      const terms = localizationLines('terms');
      const localeChoices = localizationLines('localeChoices');
      const riskItems = localizationLines('riskItems');
      const brief = [
        'Localization QA Brief',
        '',
        'Source language: ' + sourceLanguage,
        'Target locale: ' + targetLocale,
        'Content type: ' + contentType,
        'Approximate source word count: ' + wordCount,
        'Audience and tone: ' + (audience || '[buyer to provide]'),
        '',
        'Glossary starter:',
        ...(terms.length ? terms.map((term, i) => (i + 1) + '. ' + term + ' - translate/review with buyer-approved terminology') : ['1. [add terms to preserve or review]']),
        '',
        'Locale choices to confirm:',
        ...(localeChoices.length ? localeChoices.map((item, i) => (i + 1) + '. ' + item) : ['1. dates', '2. currency', '3. measurements', '4. formality']),
        '',
        'Risk items:',
        ...(riskItems.length ? riskItems.map((item, i) => (i + 1) + '. ' + item) : ['1. product claims must be owner-approved', '2. policy wording must match real policy']),
        '',
        'QA checklist:',
        '1. Names and brands preserved or intentionally localized.',
        '2. Numbers, prices, dates, measurements, and units checked.',
        '3. Tone matches the target audience and buyer-approved formality.',
        '4. Unsupported claims were not added.',
        '5. Formatting, links, CTAs, and placeholders preserved.',
        '6. Qualified reviewer or language owner signs off before publication.',
        '',
        'Suggested paid next step:',
        'Translation and Localization Draft Pack ($100) for up to 1,000 source words, glossary notes, localization notes, draft structure, and QA checklist.',
        '',
        'Proof rule: count $0 until buyer accepts scope and external payment proof exists.'
      ].join('\\n');
      document.getElementById('localizationOutput').textContent = brief;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Translation and Localization Draft Pack',
        'Listed price: $100',
        'Tool source: #{SITE_URL}localization-qa-brief-builder.html',
        '',
        'Requested quantity or scope:',
        'Localization draft pack for buyer-approved source content, glossary, locale choices, and reviewer workflow.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Localization draft, glossary notes, and QA checklist accepted by buyer or reviewer.',
        '',
        'Brief:',
        brief
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Translation and Localization Draft Pack', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('localizationOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return brief;
    }
    ['sourceLanguage','targetLocale','contentType','wordCount','audience','terms','localeChoices','riskItems'].forEach(id => document.getElementById(id).addEventListener('input', buildLocalizationBrief));
    document.getElementById('localizationBuildBtn').addEventListener('click', event => { event.preventDefault(); buildLocalizationBrief(); });
    document.getElementById('localizationDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const brief = buildLocalizationBrief();
      const blob = new Blob([brief], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'localization-qa-brief.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildLocalizationBrief();
  </script>
HTML

subscription_tool_row = tool_rows.find { |row| row[:slug] == "subscription-savings-calculator" }
File.write(File.join(DOCS, "subscription-savings-calculator.html"), page_shell("Subscription Savings Calculator - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(subscription_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(subscription_audit_offer))}">Start $100 audit prep pack</a></p><h1>Subscription Savings Calculator</h1><p class="muted">Estimate potential annualized savings from recurring charges and build a safe review checklist. Everything runs in the browser; nothing is uploaded.</p></header>
  <section class="notice"><h2>Account and advice boundary</h2><p>This is an organizer and service preview, not financial, tax, legal, or account-security advice. Do not paste full bank exports, card numbers, passwords, OTPs, private statements, account IDs, or business-critical secrets. Do not cancel password managers, domains, email, backups, developer accounts, insurance, health services, or business-critical tools without an owner-approved replacement plan.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Recurring-charge rows</h2>
      <p class="muted">CSV columns: <code>vendor,category,monthly_cost_usd,usage,action,estimated_monthly_savings_usd,risk_note</code>.</p>
      <label for="subscriptionCsvInput">Subscription CSV sample</label>
      <textarea id="subscriptionCsvInput">vendor,category,monthly_cost_usd,usage,action,estimated_monthly_savings_usd,risk_note
Example SaaS tool,software,29,unused,cancel,29,verify no team dependency
Example streaming bundle,media,19,low,downgrade,9,check household usage
Example storage plan,cloud,12,active,negotiate,5,confirm backup coverage</textarea>
      <p class="buttons"><a href="#" id="subscriptionAnalyzeBtn">Build savings plan</a><a href="#" id="subscriptionDownloadBtn">Download plan</a><a href="#{h(prefilled_issue_url(subscription_audit_offer))}" id="subscriptionOrderBtn">Start paid audit prep</a></p>
      <div class="copybox" id="subscriptionOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Potential annual savings</span><strong id="potentialSavings">$0</strong></div>
      <div class="fact"><span>Annual recurring spend</span><strong id="annualSpend">$0</strong></div>
      <div class="fact"><span>Rows to review</span><strong id="reviewRows">0</strong></div>
      <div class="fact"><span>Paid service</span><strong>Subscription Audit and Savings Prep Pack - $100</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until payment or verified posted savings proof exists</strong></div>
    </aside>
  </section>
  <script>
    function parseSubscriptionCsv(text){
      const rows = [];
      let row = [], cell = '', quoted = false;
      for(let i = 0; i < text.length; i++){
        const ch = text[i], next = text[i + 1];
        if(ch === '"' && quoted && next === '"'){ cell += '"'; i++; }
        else if(ch === '"'){ quoted = !quoted; }
        else if(ch === ',' && !quoted){ row.push(cell); cell = ''; }
        else if((ch === '\\n' || ch === '\\r') && !quoted){
          if(ch === '\\r' && next === '\\n') i++;
          row.push(cell); rows.push(row); row = []; cell = '';
        } else { cell += ch; }
      }
      row.push(cell); rows.push(row);
      return rows.filter(r => r.some(c => c.trim() !== ''));
    }
    function subscriptionMoney(n){ return '$' + Number(n || 0).toFixed(2).replace(/\\.00$/, ''); }
    function buildSubscriptionPlan(){
      const rows = parseSubscriptionCsv(document.getElementById('subscriptionCsvInput').value);
      const headers = (rows[0] || []).map(h => h.trim());
      const records = rows.slice(1).map(r => Object.fromEntries(headers.map((h, i) => [h, (r[i] || '').trim()])));
      const numberFor = (row, key) => Number(String(row[key] || '0').replace(/[^0-9.-]/g, '')) || 0;
      const annualSpend = records.reduce((sum, row) => sum + numberFor(row, 'monthly_cost_usd') * 12, 0);
      const potential = records.reduce((sum, row) => sum + numberFor(row, 'estimated_monthly_savings_usd') * 12, 0);
      const review = records.filter(row => numberFor(row, 'estimated_monthly_savings_usd') > 0);
      const plan = [
        'Subscription Savings Plan',
        '',
        'Rows reviewed: ' + records.length,
        'Annual recurring spend: ' + subscriptionMoney(annualSpend),
        'Potential annualized savings: ' + subscriptionMoney(potential),
        'Confirmed savings: $0 until provider or billing proof exists.',
        '',
        'Review queue:',
        ...(review.length ? review.map((row, i) => (i + 1) + '. ' + (row.vendor || '[vendor]') + ' - action: ' + (row.action || '[review]') + ' - estimated annual savings: ' + subscriptionMoney(numberFor(row, 'estimated_monthly_savings_usd') * 12) + ' - risk check: ' + (row.risk_note || '[add risk note]')) : ['1. No savings rows entered.']),
        '',
        'Owner-only action checklist:',
        '1. Open the official account or provider dashboard yourself.',
        '2. Confirm owner authority, renewal date, stored data, users, dependencies, and replacement plan.',
        '3. Cancel, downgrade, or negotiate only when it will not break required access or records.',
        '4. Save provider confirmation, next-bill reduction, posted credit, or statement proof.',
        '5. Count only verified posted savings, not estimates.',
        '',
        'Suggested paid next step:',
        'Subscription Audit and Savings Prep Pack ($100) for normalized audit CSV, risk controls, scripts, and proof checklist.',
        '',
        'Proof rule: count $0 until a buyer pays for the prep pack or account-owner savings are externally verified.'
      ].join('\\n');
      document.getElementById('potentialSavings').textContent = subscriptionMoney(potential);
      document.getElementById('annualSpend').textContent = subscriptionMoney(annualSpend);
      document.getElementById('reviewRows').textContent = String(review.length);
      document.getElementById('subscriptionOutput').textContent = plan;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Subscription Audit and Savings Prep Pack',
        'Listed price: $100',
        'Tool source: #{SITE_URL}subscription-savings-calculator.html',
        '',
        'Requested quantity or scope:',
        'Recurring-charge audit prep using buyer-approved low-risk rows, cancellation/downgrade scripts, risk controls, and proof checklist.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Audit prep CSV, scripts, risk notes, and proof checklist accepted by buyer.',
        '',
        'Savings plan:',
        plan
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Subscription Audit and Savings Prep Pack', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('subscriptionOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return plan;
    }
    document.getElementById('subscriptionCsvInput').addEventListener('input', buildSubscriptionPlan);
    document.getElementById('subscriptionAnalyzeBtn').addEventListener('click', event => { event.preventDefault(); buildSubscriptionPlan(); });
    document.getElementById('subscriptionDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const plan = buildSubscriptionPlan();
      const blob = new Blob([plan], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'subscription-savings-plan.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildSubscriptionPlan();
  </script>
HTML

content_tool_row = tool_rows.find { |row| row[:slug] == "content-repurposing-brief-builder" }
File.write(File.join(DOCS, "content-repurposing-brief-builder.html"), page_shell("Content Repurposing Brief Builder - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(content_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(content_repurposing_offer))}">Start $100 repurposing sprint</a></p><h1>Content Repurposing Brief Builder</h1><p class="muted">Turn buyer-approved source facts into a newsletter/post/caption brief for a fixed-scope repurposing sprint. Everything runs in the browser; nothing is uploaded or posted.</p></header>
  <section class="notice"><h2>Publishing and claims boundary</h2><p>Use only source material the buyer owns or is authorized to reuse. Do not invent personal stories, case studies, endorsements, results, statistics, regulated advice, or platform performance claims. This tool does not post to social accounts, send newsletters, use private accounts, or guarantee reach, followers, sales, or engagement.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Source asset facts</h2>
      <label for="sourceAsset">Source asset</label><input id="sourceAsset" value="buyer-approved webinar transcript">
      <label for="audience">Audience</label><input id="audience" value="small business owners">
      <label for="coreIdea">Core idea</label><textarea id="coreIdea">Turn one existing source asset into a week of useful content instead of starting from a blank calendar.</textarea>
      <label for="proofPoints">Approved proof points or examples</label><textarea id="proofPoints">one newsletter issue
five LinkedIn-style posts
ten captions or hooks
publishing checklist</textarea>
      <label for="avoidClaims">Claims to avoid</label><textarea id="avoidClaims">guaranteed reach
guaranteed sales
unapproved customer stories
regulated advice</textarea>
      <label for="cta">Buyer-approved CTA</label><input id="cta" value="Reply if you want this turned into a simple checklist.">
      <label for="channels">Target channels</label><input id="channels" value="newsletter, LinkedIn, short captions">
      <p class="buttons"><a href="#" id="contentBuildBtn">Build repurposing brief</a><a href="#" id="contentDownloadBtn">Download brief</a><a href="#{h(prefilled_issue_url(content_repurposing_offer))}" id="contentOrderBtn">Start paid sprint</a></p>
      <div class="copybox" id="contentOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Paid service</span><strong>Content Repurposing Sprint - $100</strong></div>
      <div class="fact"><span>First $100</span><strong>One paid sprint reaches $100.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <script>
    function contentLines(id){
      return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
    }
    function buildContentBrief(){
      const sourceAsset = document.getElementById('sourceAsset').value.trim();
      const audience = document.getElementById('audience').value.trim();
      const coreIdea = document.getElementById('coreIdea').value.trim();
      const proofPoints = contentLines('proofPoints');
      const avoidClaims = contentLines('avoidClaims');
      const cta = document.getElementById('cta').value.trim();
      const channels = document.getElementById('channels').value.trim();
      const brief = [
        'Content Repurposing Brief',
        '',
        'Source asset: ' + sourceAsset,
        'Audience: ' + audience,
        'Target channels: ' + channels,
        '',
        'Core idea:',
        coreIdea || '[buyer-approved source idea]',
        '',
        'Newsletter angle:',
        'Explain the core idea for ' + (audience || '[audience]') + ' using only buyer-approved source material. Keep claims modest and true.',
        '',
        'Five post angles:',
        '1. Pain point: why starting from a blank content calendar is expensive.',
        '2. How-to: split one source asset into problem, process, example, CTA, and FAQ.',
        '3. Objection: repurposing is not repeating yourself; it is making the idea easier to understand.',
        '4. Offer: turn one approved source asset into newsletter, posts, captions, and review checklist.',
        '5. Checklist: source approved, claims true, CTA current, each post stands alone, context owner reviewed.',
        '',
        'Approved proof points or deliverables:',
        ...(proofPoints.length ? proofPoints.map((item, i) => (i + 1) + '. ' + item) : ['1. [add buyer-approved proof points]']),
        '',
        'Claims to avoid:',
        ...(avoidClaims.length ? avoidClaims.map((item, i) => (i + 1) + '. ' + item) : ['1. [add forbidden claims]']),
        '',
        'Buyer-approved CTA:',
        cta || '[buyer-approved CTA]',
        '',
        'Review checklist:',
        '1. Buyer owns or is authorized to reuse the source asset.',
        '2. No invented personal story, statistic, endorsement, or result.',
        '3. CTA is current and approved.',
        '4. Regulated advice is excluded or professionally reviewed.',
        '5. Account owner reviews before publishing.',
        '',
        'Suggested paid next step:',
        'Content Repurposing Sprint ($100) for one newsletter issue, five post drafts, ten captions/hooks, repurposing map, and publishing checklist.',
        '',
        'Proof rule: count $0 until buyer accepts scope and external payment proof exists.'
      ].join('\\n');
      document.getElementById('contentOutput').textContent = brief;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Content Repurposing Sprint',
        'Listed price: $100',
        'Tool source: #{SITE_URL}content-repurposing-brief-builder.html',
        '',
        'Requested quantity or scope:',
        'Repurposing sprint from buyer-approved source asset into newsletter, posts, captions, map, and checklist.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Newsletter draft, post set, captions/hooks, map, and checklist accepted by buyer.',
        '',
        'Brief:',
        brief
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Content Repurposing Sprint', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('contentOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return brief;
    }
    ['sourceAsset','audience','coreIdea','proofPoints','avoidClaims','cta','channels'].forEach(id => document.getElementById(id).addEventListener('input', buildContentBrief));
    document.getElementById('contentBuildBtn').addEventListener('click', event => { event.preventDefault(); buildContentBrief(); });
    document.getElementById('contentDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const brief = buildContentBrief();
      const blob = new Blob([brief], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'content-repurposing-brief.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildContentBrief();
  </script>
HTML

technical_docs_tool_row = tool_rows.find { |row| row[:slug] == "technical-docs-audit-brief-builder" }
File.write(File.join(DOCS, "technical-docs-audit-brief-builder.html"), page_shell("Technical Docs Audit Brief Builder - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(technical_docs_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(technical_docs_offer))}">Start $150 docs cleanup</a></p><h1>Technical Docs Audit Brief Builder</h1><p class="muted">Draft a scope-ready documentation audit brief from public or buyer-authorized docs. Everything runs in the browser; nothing is uploaded or edited.</p></header>
  <section class="notice"><h2>Documentation boundary</h2><p>Use only public documentation or private docs the buyer is authorized to share. This tool does not access private repos, edit production docs, invent product behavior, verify hidden APIs, or publish changes. Owner review is required before any doc rewrite is treated as final.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Document facts</h2>
      <label for="docType">Document type</label>
      <select id="docType">
        <option>README</option>
        <option>Quickstart</option>
        <option>API docs</option>
        <option>Internal SOP</option>
        <option>Onboarding doc</option>
      </select>
      <label for="docUrl">Public or authorized doc URL/name</label><input id="docUrl" value="https://example.com/docs/quickstart">
      <label for="reader">Target reader</label><input id="reader" value="first-time developer">
      <label for="goal">Reader success outcome</label><textarea id="goal">Install the project locally, configure required environment variables, run tests, and open the dashboard.</textarea>
      <label for="knownGaps">Known gaps or support questions</label><textarea id="knownGaps">missing prerequisites
commands do not mention working directory
no common error section
unclear owner/support path</textarea>
      <label for="constraints">Owner constraints</label><textarea id="constraints">do not invent product behavior
owner must verify environment names
keep one-page quickstart under 1,500 words</textarea>
      <p class="buttons"><a href="#" id="docsBuildBtn">Build docs audit brief</a><a href="#" id="docsDownloadBtn">Download brief</a><a href="#{h(prefilled_issue_url(technical_docs_offer))}" id="docsOrderBtn">Start paid docs cleanup</a></p>
      <div class="copybox" id="docsOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Paid service</span><strong>Technical Docs Cleanup - $150</strong></div>
      <div class="fact"><span>First $100</span><strong>One docs sprint clears $100.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <script>
    function docsLines(id){
      return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
    }
    function buildDocsBrief(){
      const docType = document.getElementById('docType').value;
      const docUrl = document.getElementById('docUrl').value.trim();
      const reader = document.getElementById('reader').value.trim();
      const goal = document.getElementById('goal').value.trim();
      const gaps = docsLines('knownGaps');
      const constraints = docsLines('constraints');
      const brief = [
        'Technical Docs Audit Brief',
        '',
        'Document type: ' + docType,
        'Public or authorized source: ' + (docUrl || '[buyer to provide]'),
        'Target reader: ' + (reader || '[buyer to provide]'),
        '',
        'Reader success outcome:',
        goal || '[buyer-approved success outcome]',
        '',
        'Audit rubric:',
        '1. Audience: reader knows whether this is for developer, admin, operator, or end user.',
        '2. Outcome: first paragraph defines what success looks like.',
        '3. Prerequisites: accounts, tools, versions, permissions, and env vars are listed before commands.',
        '4. Commands: commands are copyable, scoped to a directory, and ordered.',
        '5. Troubleshooting: common errors are mapped to fixes.',
        '6. Ownership: support, update owner, and escalation path are named.',
        '',
        'Known gaps to address:',
        ...(gaps.length ? gaps.map((item, i) => (i + 1) + '. ' + item) : ['1. [add known gaps]']),
        '',
        'Owner constraints:',
        ...(constraints.length ? constraints.map((item, i) => (i + 1) + '. ' + item) : ['1. Owner must verify product behavior before publishing.']),
        '',
        'Proposed paid scope:',
        'Technical Docs Cleanup ($150): audit one public or authorized README, quickstart, API page, or SOP up to 1,500 words; rewrite for first-run success; provide before/after change log and owner-review backlog.',
        '',
        'Proof rule: count $0 until buyer accepts scope and external payment proof exists.'
      ].join('\\n');
      document.getElementById('docsOutput').textContent = brief;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Technical Docs Cleanup',
        'Listed price: $150',
        'Tool source: #{SITE_URL}technical-docs-audit-brief-builder.html',
        '',
        'Requested quantity or scope:',
        'Documentation cleanup sprint for one public or buyer-authorized document up to 1,500 words.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Audited/revised doc draft, change log, and owner-review backlog accepted by buyer.',
        '',
        'Brief:',
        brief
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Technical Docs Cleanup', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('docsOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return brief;
    }
    ['docType','docUrl','reader','goal','knownGaps','constraints'].forEach(id => document.getElementById(id).addEventListener('input', buildDocsBrief));
    document.getElementById('docType').addEventListener('change', buildDocsBrief);
    document.getElementById('docsBuildBtn').addEventListener('click', event => { event.preventDefault(); buildDocsBrief(); });
    document.getElementById('docsDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const brief = buildDocsBrief();
      const blob = new Blob([brief], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'technical-docs-audit-brief.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildDocsBrief();
  </script>
HTML

pdf_tool_row = tool_rows.find { |row| row[:slug] == "pdf-table-intake-builder" }
File.write(File.join(DOCS, "pdf-table-intake-builder.html"), page_shell("PDF/Table Intake Builder - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(pdf_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(pdf_extraction_offer))}">Start $125 extraction package</a></p><h1>PDF/Table Intake Builder</h1><p class="muted">Draft a scope-ready intake, field map, and QA checklist for an authorized PDF, screenshot, or messy table extraction job. Everything runs in the browser; there is no upload and no file processing on this page.</p></header>
  <section class="notice"><h2>Authorization and data boundary</h2><p>Use only public material or files the buyer is authorized to share and process. Do not paste confidential documents, credentials, payment cards, tax identifiers, medical/legal/financial private details, private customer records, copyrighted material without permission, or content with unclear rights. This tool does not guarantee OCR accuracy; owner review is required before delivery is final.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Extraction facts</h2>
      <label for="sourceType">Source type</label>
      <select id="sourceType">
        <option>Authorized PDF</option>
        <option>Public PDF</option>
        <option>Screenshot set</option>
        <option>Messy pasted table</option>
        <option>Image scan with tables</option>
      </select>
      <label for="sourceLabel">Public URL or authorized file description</label><input id="sourceLabel" value="buyer-authorized 8-page price-list PDF">
      <label for="pageCount">Pages or screenshots</label><input id="pageCount" type="number" min="1" max="10" step="1" value="8">
      <label for="tableCount">Expected tables</label><input id="tableCount" type="number" min="1" step="1" value="3">
      <label for="outputFields">Target fields</label><textarea id="outputFields">item_id
item_name
category
unit_price
minimum_order
notes</textarea>
      <label for="cleaningRules">Cleaning and normalization rules</label><textarea id="cleaningRules">trim whitespace
normalize currency to USD
split combined item/name cells when clear
keep original notes column for uncertain values</textarea>
      <label for="qualityRisks">Known quality risks</label><textarea id="qualityRisks">small text in footer
merged header cells
two columns wrap across page break
some prices may be handwritten</textarea>
      <label for="privacyLevel">Data sensitivity</label>
      <select id="privacyLevel">
        <option>Public or low-risk business data</option>
        <option>Buyer-authorized internal data without regulated private details</option>
        <option>Rejected: contains secrets, regulated private data, or unclear rights</option>
      </select>
      <label for="sampleRows">Optional small sample rows or notes</label><textarea id="sampleRows">A-100 | Widget small | Hardware | $12.50 | 10 units
B-200 | Widget large | Hardware | $19.75 | 5 units</textarea>
      <label for="deliverables">Expected deliverables</label><textarea id="deliverables">clean CSV
field map
QA report
summary dashboard</textarea>
      <p class="buttons"><a href="#" id="pdfBuildBtn">Build extraction brief</a><a href="#" id="pdfDownloadBtn">Download brief</a><a href="#{h(prefilled_issue_url(pdf_extraction_offer))}" id="pdfOrderBtn">Start paid extraction package</a></p>
      <div class="copybox" id="pdfOutput"></div>
    </div>
    <aside>
      <div class="fact"><span>Paid service</span><strong>PDF/Table Extraction - $125</strong></div>
      <div class="fact"><span>First $100</span><strong>One paid extraction package clears $100.</strong></div>
      <div class="fact"><span>Scope cap</span><strong>Up to 10 pages or screenshots in the fixed scope.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <script>
    function pdfLines(id){
      return document.getElementById(id).value.split(/\\n|,/).map(s => s.trim()).filter(Boolean);
    }
    function buildPdfBrief(){
      const sourceType = document.getElementById('sourceType').value;
      const sourceLabel = document.getElementById('sourceLabel').value.trim();
      const pageCount = Math.max(1, Number(document.getElementById('pageCount').value || 1));
      const tableCount = Math.max(1, Number(document.getElementById('tableCount').value || 1));
      const fields = pdfLines('outputFields');
      const rules = pdfLines('cleaningRules');
      const risks = pdfLines('qualityRisks');
      const privacyLevel = document.getElementById('privacyLevel').value;
      const sampleRows = document.getElementById('sampleRows').value.trim();
      const deliverables = pdfLines('deliverables');
      const rejected = privacyLevel.startsWith('Rejected');
      const brief = [
        'PDF/Table Extraction Brief',
        '',
        'Source type: ' + sourceType,
        'Source description: ' + (sourceLabel || '[buyer to provide authorized source description]'),
        'Pages or screenshots: ' + pageCount,
        'Expected tables: ' + tableCount,
        'Sensitivity: ' + privacyLevel,
        'Scope status: ' + (pageCount <= 10 && !rejected ? 'Fixed-scope candidate' : 'Needs rescope or rejection before paid work'),
        '',
        'Authorization statement:',
        rejected ? 'Do not proceed: source appears to include secrets, regulated private data, unclear rights, or another rejected category.' : 'Buyer must confirm they own or are authorized to share and process this source before work starts.',
        '',
        'Field map:',
        ...(fields.length ? fields.map((field, i) => (i + 1) + '. ' + field + ' - extract if visible; mark unclear values for review') : ['1. [buyer to provide target fields]']),
        '',
        'Cleaning rules:',
        ...(rules.length ? rules.map((rule, i) => (i + 1) + '. ' + rule) : ['1. Trim whitespace', '2. Preserve original values when ambiguous']),
        '',
        'Quality risks:',
        ...(risks.length ? risks.map((risk, i) => (i + 1) + '. ' + risk) : ['1. No risks listed; still perform manual spot check']),
        '',
        'Sample rows or notes:',
        sampleRows || '[optional buyer-provided low-risk sample rows]',
        '',
        'Deliverables:',
        ...(deliverables.length ? deliverables.map((item, i) => (i + 1) + '. ' + item) : ['1. clean CSV', '2. field map', '3. QA report']),
        '',
        'QA checklist:',
        '1. Confirm source authorization and handling rules before work starts.',
        '2. Count pages, screenshots, tables, and requested fields against scope.',
        '3. Preserve source row order unless buyer requests sorting.',
        '4. Validate required columns, blank counts, duplicate rows, and obvious numeric formats.',
        '5. Mark illegible or ambiguous cells instead of guessing.',
        '6. Compare a sample of extracted rows back to source pages.',
        '7. Deliver CSV, field map, QA notes, and summary dashboard for owner acceptance.',
        '',
        'Paid next step:',
        'PDF/Table Extraction ($125): extract up to 10 authorized pages or screenshots into clean CSV plus field validation, QA report, and summary dashboard.',
        '',
        'Proof rule: count $0 until buyer requests the PDF/Table Extraction package and external payment proof exists.'
      ].join('\\n');
      document.getElementById('pdfOutput').textContent = brief;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: PDF/Table Extraction',
        'Listed price: $125',
        'Tool source: #{SITE_URL}pdf-table-intake-builder.html',
        '',
        'Requested quantity or scope:',
        'Extract authorized PDF, screenshot, or messy table source into clean CSV, field map, QA report, and summary dashboard.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Clean CSV, field map, QA report, and summary dashboard accepted by buyer.',
        '',
        'Safety confirmation:',
        'Buyer confirms source is public or buyer-authorized and does not include secrets, payment cards, tax identifiers, regulated private details, or unclear-rights copyrighted material.',
        '',
        'Brief:',
        brief
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: PDF/Table Extraction', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('pdfOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
      return brief;
    }
    ['sourceType','sourceLabel','pageCount','tableCount','outputFields','cleaningRules','qualityRisks','privacyLevel','sampleRows','deliverables'].forEach(id => document.getElementById(id).addEventListener('input', buildPdfBrief));
    document.getElementById('sourceType').addEventListener('change', buildPdfBrief);
    document.getElementById('privacyLevel').addEventListener('change', buildPdfBrief);
    document.getElementById('pdfBuildBtn').addEventListener('click', event => { event.preventDefault(); buildPdfBrief(); });
    document.getElementById('pdfDownloadBtn').addEventListener('click', event => {
      event.preventDefault();
      const brief = buildPdfBrief();
      const blob = new Blob([brief], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'pdf-table-extraction-brief.txt'; a.click();
      URL.revokeObjectURL(url);
    });
    buildPdfBrief();
  </script>
HTML

audit_tool_row = tool_rows.find { |row| row[:slug] == "website-audit-lite" }
File.write(File.join(DOCS, "website-audit-lite.html"), page_shell("Website Audit Lite - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(audit_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(website_audit_offer))}">Start $150 audit</a></p><h1>Website Audit Lite</h1><p class="muted">Create a quick buyer-facing audit brief from public page observations. This tool does not fetch the site; enter only public observations you are allowed to share.</p></header>
  <section class="split">
    <div class="panel">
      <h2>Inputs</h2>
      <label for="siteUrl">Public URL</label><input id="siteUrl" value="https://example.com">
      <label for="headline">Main headline</label><input id="headline" value="Simple service headline">
      <label for="cta">Primary CTA</label><input id="cta" value="Book a call">
      <label for="concerns">Visible concerns</label><textarea id="concerns">Unclear proof, weak mobile CTA, no pricing signal, missing trust section</textarea>
      <p class="buttons"><a href="#" id="auditBtn">Build audit brief</a><a href="#{h(prefilled_issue_url(website_audit_offer))}" id="auditOrderBtn">Start full audit</a></p>
    </div>
    <aside>
      <div class="fact"><span>Paid path</span><strong>Website Audit Microservice - $150</strong></div>
      <div class="fact"><span>First $100</span><strong>One accepted audit clears $100.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <section class="panel"><h2>Generated brief</h2><div class="copybox" id="auditOutput"></div></section>
  <script>
    function buildAudit(){
      const url = document.getElementById('siteUrl').value.trim();
      const headline = document.getElementById('headline').value.trim();
      const cta = document.getElementById('cta').value.trim();
      const concerns = document.getElementById('concerns').value.trim().split(/\\n|,/).map(s => s.trim()).filter(Boolean);
      const brief = [
        'Website Audit Lite brief',
        '',
        'URL: ' + url,
        'Headline: ' + headline,
        'Primary CTA: ' + cta,
        '',
        'Quick observations:',
        ...concerns.map((item, i) => (i + 1) + '. ' + item),
        '',
        'Suggested paid sprint:',
        'Website Audit Microservice ($150): public-site quick-win audit, mobile/CTA checks, copy clarity, trust section, and prioritized fixes.',
        '',
        'Proof rule: count $0 until buyer accepts scope and external payment proof exists.'
      ].join('\\n');
      document.getElementById('auditOutput').textContent = brief;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Website Audit Microservice',
        'Listed price: $150',
        'Tool source: #{SITE_URL}website-audit-lite.html',
        'Public URL: ' + url,
        '',
        'Requested quantity or scope:',
        'Full public-site audit based on this brief.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Audit report accepted by buyer.',
        '',
        'Brief:',
        brief
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Website Audit Microservice', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('auditOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
    }
    ['siteUrl','headline','cta','concerns'].forEach(id => document.getElementById(id).addEventListener('input', buildAudit));
    document.getElementById('auditBtn').addEventListener('click', event => { event.preventDefault(); buildAudit(); });
    buildAudit();
  </script>
HTML

blueprint_tool_row = tool_rows.find { |row| row[:slug] == "workflow-blueprint-lite" }
File.write(File.join(DOCS, "workflow-blueprint-lite.html"), page_shell("Workflow Blueprint Lite - Micro Offer Studio", <<~HTML, jsonld_script(tool_schema(blueprint_tool_row))))
  <header><p class="buttons"><a href="index.html">Home</a><a href="tools.html">Free tools</a><a href="#{h(prefilled_issue_url(automation_offer))}">Start $100 blueprint</a></p><h1>Workflow Blueprint Lite</h1><p class="muted">Draft a small automation blueprint from a repetitive workflow. This creates an order-ready brief for the $100 Automation Blueprint service.</p></header>
  <section class="split">
    <div class="panel">
      <h2>Workflow</h2>
      <label for="trigger">Trigger</label><input id="trigger" value="New form submission">
      <label for="source">Source system</label><input id="source" value="Website form">
      <label for="destination">Destination system</label><input id="destination" value="Spreadsheet and email notification">
      <label for="failures">Likely failure cases</label><textarea id="failures">Missing email, duplicate submission, malformed budget field</textarea>
      <p class="buttons"><a href="#" id="blueprintBtn">Build blueprint</a><a href="#{h(prefilled_issue_url(automation_offer))}" id="blueprintOrderBtn">Start $100 order</a></p>
    </div>
    <aside>
      <div class="fact"><span>Paid path</span><strong>Automation Blueprint - $100</strong></div>
      <div class="fact"><span>First $100</span><strong>One blueprint reaches $100.</strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
    </aside>
  </section>
  <section class="panel"><h2>Generated blueprint</h2><div class="copybox" id="blueprintOutput"></div></section>
  <script>
    function buildBlueprint(){
      const trigger = document.getElementById('trigger').value.trim();
      const source = document.getElementById('source').value.trim();
      const destination = document.getElementById('destination').value.trim();
      const failures = document.getElementById('failures').value.trim().split(/\\n|,/).map(s => s.trim()).filter(Boolean);
      const blueprint = [
        'Workflow Blueprint Lite',
        '',
        'Trigger: ' + trigger,
        'Source: ' + source,
        'Destination: ' + destination,
        '',
        'Steps:',
        '1. Capture trigger event and required fields.',
        '2. Validate required fields before writing data.',
        '3. Normalize field names and values.',
        '4. Send to destination and log status.',
        '5. Alert owner when validation or delivery fails.',
        '',
        'Failure cases:',
        ...failures.map((item, i) => (i + 1) + '. ' + item),
        '',
        'Paid next step: Automation Blueprint ($100) with trigger map, field map, failure handling, and test plan.',
        'Proof rule: count $0 until buyer accepts scope and external payment proof exists.'
      ].join('\\n');
      document.getElementById('blueprintOutput').textContent = blueprint;
      const issueBody = [
        '## Ready-to-pay intake',
        '',
        'Offer: Automation Blueprint',
        'Listed price: $100',
        'Tool source: #{SITE_URL}workflow-blueprint-lite.html',
        '',
        'Requested quantity or scope:',
        'Full automation blueprint from this brief.',
        '',
        'Payment/proof route:',
        '[buyer to fill]',
        '',
        'Acceptance proof:',
        'Blueprint accepted by buyer.',
        '',
        'Brief:',
        blueprint
      ].join('\\n');
      const params = new URLSearchParams({ template: 'ready-to-pay.md', title: 'Ready to pay: Automation Blueprint', labels: 'paid-inquiry,ready-to-pay', body: issueBody });
      document.getElementById('blueprintOrderBtn').href = '#{h(NEW_ISSUE_URL)}?' + params.toString();
    }
    ['trigger','source','destination','failures'].forEach(id => document.getElementById(id).addEventListener('input', buildBlueprint));
    document.getElementById('blueprintBtn').addEventListener('click', event => { event.preventDefault(); buildBlueprint(); });
    buildBlueprint();
  </script>
HTML

order_intake_rows = OFFERS.map do |offer|
  {
    type: offer[:type],
    title: offer[:title],
    slug: offer[:slug],
    price: offer[:price],
    amount: price_amount(offer),
    first_100: offer[:first_100],
    detail_url: "#{SITE_URL}#{offer[:slug]}.html",
    ready_to_pay_url: prefilled_issue_url(offer),
    template_url: template_issue_url(offer)
  }
end

CSV.open(File.join(DOCS, "order_intake.csv"), "w", write_headers: true, headers: %w[type title slug price amount first_100 detail_url ready_to_pay_url template_url]) do |csv|
  order_intake_rows.each do |row|
    csv << row.values_at(:type, :title, :slug, :price, :amount, :first_100, :detail_url, :ready_to_pay_url, :template_url)
  end
end

start_order_options = order_intake_rows.map do |row|
  %(<option value="#{h(row[:slug])}">#{h(row[:title])} - #{h(row[:price])} - #{h(row[:type])}</option>)
end.join

start_order_data = JSON.generate(order_intake_rows)
File.write(File.join(DOCS, "start-order.html"), page_shell("Start Order - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="pricing.html">Pricing</a><a href="order_intake.csv">Order CSV</a><a href="proof.html">Proof rules</a><a href="fulfillment.html">Fulfillment</a></p><h1>Start Order</h1><p class="muted">A structured intake builder that turns a visitor into a specific paid inquiry. This page still does not process payment; it creates a ready-to-pay issue draft with the exact offer, price, scope, and proof fields.</p></header>
  <section class="notice"><h2>Payment boundary</h2><p>Opening an issue is not payment. Count $0 until an external paid order, cleared invoice, funded milestone, payable balance, posted refund/credit, or equivalent proof exists.</p></section>
  <section class="split">
    <div class="panel">
      <h2>Build a paid inquiry</h2>
      <label for="offer">Offer</label>
      <select id="offer">#{start_order_options}</select>
      <label for="quantity">Quantity or units</label>
      <input id="quantity" type="number" min="1" step="1" value="1">
      <label for="scope">Requested scope</label>
      <textarea id="scope" placeholder="Public URL, authorized file type, workflow, bundle transfer, or exact output. Do not include secrets."></textarea>
      <label for="payment">Payment/proof route</label>
      <input id="payment" placeholder="invoice, funded milestone, marketplace order, checkout receipt, or other external proof">
      <label for="deadline">Deadline</label>
      <input id="deadline" placeholder="date or timing">
      <label for="acceptance">Acceptance proof</label>
      <textarea id="acceptance" placeholder="What will show the work is accepted and payable?"></textarea>
      <p class="buttons"><a id="readyLink" href="#">Open ready-to-pay issue</a><a id="templateLink" href="#">Open form template</a><a id="detailLink" href="#">Offer page</a></p>
    </div>
    <aside>
      <div class="fact"><span>Selected price</span><strong id="price"></strong></div>
      <div class="fact"><span>Estimated gross</span><strong class="total" id="gross"></strong></div>
      <div class="fact"><span>Path to $100</span><strong id="first100"></strong></div>
      <div class="fact"><span>Money status</span><strong>$0 until external payment proof exists</strong></div>
      <div class="copybox" id="bodyPreview"></div>
    </aside>
  </section>
  <script>
    const offers = #{start_order_data};
    const bySlug = Object.fromEntries(offers.map(o => [o.slug, o]));
    const offerEl = document.getElementById('offer');
    const quantityEl = document.getElementById('quantity');
    const scopeEl = document.getElementById('scope');
    const paymentEl = document.getElementById('payment');
    const deadlineEl = document.getElementById('deadline');
    const acceptanceEl = document.getElementById('acceptance');
    const readyLink = document.getElementById('readyLink');
    const templateLink = document.getElementById('templateLink');
    const detailLink = document.getElementById('detailLink');
    const priceEl = document.getElementById('price');
    const grossEl = document.getElementById('gross');
    const firstEl = document.getElementById('first100');
    const bodyPreview = document.getElementById('bodyPreview');
    function money(n){ return '$' + Number(n || 0).toFixed(2).replace(/\\.00$/, ''); }
    function issueUrl(offer, body){
      const params = new URLSearchParams({
        template: 'ready-to-pay.md',
        title: 'Ready to pay: ' + offer.title,
        labels: 'paid-inquiry,ready-to-pay',
        body
      });
      return '#{h(NEW_ISSUE_URL)}?' + params.toString();
    }
    function update(){
      const offer = bySlug[offerEl.value];
      const quantity = Math.max(1, parseInt(quantityEl.value || '1', 10));
      const gross = offer.amount * quantity;
      const body = [
        '## Ready-to-pay intake',
        '',
        'Offer: ' + offer.title,
        'Listed price: ' + offer.price,
        'Quantity or units: ' + quantity,
        'Estimated gross: ' + money(gross),
        'Offer page: ' + offer.detail_url,
        '',
        'Requested quantity or scope:',
        scopeEl.value || '[buyer to fill]',
        '',
        'Payment/proof route:',
        paymentEl.value || '[buyer to fill]',
        '',
        'Deadline:',
        deadlineEl.value || '[buyer to fill]',
        '',
        'Acceptance proof:',
        acceptanceEl.value || '[buyer to fill]',
        '',
        'Safety confirmation:',
        '- I will not post passwords, payment cards, tax identifiers, medical/legal/financial private details, or files I am not authorized to share.',
        '- I understand this issue is not payment by itself; money counts only after external payment or payout proof exists.'
      ].join('\\n');
      priceEl.textContent = offer.price;
      grossEl.textContent = money(gross);
      firstEl.textContent = offer.first_100;
      bodyPreview.textContent = body;
      readyLink.href = issueUrl(offer, body);
      templateLink.href = offer.template_url;
      detailLink.href = offer.detail_url;
    }
    [offerEl, quantityEl, scopeEl, paymentEl, deadlineEl, acceptanceEl].forEach(el => el.addEventListener('input', update));
    offerEl.addEventListener('change', update);
    update();
  </script>
HTML

if ORDER_BOARDS.any?
  FileUtils.cp(ORDER_BOARDS_PATH, File.join(DOCS, "order_boards.csv"))
  File.write(File.join(DOCS, "order-boards.html"), page_shell("Order Boards - Micro Offer Studio", <<~HTML))
    <header><p class="buttons"><a href="index.html">Home</a><a href="pricing.html">Pricing</a><a href="proof.html">Proof rules</a><a href="order_boards.csv">CSV</a></p><h1>Focused Order Boards</h1><p class="muted">Specific public issue threads for the fastest $100 routes. These are owned-repo order boards, not third-party outreach. Money still requires external buyer/payment proof.</p></header>
    <section class="notice"><h2>Current money status</h2><p>All listed boards are public inquiry surfaces. They count as $0 until a buyer comments, scope is accepted, and payment/payout proof exists.</p></section>
    <section><table><thead><tr><th>Issue</th><th>Offer</th><th>Type</th><th>Price</th><th>Path to $100</th><th>State</th><th>Comments</th></tr></thead><tbody>#{order_board_rows(ORDER_BOARDS)}</tbody></table></section>
  HTML
else
  File.write(File.join(DOCS, "order-boards.html"), page_shell("Order Boards - Micro Offer Studio", <<~HTML))
    <header><p class="buttons"><a href="index.html">Home</a><a href="pricing.html">Pricing</a></p><h1>Focused Order Boards</h1><p class="muted">No focused order-board issues have been generated yet.</p></header>
  HTML
end

if PROOF_MONITOR.any?
  FileUtils.cp(PROOF_MONITOR_PATH, File.join(DOCS, "proof_monitor.csv"))
  File.write(File.join(DOCS, "proof-monitor.html"), page_shell("Proof Monitor - Micro Offer Studio", <<~HTML))
    <header><p class="buttons"><a href="index.html">Home</a><a href="order-boards.html">Order boards</a><a href="download-followup.html">Download follow-up</a><a href="proof.html">Proof rules</a><a href="proof_monitor.csv">CSV</a></p><h1>Proof Monitor</h1><p class="muted">Current issue-board, standalone repo board, and release-download signal state. This monitor does not infer income from public pages, issues, downloads, or comments.</p></header>
    <section class="notice"><h2>Confirmed money: $0</h2><p>Every monitored row stays at $0 until external paid order, cleared invoice, funded milestone, payable balance, posted refund/credit, or equivalent proof exists.</p></section>
    <section><table><thead><tr><th>Signal</th><th>Kind</th><th>Title</th><th>Price</th><th>State</th><th>Issue comments</th><th>Release downloads</th><th>Proof status</th><th>Next paid step</th><th>Money</th></tr></thead><tbody>#{proof_monitor_rows(PROOF_MONITOR)}</tbody></table></section>
  HTML
else
  File.write(File.join(DOCS, "proof-monitor.html"), page_shell("Proof Monitor - Micro Offer Studio", <<~HTML))
    <header><p class="buttons"><a href="index.html">Home</a><a href="proof.html">Proof rules</a></p><h1>Proof Monitor</h1><p class="muted">No proof monitor rows have been generated yet.</p></header>
  HTML
end

File.write(File.join(DOCS, "fulfillment.html"), page_shell("Fulfillment - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="products.html">Products</a><a href="services.html">Services</a><a href="proof.html">Proof rules</a></p><h1>Fulfillment Ledger</h1><p class="muted">This page shows what is ready to deliver after an external paid request. Paid bundles are not uploaded publicly; checksums identify the local deliverable that can be transferred after payment or buyer authorization.</p></header>
  <section class="notice"><h2>Delivery boundary</h2><p>The public site is not a checkout and does not itself prove earnings. Delivery happens only after a legitimate buyer request, accepted scope, and payment/proof route. Full ZIP bundles stay local until that point.</p></section>
  <section><h2>Ready artifacts</h2><table><thead><tr><th>Offer</th><th>Type</th><th>Price</th><th>Fulfillment status</th><th>Artifact</th><th>SHA-256</th></tr></thead><tbody>#{fulfillment_rows(OFFERS)}</tbody></table></section>
HTML

proof_body = <<~HTML
  <header><p class="buttons"><a href="index.html">Home</a><a href="fulfillment.html">Fulfillment</a><a href="proposals.html">Proposal copy</a></p><h1>Proof Rules</h1><p class="muted">What must exist before any dollar is counted toward the $100 objective.</p></header>
  <section class="notice"><h2>Current confirmed money: $0</h2><p>Prepared assets, public pages, issues, sent proposals, draft listings, and pending requests do not count. Count money only from external proof.</p></section>
  <section class="grid">
    <article class="panel"><h2>Digital product proof</h2><ul><li>Paid order, platform receipt, payment-provider record, or payable balance.</li><li>Amount net of refunds and platform holds when known.</li><li>Product delivered or available according to buyer terms.</li></ul></article>
    <article class="panel"><h2>Service proof</h2><ul><li>Accepted scope and buyer authorization.</li><li>Funded order, paid invoice, escrow/milestone, or cleared payment.</li><li>Delivered work accepted by buyer or platform.</li></ul></article>
    <article class="panel"><h2>Refund/savings proof</h2><ul><li>Provider confirmation, posted credit, next-bill reduction, or cancelled renewal.</li><li>Only count verified annualized savings when the provider confirms the charge is stopped.</li></ul></article>
    <article class="panel"><h2>Do not count</h2><ul><li>GitHub Pages traffic, draft listings, estimates, outreach sent, unaccepted work, unpaid issues, unapproved refunds, or expected future sales.</li></ul></article>
  </section>
HTML
File.write(File.join(DOCS, "proof.html"), page_shell("Proof Rules - Micro Offer Studio", proof_body))

proposal_cards = (SERVICES.first(8) + PRODUCTS.values_at(5, 10, 4, 6)).compact.map do |offer|
  issue = prefilled_issue_url(offer)
  <<~HTML
    <article class="panel">
      <h2>#{h(offer[:title])}</h2>
      <p><strong>Price:</strong> #{h(offer[:price])} · <strong>First $100:</strong> #{h(offer[:first_100])}</p>
      <div class="copybox">Hi - I have a ready-to-scope #{offer[:type]} called "#{offer[:title]}". It is designed for #{offer[:description].sub(/\.$/, "")}. The fixed price is #{offer[:price]}. If this is useful, open a ready-to-pay inquiry with the exact scope, deadline, acceptance proof, and payment route here: #{issue}</div>
      <p class="buttons"><a href="#{h(offer[:slug])}.html">Offer page</a><a href="#{h(issue)}">Start order</a></p>
    </article>
  HTML
end.join
File.write(File.join(DOCS, "proposals.html"), page_shell("Proposal Copy - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="fulfillment.html">Fulfillment</a><a href="proof.html">Proof rules</a></p><h1>Proposal Copy</h1><p class="muted">Copy-ready, truthful snippets for channels the account owner controls. Do not spam; use only in relevant conversations or profiles where posting is allowed.</p></header>
  <section class="grid">#{proposal_cards}</section>
HTML

faq_body = <<~HTML
  <header><p class="buttons"><a href="index.html">Home</a><a href="pricing.html">Pricing</a><a href="fulfillment.html">Fulfillment</a><a href="proof.html">Proof rules</a></p><h1>Buyer FAQ</h1><p class="muted">Practical details for legitimate paid requests.</p></header>
  <section class="grid">
    <article class="panel"><h2>How do I buy?</h2><p>Open the first $100 request board or a paid inquiry issue with the offer name, exact scope, budget/payment route, deadline, and acceptance proof. The public site does not process payment.</p></article>
    <article class="panel"><h2>What can be delivered immediately?</h2><p>Digital product bundles and prepared service kits are listed on the fulfillment ledger. Full paid bundles are local and transferred only after accepted scope and external payment/proof.</p></article>
    <article class="panel"><h2>What should I not share?</h2><p>Do not post passwords, payment cards, tax IDs, private financial/medical/legal facts, or files you are not authorized to share. Services can be scoped from public data or buyer-provided safe files.</p></article>
    <article class="panel"><h2>When does money count?</h2><p>Money counts only after an external paid order, cleared invoice, funded milestone, payable balance, posted refund/credit, or equivalent proof exists. Public pages and issues are not earnings.</p></article>
    <article class="panel"><h2>What is the fastest $100 service?</h2><p>The $100 Automation Blueprint reaches $100 with one accepted scope and payment. The $125 Data Cleanup Sprint and $150 Website Audit also clear $100 with one order.</p></article>
    <article class="panel"><h2>What is the fastest product path?</h2><p>The $29 Browser Extension Template or Mini Course Workbook reaches $100 gross after four paid transfers. Product transfer still requires a payment route and delivery proof.</p></article>
  </section>
HTML
File.write(File.join(DOCS, "buyer-faq.html"), page_shell("Buyer FAQ - Micro Offer Studio", faq_body))

File.write(File.join(DOCS, "share-kit.html"), page_shell("Share Kit - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="pricing.html">Pricing</a><a href="case-studies.html">Case studies</a><a href="#{h(ISSUE_BOARD_URL)}">First $100 board</a></p><h1>Share Kit</h1><p class="muted">Owned-channel snippets for profiles, relevant conversations, or buyer follow-up. Do not spam unrelated threads or communities.</p></header>
  <section class="notice"><h2>Safe-use rule</h2><p>Use these only where posting is allowed and relevant. Do not imply payment has already happened. Do not claim credentials, endorsements, results, or guarantees that are not true.</p></section>
  <section class="panel"><h2>Choose the right route</h2><p>If a buyer describes a problem rather than naming an offer, start with the <a href="buyer-intent-router.html">Buyer Intent Router</a> and send only the matching ready-to-buy URL.</p></section>
  <section><h2>Ready-to-buy route snippets</h2><table><thead><tr><th>Route</th><th>Price</th><th>Ready URL</th><th>Snippet</th></tr></thead><tbody>#{ready_to_buy_share_rows(ready_to_buy_offers)}</tbody></table></section>
  <section><h2>Offer snippets</h2><table><thead><tr><th>Offer</th><th>Price</th><th>Snippet</th></tr></thead><tbody>#{share_rows(OFFERS)}</tbody></table></section>
HTML

OFFERS.each do |offer|
  issue = prefilled_issue_url(offer)
  form_issue = template_issue_url(offer)
  body = <<~HTML
    <header>
      <p class="buttons"><a href="index.html">Home</a><a href="#{offer[:type] == "product" ? "products.html" : "services.html"}">Back to #{h(offer[:type])}s</a><a href="start-order.html">Quote builder</a><a href="#{h(issue)}">Start order</a></p>
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
          <h2>Fulfillment</h2>
          <p><strong>Status:</strong> #{offer[:zip_name] ? "Local paid bundle ready" : "Source folder ready"}</p>
          <p><strong>Artifact:</strong> #{h(offer[:zip_name] || offer[:source_dir])}</p>
          <p><strong>SHA-256:</strong> #{h(offer[:zip_sha256] || "N/A")}</p>
          <p>Full deliverables are transferred only after accepted scope and external payment/proof. Public previews are intentionally not the full paid bundle.</p>
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
        <div class="fact"><span>Ready-to-pay issue</span><a href="#{h(issue)}">Open prefilled issue</a></div>
        <div class="fact"><span>Form template</span><a href="#{h(form_issue)}">Open #{h(offer[:type])} form</a></div>
      </aside>
    </section>
  HTML
  File.write(File.join(DOCS, "#{offer[:slug]}.html"), page_shell("#{offer[:title]} - Micro Offer Studio", body, jsonld_script(offer_schema(offer))))
end

source_body = <<~HTML
  <header><p class="buttons"><a href="index.html">Home</a><a href="products.html">Products</a><a href="services.html">Services</a></p><h1>Source Notes</h1><p class="muted">Generated #{h(GENERATED_AT)} from local assets under <code>#{h(RUN_ROOT)}</code>.</p></header>
  <section class="notice"><h2>Public Safety Boundary</h2><p>The public launch package intentionally excludes private credentials, user financial data, buyer files, KYC/tax details, and full paid ZIP downloads. It publishes generated previews, offer pages, and an inquiry template only.</p></section>
  <section><h2>Included Offers</h2><ul>#{OFFERS.map { |offer| "<li>#{h(offer[:title])} - #{h(offer[:type])} - #{h(offer[:source_dir])}</li>" }.join}</ul></section>
HTML
File.write(File.join(DOCS, "source-notes.html"), page_shell("Source Notes - Micro Offer Studio", source_body))

CSV.open(File.join(LAUNCH_ROOT, "public_launch_manifest.csv"), "w", write_headers: true, headers: %w[generated_at_jst type title slug price source_dir public_detail preview_public first_100 fulfillment_status zip_name zip_bytes zip_sha256]) do |csv|
  OFFERS.each do |offer|
    csv << [
      GENERATED_AT,
      offer[:type],
      offer[:title],
      offer[:slug],
      offer[:price],
      offer[:source_dir],
      "docs/#{offer[:slug]}.html",
      offer[:preview_public].to_s,
      offer[:first_100],
      offer[:zip_name] ? "local_paid_bundle_ready" : "source_folder_ready",
      offer[:zip_name].to_s,
      offer[:zip_bytes].to_s,
      offer[:zip_sha256].to_s
    ]
  end
end

CSV.open(File.join(DOCS, "fulfillment_manifest.csv"), "w", write_headers: true, headers: %w[type title slug price fulfillment_status artifact zip_bytes zip_sha256 source_dir]) do |csv|
  OFFERS.each do |offer|
    csv << [
      offer[:type],
      offer[:title],
      offer[:slug],
      offer[:price],
      offer[:zip_name] ? "local_paid_bundle_ready" : "source_folder_ready",
      offer[:zip_name] || offer[:source_dir],
      offer[:zip_bytes].to_s,
      offer[:zip_sha256].to_s,
      offer[:source_dir]
    ]
  end
end

File.write(File.join(LAUNCH_ROOT, "README.md"), <<~MD)
  # Micro Offer Studio

  Public launch package generated during the autonomous earning run.

  - Generated: #{GENERATED_AT}
  - Live site: #{SITE_URL}
  - Public site root: `docs/index.html`
  - Manifest: `public_launch_manifest.csv`
  - Public fulfillment manifest: `docs/fulfillment_manifest.csv`
  - Inquiry path: #{ISSUE_URL}
  - Buyer intent router: #{SITE_URL}buyer-intent-router.html
  - Ready-to-buy routes: #{SITE_URL}ready-to-buy.html
  - Close a service order: #{SITE_URL}close-service-order.html
  - Ready-to-pay builder: #{SITE_URL}start-order.html
  - Payment activation: #{SITE_URL}payment-activation
  - Free tools: #{SITE_URL}tools.html
  - GitHub lead repos: #{SITE_URL}github-leads.html
  - Tool manifest: #{SITE_URL}tool_manifest.csv
  - IndexNow status: #{SITE_URL}indexnow.html
  - LLM summary: #{SITE_URL}llms.txt
  - RSS feed: #{SITE_URL}feed.xml
  - Search index: #{SITE_URL}search-index.json
  - Structured data graph: #{SITE_URL}structured-data.json
  - First $100 Fast Start board: #{ISSUE_BOARD_URL}
  - Pricing page: #{SITE_URL}pricing.html
  - Case studies: #{SITE_URL}case-studies.html
  - Sample pack: #{SITE_URL}micro-offer-studio-sample-pack.zip
  - Focused order boards: #{SITE_URL}order-boards.html
  - Proof monitor: #{SITE_URL}proof-monitor.html
  - Buyer FAQ: #{SITE_URL}buyer-faq.html
  - Share kit: #{SITE_URL}share-kit.html
  - Order intake CSV: #{SITE_URL}order_intake.csv
  - Offers: #{PRODUCTS.length} digital products and #{SERVICES.length} productized services

  Confirmed earned money is still `$0` until external buyer/payment/payout proof exists. This repo publishes generated preview and inquiry material only; it does not include private credentials, KYC/tax/payment data, or private buyer files.

  ## Observed preview-download close rooms

  These are the closest current public paths because their preview ZIPs have download signals. Downloads are interest only; paid work still requires accepted scope, a seller-controlled payment route, delivery, and external payment/payout proof.

  - Local SEO GBP Audit Starter ($175): #{SITE_URL}hot-download-close-local-seo-gbp-audit-starter.html
  - PDF Table Extraction Starter ($125): #{SITE_URL}hot-download-close-pdf-table-extraction-starter.html

  ## Fastest $100 paths

  #{(SERVICES.first(6) + PRODUCTS.values_at(5, 10, 4, 6)).compact.map { |offer| "- #{offer[:title]} (#{offer[:price]}): #{offer[:first_100]}" }.join("\n")}

  ## Inquiry safety

  Use the paid inquiry issue template for legitimate paid requests only. Do not post passwords, payment cards, tax identifiers, medical/legal/financial private details, or files you are not authorized to share.
MD

File.write(File.join(LAUNCH_ROOT, ".github", "ISSUE_TEMPLATE", "first-100-fast-start.yml"), <<~YAML)
  name: First $100 Fast Start
  description: Ready-to-pay intake for one exact $100 fixed-scope starter.
  title: "Ready to pay: First $100 Fast Start - "
  labels: ["paid-inquiry", "ready-to-pay", "first-100"]
  body:
    - type: markdown
      attributes:
        value: |
          Start here for one exact $100 fixed-scope starter:
          #{SITE_URL}first-100-fast-start.html

          Order board:
          https://github.com/jaxassistant55/jax-micro-offer-studio/issues/24

          Payment activation after scope acceptance:
          #{SITE_URL}payment-activation

          This GitHub issue is intake only. Paid work starts only after scope is accepted and external payment proof exists through a seller-owned checkout, invoice, marketplace order, funded milestone, or payment request.
    - type: dropdown
      id: starter_scope
      attributes:
        label: Starter scope
        description: Pick one exact $100 starter.
        options:
          - Automation Blueprint Mini ($100)
          - PDF/Table Extraction Mini ($100)
          - Local SEO Snapshot Mini ($100)
          - Website Quick-Win Audit Mini ($100)
      validations:
        required: true
    - type: textarea
      id: authorized_input
      attributes:
        label: Public or buyer-authorized input
        description: Provide a public URL or describe the buyer-authorized input. Do not paste secrets or confidential files into this public issue.
        placeholder: "Public URL, public business/profile, workflow summary, or buyer-authorized non-sensitive input summary."
      validations:
        required: true
    - type: input
      id: deadline
      attributes:
        label: Deadline
        description: When do you need the starter delivered?
        placeholder: "YYYY-MM-DD or relative deadline"
      validations:
        required: true
    - type: textarea
      id: acceptance
      attributes:
        label: Acceptance criterion
        description: What will show that the fixed-scope starter is accepted?
        placeholder: "Example: delivered CSV opens cleanly; audit covers the listed URL; blueprint includes current flow, risks, and next actions."
      validations:
        required: true
    - type: input
      id: payment_route
      attributes:
        label: External payment or proof route
        description: Use a seller-owned checkout, invoice, marketplace order, funded milestone, payment request, or equivalent external proof route.
        placeholder: "invoice, checkout, funded milestone, marketplace order, or payment request"
      validations:
        required: true
    - type: checkboxes
      id: safety
      attributes:
        label: Safety confirmation
        options:
          - label: I will not post passwords, payment cards, tax identifiers, credentials, private client files, or confidential documents in this public issue.
            required: true
          - label: I understand this issue is not payment proof and money counts only after external payment is posted, released, payable, or cleared.
            required: true
YAML

File.write(File.join(LAUNCH_ROOT, ".github", "ISSUE_TEMPLATE", "paid-inquiry.yml"), <<~YAML)
  name: Paid inquiry
  description: Request a product bundle, custom service, or scoped paid handoff.
  title: "Inquiry: "
  labels: ["paid-inquiry"]
  body:
    - type: markdown
      attributes:
        value: |
          Payment activation after scope acceptance: #{SITE_URL}payment-activation
          Exact $100 fast-start route: #{SITE_URL}first-100-fast-start.html
          Use this for legitimate paid inquiries only. Do not paste passwords, payment cards, tax identifiers, medical/legal/financial private details, or files you are not authorized to share.
          If you arrived from a preview download, use the matching fixed-scope close room first:
          - Local SEO GBP Audit Starter ($175): #{SITE_URL}hot-download-close-local-seo-gbp-audit-starter.html
          - PDF Table Extraction Starter ($125): #{SITE_URL}hot-download-close-pdf-table-extraction-starter.html
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

File.write(File.join(LAUNCH_ROOT, ".github", "ISSUE_TEMPLATE", "service-scope.yml"), <<~YAML)
  name: Service scope request
  description: Request a fixed-scope productized service.
  title: "Service scope: "
  labels: ["paid-inquiry", "needs-scope"]
  body:
    - type: markdown
      attributes:
        value: |
          Payment activation after scope acceptance: #{SITE_URL}payment-activation
          Exact $100 fast-start route: #{SITE_URL}first-100-fast-start.html
          Use this for one of the fixed-scope services. Do not paste secrets, payment details, tax identifiers, or files you are not authorized to share.
          Observed preview-download close rooms:
          - Local SEO GBP Audit Starter ($175): #{SITE_URL}hot-download-close-local-seo-gbp-audit-starter.html
          - PDF Table Extraction Starter ($125): #{SITE_URL}hot-download-close-pdf-table-extraction-starter.html
    - type: dropdown
      id: service
      attributes:
        label: Service
        options:
          - First $100 Fast Start - choose one mini scope ($100)
  #{SERVICES.map { |offer| "        - #{offer[:title]} (#{offer[:price]})" }.join("\n")}
      validations:
        required: true
    - type: textarea
      id: scope
      attributes:
        label: Exact scope
        description: What public URL, authorized file, workflow, or output should be handled?
      validations:
        required: true
    - type: textarea
      id: acceptance
      attributes:
        label: Acceptance proof
        description: What will show the work is accepted and payable?
      validations:
        required: true
    - type: input
      id: payment
      attributes:
        label: Payment route
        placeholder: "invoice, funded milestone, platform order, or other external proof route"
      validations:
        required: true
YAML

File.write(File.join(LAUNCH_ROOT, ".github", "ISSUE_TEMPLATE", "product-transfer.yml"), <<~YAML)
  name: Product transfer request
  description: Request a digital product bundle transfer after payment/proof route is agreed.
  title: "Product transfer: "
  labels: ["paid-inquiry", "needs-scope"]
  body:
    - type: markdown
      attributes:
        value: |
          Payment activation after scope acceptance: #{SITE_URL}payment-activation
          Use this to request a product bundle listed in the fulfillment ledger. Full ZIP bundles are not public; transfer happens only after accepted payment/proof route.
    - type: dropdown
      id: product
      attributes:
        label: Product
        options:
  #{PRODUCTS.map { |offer| "        - #{offer[:title]} (#{offer[:price]})" }.join("\n")}
      validations:
        required: true
    - type: input
      id: proof_route
      attributes:
        label: Payment or proof route
        placeholder: "paid order, invoice, escrow, transfer receipt, or other approved external proof"
      validations:
        required: true
    - type: textarea
      id: delivery
      attributes:
        label: Delivery preference
        description: How should the bundle be transferred after payment/proof?
      validations:
        required: true
YAML

File.write(File.join(LAUNCH_ROOT, ".github", "ISSUE_TEMPLATE", "ready-to-pay.md"), <<~MD)
  ---
  name: Ready-to-pay issue
  about: Prefilled buyer intake generated from the Start Order page.
  title: "Ready to pay: "
  labels: paid-inquiry, ready-to-pay
  ---

  ## Ready-to-pay intake

  First $100 Fast Start:
  - Page: #{SITE_URL}first-100-fast-start.html
  - Order board: https://github.com/jaxassistant55/jax-micro-offer-studio/issues/24
  - Release CSV: https://github.com/jaxassistant55/jax-micro-offer-studio/releases/download/first-100-fast-start-v1/first_100_fast_start.csv

  Observed preview-download close rooms, if they match your request:
  - Local SEO GBP Audit Starter ($175): #{SITE_URL}hot-download-close-local-seo-gbp-audit-starter.html
  - PDF Table Extraction Starter ($125): #{SITE_URL}hot-download-close-pdf-table-extraction-starter.html

  Offer:
  Listed price:
  Quantity or units:
  Estimated gross:
  Offer page:

  Requested quantity or scope:

  Payment/proof route:
  Payment activation page after scope acceptance: #{SITE_URL}payment-activation

  Deadline:

  Acceptance proof:

  Safety confirmation:
  - I will not post passwords, payment cards, tax identifiers, medical/legal/financial private details, or files I am not authorized to share.
  - I understand this issue is not payment by itself; money counts only after external payment or payout proof exists.
MD

File.write(File.join(LAUNCH_ROOT, ".github", "ISSUE_TEMPLATE", "config.yml"), <<~YAML)
  blank_issues_enabled: false
  contact_links:
    - name: First $100 Fast Start
      url: #{SITE_URL}first-100-fast-start.html
      about: Pick one exact $100 fixed-scope starter and open the ready-to-pay intake.
    - name: Payment activation after scope acceptance
      url: #{SITE_URL}payment-activation
      about: Generate a buyer payment message from a seller-owned payment route after scope is accepted.
    - name: Hot close - Local SEO GBP Audit Starter
      url: #{SITE_URL}hot-download-close-local-seo-gbp-audit-starter.html
      about: Fixed-scope $175 close room for the observed Local SEO preview-download route.
    - name: Hot close - PDF Table Extraction Starter
      url: #{SITE_URL}hot-download-close-pdf-table-extraction-starter.html
      about: Fixed-scope $125 close room for the observed PDF/table preview-download route.
    - name: Live Micro Offer Studio site
      url: #{SITE_URL}
      about: Browse public offers and previews.
    - name: Start order builder
      url: #{SITE_URL}start-order.html
      about: Build a structured ready-to-pay issue.
    - name: Ready-to-buy routes
      url: #{SITE_URL}ready-to-buy.html
      about: Open the highest-intent one-sale service routes.
    - name: Buyer intent router
      url: #{SITE_URL}buyer-intent-router.html
      about: Match a buyer problem to the closest ready-to-buy route.
    - name: Close a service order
      url: #{SITE_URL}close-service-order.html
      about: Use close-ready scripts, invoice lines, and proof gates for $100+ services.
    - name: Fulfillment ledger
      url: #{SITE_URL}fulfillment.html
      about: Check ready artifacts and local bundle checksums.
    - name: First $100 order board
      url: https://github.com/jaxassistant55/jax-micro-offer-studio/issues/24
      about: Comment on the current exact $100 order board.
YAML

File.write(File.join(LAUNCH_ROOT, ".gitignore"), <<~TXT)
  .DS_Store
TXT

File.write(File.join(DOCS, "offers.json"), JSON.pretty_generate(OFFERS.map do |offer|
  offer.slice(:type, :title, :slug, :source_dir, :price, :description, :first_100, :preview_public, :zip_name, :zip_bytes, :zip_sha256)
end))

github_lead_documents = GITHUB_LEADS.map do |row|
  {
    type: "github_lead_repo",
    title: row["title"],
    slug: slug(row["title"]),
    url: absolute_url("github-leads.html"),
    price: row["price"],
    amount_usd: row["price"].to_s.gsub(/[^\d.]/, "").to_f,
    description: "Standalone GitHub lead repository with Pages preview, release ZIP, and paid-inquiry template.",
    first_100: row["first_100_path"],
    start_order_url: row["issue_template_url"],
    proof_rule: row["proof_rule"],
    repo_url: row["repo_url"],
    pages_url: row["pages_url"],
    release_url: row["release_url"]
  }
end

ready_to_buy_documents = ready_to_buy_offers.map do |offer|
  lead = github_lead_for_offer(offer)
  {
    type: "ready_to_buy_route",
    title: "Ready To Buy: #{offer[:title]}",
    slug: "ready-to-buy-#{offer[:slug]}",
    url: absolute_url(ready_to_buy_path(offer)),
    price: offer[:price],
    amount_usd: price_amount(offer),
    description: "High-intent buyer route for #{offer[:description]}",
    first_100: offer[:first_100],
    start_order_url: ready_to_buy_inquiry_url(offer, lead),
    proof_rule: lead["proof_rule"].to_s.empty? ? "Counts $0 until external buyer/payment proof exists." : lead["proof_rule"]
  }
end

buyer_intent_documents = buyer_intents.map do |row|
  {
    type: "buyer_intent_route",
    title: row[:intent],
    slug: "buyer-intent-#{row[:slug]}",
    url: absolute_url("buyer-intent-router.html"),
    price: row[:price],
    amount_usd: row[:price].to_s.gsub(/[^\d.]/, "").to_f,
    description: "Routes buyer problem to #{row[:offer]} with safe inputs and a prefilled inquiry.",
    first_100: "Use #{row[:offer]} route; count $0 until external payment proof exists.",
    start_order_url: row[:inquiry_url],
    proof_rule: row[:proof_rule]
  }
end

buyer_response_document = {
  type: "buyer_response_autopilot",
  title: "Buyer Response Autopilot",
  slug: "buyer-response-playbook",
  url: absolute_url("buyer-response-playbook.html"),
  price: "$0",
  amount_usd: 0,
  description: "Owned-repo workflow and playbook for safe next-step replies on legitimate ready-to-pay or ready-to-buy issues.",
  first_100: "Moves buyer issues closer to payment proof but counts $0 until external posted/released/payable money exists.",
  start_order_url: absolute_url("paid-offer-action-catalog.html"),
  proof_rule: "Counts $0 until external buyer/payment proof exists."
}

search_documents = OFFERS.map do |offer|
  {
    type: offer[:type],
    title: offer[:title],
    slug: offer[:slug],
    url: absolute_url("#{offer[:slug]}.html"),
    price: offer[:price],
    amount_usd: price_amount(offer),
    description: offer[:description],
    first_100: offer[:first_100],
    start_order_url: prefilled_issue_url(offer),
    proof_rule: "Counts $0 until external buyer/payment proof exists."
  }
end + tool_rows.map do |row|
  {
    type: "free_tool",
    title: row[:title],
    slug: row[:slug],
    url: absolute_url(row[:path]),
    price: "$0",
    amount_usd: 0,
    description: "Browser-only lead tool for #{row[:service]}.",
    first_100: row[:proof_rule],
    start_order_url: row[:paid_path],
    proof_rule: row[:proof_rule]
  }
end + github_lead_documents + ready_to_buy_documents + buyer_intent_documents + [buyer_response_document]

File.write(File.join(DOCS, "search-index.json"), JSON.pretty_generate(
  generated_at_jst: GENERATED_AT,
  site: SITE_URL,
  money_status: "Confirmed earned money remains $0 until external proof exists.",
  documents: search_documents
))

structured_graph = {
  "@context" => "https://schema.org",
  "@graph" => [
    site_schema,
    ready_to_buy_schema,
    buyer_router_schema,
    tools_schema,
    *OFFERS.map { |offer| offer_schema(offer) },
    *ready_to_buy_documents.map do |row|
      {
        "@type" => "WebPage",
        "name" => row[:title],
        "url" => row[:url],
        "description" => row[:description]
      }
    end,
    {
      "@type" => "WebPage",
      "additionalType" => "buyer_response_autopilot",
      "name" => "Buyer Response Autopilot",
      "url" => absolute_url("buyer-response-playbook.html"),
      "description" => "Safe workflow and playbook for responding to legitimate paid buyer issues."
    },
    *tool_rows.map { |row| tool_schema(row) },
    *GITHUB_LEADS.map do |row|
      {
        "@type" => "WebPage",
        "name" => row["title"],
        "url" => row["repo_url"],
        "description" => "Standalone GitHub lead repository for #{row["first_100_path"]}"
      }
    end
  ]
}
File.write(File.join(DOCS, "structured-data.json"), JSON.pretty_generate(structured_graph))

llms_lines = [
  "# Micro Offer Studio",
  "",
  "Public offer catalog for generated digital products, productized micro-services, and free browser-only lead tools.",
  "Confirmed earned money remains $0 until external buyer/payment/payout proof exists.",
  "",
  "## Fastest paid paths",
  "- Automation Blueprint: $100 service, one accepted paid order reaches $100. #{absolute_url("automation-blueprint.html")}",
  "- Data Cleanup Sprint: $125 service, one accepted paid order clears $100. #{absolute_url("data-cleanup-sprint.html")}",
  "- Website Audit Microservice: $150 service, one accepted paid order clears $100. #{absolute_url("website-audit-microservice.html")}",
  "",
  "## Ready-to-buy routes",
  "- Buyer response autopilot: #{absolute_url("buyer-response-playbook.html")}",
  "- Ready-to-buy index: #{absolute_url("ready-to-buy.html")}",
  "- Buyer intent router: #{absolute_url("buyer-intent-router.html")}",
  *ready_to_buy_offers.map { |offer| "- #{offer[:title]}: #{absolute_url(ready_to_buy_path(offer))} -> #{ready_to_buy_inquiry_url(offer, github_lead_for_offer(offer))}" },
  "",
  "## Free tools that route to paid services",
  *tool_rows.map { |row| "- #{row[:title]}: #{absolute_url(row[:path])} -> #{row[:service]} #{row[:price]}" },
  "",
  "## Standalone GitHub lead repositories",
  *GITHUB_LEADS.map { |row| "- #{row["title"]}: #{row["repo_url"]} with preview #{row["pages_url"]} and inquiry template #{row["issue_template_url"]}" },
  "",
  "## Machine-readable files",
  "- Search index: #{absolute_url("search-index.json")}",
  "- Structured data graph: #{absolute_url("structured-data.json")}",
  "- RSS feed: #{absolute_url("feed.xml")}",
  "- Sitemap: #{absolute_url("sitemap.xml")}",
  "- Start order builder: #{absolute_url("start-order.html")}",
  "",
  "## Safety and proof boundary",
  "Do not treat public pages, issue drafts, estimates, samples, traffic, or tool usage as earned money. Count only external payment, payout, refund, credit, funded order, or payable-balance proof."
]
File.write(File.join(DOCS, "llms.txt"), llms_lines.join("\n"))

feed_items = (SERVICES.first(6) + ready_to_buy_offers + tool_rows).map do |item|
  if item.is_a?(Hash) && item.key?(:path)
    title = item[:title]
    link = absolute_url(item[:path])
    description = "Free tool leading to #{item[:service]} at #{item[:price]}. #{item[:proof_rule]}"
  elsif item.is_a?(Hash) && READY_TO_BUY_SLUGS.include?(item[:slug])
    title = "Ready To Buy: #{item[:title]}"
    link = absolute_url(ready_to_buy_path(item))
    description = "High-intent paid inquiry route for #{item[:price]} #{item[:title]}. #{item[:first_100]}"
  else
    title = item[:title]
    link = absolute_url("#{item[:slug]}.html")
    description = "#{item[:description]} #{item[:first_100]}"
  end
  <<~XML
    <item>
      <title>#{h(title)}</title>
      <link>#{h(link)}</link>
      <guid>#{h(link)}</guid>
      <pubDate>#{Time.now.rfc2822}</pubDate>
      <description>#{h(description)}</description>
    </item>
  XML
end.join
lead_feed_items = GITHUB_LEADS.map do |row|
  <<~XML
    <item>
      <title>GitHub lead repo: #{h(row["title"])}</title>
      <link>#{h(absolute_url("github-leads.html"))}</link>
      <guid>#{h(row["repo_url"])}</guid>
      <pubDate>#{Time.now.rfc2822}</pubDate>
      <description>#{h(row["first_100_path"])} Money still counts $0 until external payment proof exists.</description>
    </item>
  XML
end.join

File.write(File.join(DOCS, "feed.xml"), <<~XML)
  <?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0">
    <channel>
      <title>Micro Offer Studio Updates</title>
      <link>#{h(SITE_URL)}</link>
      <description>Generated offers, tools, and paid-inquiry paths. Confirmed earned money remains $0 until external proof exists.</description>
      <lastBuildDate>#{Time.now.rfc2822}</lastBuildDate>
      #{feed_items}
      #{lead_feed_items}
    </channel>
  </rss>
XML

File.write(File.join(DOCS, "sample-pack.json"), JSON.pretty_generate({
  generated_at_jst: GENERATED_AT,
  sample_pack: "micro-offer-studio-sample-pack.zip",
  bytes: sample_pack[:bytes],
  sha256: sample_pack[:sha256],
  files: sample_pack[:files],
  boundary: "Free sample only. Full paid bundles are not public and money remains unconfirmed until external proof exists."
}))

urls = ["", "buyer-intent-router.html", "buyer-intent-router.csv", "ready-to-buy.html", "buyer-response-playbook.html", "buyer-response-playbook.csv", "products.html", "services.html", "pricing.html", "tools.html", "order-now.html", "github-leads.html", "github_lead_repos.csv", "csv-cleaner-lite.html", "invoice-expense-snapshot.html", "prompt-workflow-brief-builder.html", "resale-listing-draft-builder.html", "proposal-profile-builder.html", "localization-qa-brief-builder.html", "subscription-savings-calculator.html", "content-repurposing-brief-builder.html", "technical-docs-audit-brief-builder.html", "pdf-table-intake-builder.html", "local-seo-gbp-brief-builder.html", "client-intake-sop-builder.html", "career-packet-brief-builder.html", "ai-workflow-tracker-brief-builder.html", "static-demo-site-brief-builder.html", "quote-estimator-scope-builder.html", "website-audit-lite.html", "workflow-blueprint-lite.html", "start-order.html", "case-studies.html", "samples.html", "order-boards.html", "proof-monitor.html", "fulfillment.html", "proof.html", "proposals.html", "buyer-faq.html", "share-kit.html", "indexnow.html", "llms.txt", "feed.xml", "search-index.json", "structured-data.json", "source-notes.html"] + OFFERS.map { |offer| "#{offer[:slug]}.html" } + ready_to_buy_offers.map { |offer| ready_to_buy_path(offer) }
urls = (urls + product_preview_tool_rows.map { |row| row[:path] }).uniq
indexnow_urls = urls.map { |path| URI.join(SITE_URL, path).to_s }
File.write(File.join(DOCS, INDEXNOW_KEY_FILE), INDEXNOW_KEY)
CSV.open(File.join(DOCS, "indexnow_urls.csv"), "w", write_headers: true, headers: %w[url]) do |csv|
  indexnow_urls.each { |url| csv << [url] }
end
indexnow_payload = {
  host: URI(SITE_URL).host,
  key: INDEXNOW_KEY,
  keyLocation: INDEXNOW_KEY_LOCATION,
  urlList: indexnow_urls
}
File.write(File.join(DOCS, "indexnow_payload.json"), JSON.pretty_generate(indexnow_payload))
File.write(File.join(DOCS, "indexnow.html"), page_shell("IndexNow - Micro Offer Studio", <<~HTML))
  <header><p class="buttons"><a href="index.html">Home</a><a href="sitemap.xml">Sitemap</a><a href="indexnow_urls.csv">URL CSV</a><a href="indexnow_payload.json">Payload JSON</a><a href="#{h(INDEXNOW_KEY_LOCATION)}">Key file</a></p><h1>IndexNow Discovery</h1><p class="muted">Search-index notification setup for the recently updated public offer site. This improves discovery only; it is not a payment event.</p></header>
  <section class="notice"><h2>Money boundary</h2><p>IndexNow submissions notify participating search engines about updated URLs. They do not guarantee indexing, traffic, buyer inquiries, payments, or payouts. Confirmed money remains $0 until external payment proof exists.</p></section>
  <section class="grid">
    <article class="panel"><h2>Verification key</h2><p><strong>Key file:</strong> <a href="#{h(INDEXNOW_KEY_LOCATION)}">#{h(INDEXNOW_KEY_FILE)}</a></p><p><strong>Key location:</strong> <code>#{h(INDEXNOW_KEY_LOCATION)}</code></p></article>
    <article class="panel"><h2>Submitted URL set</h2><p><strong>URL count:</strong> #{indexnow_urls.length}</p><p><strong>Host:</strong> #{h(URI(SITE_URL).host)}</p><p><strong>Scope:</strong> URLs under <code>#{h(SITE_URL)}</code></p></article>
  </section>
  <section><h2>High-priority URLs</h2><table><thead><tr><th>URL</th></tr></thead><tbody>#{indexnow_urls.first(20).map { |url| %(<tr><td data-label="URL"><a href="#{h(url)}">#{h(url)}</a></td></tr>) }.join}</tbody></table></section>
HTML
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
