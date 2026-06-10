#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "json"
require "open3"
require "tempfile"
require "time"

ENV["TZ"] = "Asia/Tokyo"

REPO = "jaxassistant55/jax-micro-offer-studio"
LAUNCH_ROOT = File.expand_path("..", __dir__)
SITE_URL = "https://jaxassistant55.github.io/jax-micro-offer-studio"
ISSUE_BOARD_URL = "https://github.com/#{REPO}/issues/1"
GENERATED_AT = Time.now.strftime("%Y-%m-%d %H:%M:%S JST")

OFFERS = [
  ["service", "Automation Blueprint", "$100", "automation-blueprint.html", "One accepted workflow blueprint reaches $100.", "Trigger, field mapping, workflow steps, failure cases, and test plan."],
  ["service", "Data Cleanup Sprint", "$125", "data-cleanup-sprint.html", "One authorized cleanup sprint clears $100.", "Authorized CSV/spreadsheet cleanup with validation counts and QA report."],
  ["service", "Website Audit Microservice", "$150", "website-audit-microservice.html", "One accepted public-site audit clears $100.", "Public website audit covering mobile, copy, accessibility, broken links, and quick wins."],
  ["service", "AI Workflow Tracker Sprint", "$150", "ai-workflow-tracker-sprint.html", "One fixed-price tracker order clears $100.", "CSV-backed tracker plus static dashboard for leads, grants, interviews, or sales pipelines."],
  ["service", "Static Demo Site Customization", "$200", "static-demo-site-customization.html", "One starter site clears $100.", "One-page local-service starter site customization."],
  ["service", "Niche Quote Estimator", "$150", "niche-quote-estimator.html", "One custom estimator clears $100.", "Browser-only quote estimator customized to simple service pricing."],
  ["product", "Browser Extension Template", "$29", "browser-extension-template.html", "Four paid transfers clears $100 gross.", "Manifest V3 extension starter with popup UI and local storage."],
  ["product", "Mini Course Workbook", "$29", "mini-course-workbook.html", "Four paid transfers clears $100 gross.", "Self-study workbook and checklist for a simple digital product offer."],
  ["product", "Synthetic Mock Dataset Pack", "$19", "synthetic-mock-dataset-pack.html", "Six paid transfers clears $100 gross.", "Synthetic CSV/JSON datasets plus dashboard and data dictionary."],
  ["product", "CSV CLI Toolkit", "$19", "csv-cli-toolkit.html", "Six paid transfers clears $100 gross.", "Ruby CSV profiling and cleanup CLI with sample input."]
].freeze

def gh_json(args, payload = nil)
  cmd = ["gh", "api", *args]
  if payload
    Tempfile.create(["gh-payload", ".json"]) do |file|
      file.write(JSON.generate(payload))
      file.flush
      stdout, stderr, status = Open3.capture3(*cmd, "--input", file.path)
      raise stderr unless status.success?

      return stdout.empty? ? nil : JSON.parse(stdout)
    end
  else
    stdout, stderr, status = Open3.capture3(*cmd)
    raise stderr unless status.success?

    stdout.empty? ? nil : JSON.parse(stdout)
  end
end

def ensure_label(name, color, description)
  gh_json(["repos/#{REPO}/labels/#{name}"])
rescue StandardError
  gh_json(["--method", "POST", "repos/#{REPO}/labels"], {
    name: name,
    color: color,
    description: description
  })
end

ensure_label("order-board", "075DA8", "Specific public order board for a paid offer")
ensure_label("service-order", "17643A", "Service order inquiry")
ensure_label("product-transfer", "5F3B88", "Product transfer inquiry")

issues = gh_json(["repos/#{REPO}/issues?state=all&per_page=100"])
existing_by_title = issues.to_h { |issue| [issue["title"], issue] }

rows = []
OFFERS.each do |type, title, price, detail_path, first_100, scope|
  issue_title = "Order board: #{title} (#{price})"
  issue = existing_by_title[issue_title]
  body = <<~MD
    Specific order board for **#{title}**.

    - Type: #{type}
    - Price: #{price}
    - Detail page: #{SITE_URL}/#{detail_path}
    - Fulfillment ledger: #{SITE_URL}/fulfillment.html
    - Proof rules: #{SITE_URL}/proof.html
    - Main first $100 board: #{ISSUE_BOARD_URL}

    ## Scope

    #{scope}

    ## Path to $100

    #{first_100}

    ## To proceed

    Comment here or open the structured issue template with:

    1. Desired scope or product transfer.
    2. Budget/payment route.
    3. Deadline.
    4. Acceptance proof that will show the work is complete and payable.

    ## Safety boundary

    Do not post passwords, payment cards, tax identifiers, regulated private information, or files you are not authorized to share. Money is counted only from external proof such as a paid order, cleared invoice, funded milestone, payable balance, posted refund/credit, or equivalent.
  MD

  unless issue
    labels = ["order-board", type == "service" ? "service-order" : "product-transfer", "paid-inquiry", "needs-scope"]
    issue = gh_json(["--method", "POST", "repos/#{REPO}/issues"], {
      title: issue_title,
      body: body,
      labels: labels
    })
  end

  rows << {
    "generated_at_jst" => GENERATED_AT,
    "type" => type,
    "title" => title,
    "price" => price,
    "first_100_path" => first_100,
    "detail_url" => "#{SITE_URL}/#{detail_path}",
    "issue_number" => issue["number"],
    "issue_url" => issue["html_url"],
    "state" => issue["state"],
    "comments" => issue["comments"],
    "money_confirmed_usd" => "0"
  }
end

CSV.open(File.join(LAUNCH_ROOT, "order_boards.csv"), "w", write_headers: true, headers: rows.first.keys) do |csv|
  rows.each { |row| csv << row.values_at(*rows.first.keys) }
end

puts "Wrote #{rows.length} order boards to #{File.join(LAUNCH_ROOT, "order_boards.csv")}"
