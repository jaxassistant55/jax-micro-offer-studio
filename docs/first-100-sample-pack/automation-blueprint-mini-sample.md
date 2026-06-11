# Automation Blueprint Mini - Synthetic Sample

Workflow: weekly lead CSV cleanup from a public contact form export.

Current state:
- Owner exports a CSV each Monday.
- Rows have inconsistent company names, empty source fields, and duplicate emails.
- Owner manually filters rows before importing into a CRM.

Target flow:
1. Drop buyer-authorized CSV into a local folder.
2. Run a local cleanup script that normalizes company names, validates email shape, deduplicates by email, and writes rejected rows.
3. Review the QA summary before CRM import.

Risk notes:
- Do not process private customer data in public threads.
- Keep original exports unchanged.
- Confirm duplicate rules before deletion.

Next action list:
- Confirm CSV columns.
- Confirm duplicate key.
- Confirm acceptable rejection reasons.
- Deliver workflow map, field mapping, and test checklist.
