#!/usr/bin/env python3
"""Build one evidence report PDF per portfolio evidence folder.

Input:  portfolio-*/evidence/script-output/*.txt (written by scripts/init_and_evidence.sh
        and scripts/nosql_evidence.sh), hand-written portfolio-*/evidence/*.txt notes,
        and the screenshots under portfolio-*/evidence/screenshots/
Output: portfolio-*/evidence/evidence-report.pdf

Usage (from the repo root or anywhere):
    python3 scripts/build_evidence_pdfs.py            # all portfolios
    python3 scripts/build_evidence_pdfs.py 2 4        # only portfolios 2 and 4

Dependencies:
  - Python 3.9+ (standard library only)
  - WeasyPrint 60+ (pip install weasyprint; on macOS also: brew install pango)
  - Fonts: Merriweather, Open Sans and JetBrains Mono. They are loaded from
    Google Fonts (internet needed) and fall back to locally installed copies,
    then to Georgia / Helvetica / Menlo.

The txt files are reproduced verbatim and every screenshot listed below is
embedded; nothing in the evidence folders is modified or removed.
"""
import html
import re
import struct
import sys
import tempfile
from pathlib import Path

try:
    from weasyprint import HTML
except ImportError:
    raise SystemExit("WeasyPrint is required: pip install weasyprint (macOS: brew install pango)")

ROOT = Path(__file__).resolve().parent.parent

# ----------------------------------------------------------------------------
# Report definitions. Item types:
#   ("h", "Sub heading")
#   ("img", "path relative to portfolio folder", "caption")
#   ("txt", "file in evidence/script-output/", "header substring" or None for whole file)
# ----------------------------------------------------------------------------
P1 = {
    "dir": "portfolio-1-database-design",
    "title": "Portfolio 1: Database Design",
    "sections": [
        ("Entity relationship diagram", [
            ("img", "valpay-erd-dbeaver.png",
             "ValPay ER diagram exported from DBeaver: seven tables with columns, data types, primary keys and relationships."),
            ("img", "evidence/screenshots/02-er-diagram.png",
             "DBeaver Diagram tab for the public schema of the valpay database."),
        ]),
        ("Tables and columns", [
            ("img", "evidence/screenshots/01-schema-tables.png",
             "DBeaver table editor: wallet_transaction columns, data types, defaults and NOT NULL settings."),
        ]),
        ("Constraints and indexes", [
            ("img", "evidence/screenshots/03-constraints-indexes.png",
             "DBeaver: wallet_account constraints, including the foreign key to customer."),
            ("img", "evidence/screenshots/03b-indexes.png",
             "DBeaver: wallet_transaction indexes, including idx_transaction_reference (text_pattern_ops)."),
        ]),
        ("Schema dump (pg_dump --schema-only)", [
            ("txt", "schema_dump.txt", None),
        ]),
    ],
}

P2 = {
    "dir": "portfolio-2-query-optimisation",
    "title": "Portfolio 2: Query Optimisation",
    "sections": [
        ("Query results", [
            ("h", "Q1. Wallet statement for a customer"),
            ("img", "evidence/screenshots/q1-wallet-statement.png",
             "Q1 in DBeaver: wallet statement for valentine.efagene@example.com, newest first."),
            ("txt", "query_results.txt", "Q1:"),
            ("h", "Q2. Daily successful transfer volume"),
            ("img", "evidence/screenshots/q2-daily-volume.png",
             "Q2 in DBeaver: successful transfer count and total amount per day for the latest 14 days."),
            ("txt", "query_results.txt", "Q2:"),
            ("h", "Q3. Lookup by reference prefix"),
            ("img", "evidence/screenshots/q3-reference-lookup.png",
             "Q3 in DBeaver: latest 20 transactions whose reference starts with VP-TXN-202610."),
            ("txt", "query_results.txt", "Q3:"),
            ("h", "Q4. Accounts below the monitoring threshold"),
            ("img", "evidence/screenshots/q4-low-balance.png",
             "Q4 in DBeaver: active accounts with a balance below the internal threshold."),
            ("txt", "query_results.txt", "Q4:"),
            ("h", "Q5. Pending or failed transactions"),
            ("img", "evidence/screenshots/q5-pending-failed.png",
             "Q5 in DBeaver: PENDING and FAILED transactions for operations review."),
            ("txt", "query_results.txt", "Q5:"),
            ("h", "Q6. Ledger reconciliation"),
            ("img", "evidence/screenshots/q6-ledger-reconciliation.png",
             "Q6 in DBeaver: accounts checked against CREDIT minus DEBIT postings, with the mismatch count."),
            ("txt", "query_results.txt", "Q6:"),
        ]),
        ("Execution plans", [
            ("h", "Q3 before idx_transaction_reference"),
            ("img", "evidence/screenshots/explain-q3-before.png",
             "Q3 before the index: sequential scan on wallet_transaction."),
            ("txt", "explain_plans.txt", "Q3 BEFORE"),
            ("h", "Q3 after idx_transaction_reference"),
            ("img", "evidence/screenshots/explain-q3-after.png",
             "Q3 after the index: bitmap index scan on idx_transaction_reference."),
            ("txt", "explain_plans.txt", "Q3 AFTER"),
            ("h", "Q1 join plan"),
            ("img", "evidence/screenshots/explain-q1-join.png",
             "Q1 plan: nested loops using idx_ledger_account and wallet_transaction_pkey."),
            ("txt", "explain_plans.txt", "EXPLAIN Q1"),
        ]),
    ],
}

P3 = {
    "dir": "portfolio-3-transactions-concurrency",
    "title": "Portfolio 3: Transactions and Concurrency",
    "sections": [
        ("Balances before the tests", [
            ("img", "evidence/screenshots/01-balances-before.png",
             "Balances of accounts VP1000000001, VP1000000002 and VP9999999999 before the transfer tests."),
            ("txt", "transaction_run.txt", "Balances before"),
        ]),
        ("Test A: failed transfer and rollback", [
            ("img", "evidence/screenshots/02a-test-a-update-zero-rows.png",
             "Test A: the guarded balance UPDATE for 999,999.00 NGN affects 0 rows."),
            ("img", "evidence/screenshots/02-test-a-rollback.png",
             "Test A after ROLLBACK: no wallet_transaction row with reference VP-TXN-FAIL-001."),
            ("img", "evidence/screenshots/02b-balance-unchanged.png",
             "Test A after ROLLBACK: balance of account 1 unchanged."),
            ("txt", "transaction_run.txt", "Test A"),
        ]),
        ("Test B: successful transfer and commit", [
            ("img", "evidence/screenshots/03-test-b-commit.png",
             "Test B: the 2,500 NGN transfer script from account 1 to account 2 executed and committed."),
            ("txt", "transaction_run.txt", "Test B"),
            ("img", "evidence/screenshots/04-after-transfer.png",
             "After Test B: VP-TXN-OK-004 with status SUCCESS and the new balances of both accounts."),
            ("txt", "transaction_run.txt", "After successful"),
        ]),
    ],
}

S = "evidence/screenshots/"
C = "evidence/screenshots/compass/"
P4 = {
    "dir": "portfolio-4-nosql",
    "title": "Portfolio 4: NoSQL (MongoDB)",
    "sections": [
        ("Seed load", [
            ("img", C + "c01-databases-collections.png",
             "MongoDB Compass: collections in the valpay database with document counts."),
            ("img", S + "01_seed_load_summary.png",
             "mongosh: seed load summary with document counts, breakdowns and indexes."),
            ("txt", "load_summary.txt", None),
        ]),
        ("Index evidence (explain)", [
            ("h", "Customer timeline and transfer window"),
            ("img", S + "02_explain_timeline_and_window.png",
             "mongosh: explain() for the customer timeline and the transfer_initiated window, before and after indexing."),
            ("txt", "explain_plans.txt", "E1."),
            ("txt", "explain_plans.txt", "E2."),
            ("img", C + "c07-activity-indexes.png",
             "MongoDB Compass: indexes on activity_events."),
            ("img", C + "c08-activity-explain.png",
             "MongoDB Compass: explain plan for the customer timeline query using an index scan."),
            ("h", "Reference trace and pending KYC queue"),
            ("img", S + "03_explain_reference_and_pending_queue.png",
             "mongosh: explain() for the reference trace and the pending KYC queue with its partial index."),
            ("txt", "explain_plans.txt", "E3."),
            ("txt", "explain_plans.txt", "E4."),
            ("txt", "explain_plans.txt", "Partial index coverage"),
            ("txt", "explain_plans.txt", "not used for VERIFIED"),
            ("img", C + "c05-kyc-indexes.png",
             "MongoDB Compass: indexes on kyc_documents, including the partial pending_review_queue index."),
        ]),
        ("Schema validation", [
            ("img", C + "c06-kyc-validation.png",
             "MongoDB Compass: $jsonSchema validation rules on kyc_documents."),
            ("img", S + "04_validation_enum_rejection.png",
             "mongosh: insert with an unknown document type rejected by the validator."),
            ("img", S + "05_validation_rejected_rule_and_valid_insert.png",
             "mongosh: REJECTED document without rejection_reason refused, then a valid PASSPORT insert accepted."),
            ("txt", "validation_rejection.txt", "V1."),
            ("txt", "validation_rejection.txt", "V2."),
            ("txt", "validation_rejection.txt", "V3."),
            ("txt", "validation_rejection.txt", "V4."),
            ("txt", "validation_rejection.txt", "V5."),
        ]),
        ("KYC queries", [
            ("img", C + "c02-kyc-documents.png",
             "MongoDB Compass: documents in kyc_documents."),
            ("img", C + "c03-kyc-filter-pending.png",
             "MongoDB Compass: kyc_documents filtered on status PENDING."),
            ("img", C + "c04-kyc-schema.png",
             "MongoDB Compass: schema analysis of kyc_documents."),
            ("img", S + "06_kyc_queue_funnel_tiers.png",
             "mongosh: KYC review queue, funnel by document type and status, rejection reasons and derived tiers (Q1 to Q4)."),
            ("txt", "query_results.txt", "Q1."),
            ("txt", "query_results.txt", "Q2."),
            ("txt", "query_results.txt", "Q3."),
            ("txt", "query_results.txt", "Q4."),
        ]),
        ("Activity queries", [
            ("img", S + "08_timeline_window_trace.png",
             "mongosh: customer timeline, transfers initiated 1 to 7 October 2026 and the VP-TXN-OK-004 trace (Q5, Q6, Q11)."),
            ("txt", "query_results.txt", "Q5."),
            ("txt", "query_results.txt", "Q6."),
            ("txt", "query_results.txt", "Q11."),
        ]),
        ("Fraud queries", [
            ("img", C + "c09-fraud-aggregation.png",
             "MongoDB Compass: aggregation of fraud_rule_hit events grouped by rule, with hits and average score."),
            ("img", C + "c10-fraud-signals.png",
             "MongoDB Compass: documents in fraud_signals."),
            ("img", S + "07_fraud_rules_and_risky_devices.png",
             "mongosh: fraud rule hits by rule and the top risky devices."),
            ("txt", "query_results.txt", "Q7."),
            ("txt", "query_results.txt", "Q8."),
            ("txt", "query_results.txt", "Q9."),
            ("txt", "query_results.txt", "Q10."),
            ("txt", "query_results.txt", "Q12."),
        ]),
        ("Cross-store check with PostgreSQL", [
            ("img", S + "09_runner_and_cross_store_check.png",
             "Evidence runner output and the cross-store check between MongoDB and PostgreSQL."),
            ("txt", "cross_store_check.txt", None),
        ]),
    ],
}

P5 = {
    "dir": "portfolio-5-distributed-cloud",
    "title": "Portfolio 5: Distributed and Cloud Deployment",
    "sections": [
        ("Connection notes", [
            ("txt", "connection_notes.txt", None),
        ]),
    ],
}

REPORTS = {1: P1, 2: P2, 3: P3, 4: P4, 5: P5}

# ----------------------------------------------------------------------------
# Layout constants (mm / pt)
# ----------------------------------------------------------------------------
PORTRAIT_TEXT_W_PT = (210 - 36) * 72 / 25.4 - 24  # 18 mm margins, less code-block padding
LANDSCAPE_TEXT_W_PT = (297 - 30) * 72 / 25.4 - 24  # 15 mm margins, less code-block padding
MONO_ADVANCE = 0.6                               # JetBrains Mono em advance
MAX_FS, MIN_FS = 8.0, 6.3
WIDE_IMAGE_PX = 1400                             # wider images get a landscape page

SCRIPT_OUTPUT = "script-output"                   # generated txt files live here
HEADER_RE = re.compile(r"^(===|---) .*(===|---)\s*$")


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


def split_chunks(text):
    """Split txt output into chunks at '=== x ===' / '--- x ---' headers.
    Lines before the first header are kept with the first chunk."""
    lines = text.splitlines()
    starts = [i for i, l in enumerate(lines) if HEADER_RE.match(l)]
    if not starts:
        return [(None, text.strip("\n"))]
    chunks = []
    bounds = starts + [len(lines)]
    for n, s in enumerate(starts):
        a = 0 if n == 0 else s
        chunks.append((lines[s], "\n".join(lines[a:bounds[n + 1]]).strip("\n")))
    return chunks


def code_layout(text):
    """Return (font size pt, landscape?) so most lines fit without wrapping."""
    lengths = sorted(len(l.expandtabs(8)) for l in text.splitlines()) or [0]
    ref = lengths[int(0.95 * (len(lengths) - 1))]
    ref = max(ref, 1)
    fs_p = PORTRAIT_TEXT_W_PT / (ref * MONO_ADVANCE)
    if fs_p >= MIN_FS:
        return min(MAX_FS, fs_p), False
    fs_l = LANDSCAPE_TEXT_W_PT / (ref * MONO_ADVANCE)
    return max(MIN_FS, min(MAX_FS, fs_l)), True


CSS = """
@page { size: A4 portrait; margin: 16mm 18mm 18mm 18mm;
  @bottom-left { content: "ValPay · %(short)s · Evidence report"; font: 7.5pt 'Open Sans', Helvetica, sans-serif; color: #7a7a7a; }
  @bottom-right { content: "Page " counter(page) " of " counter(pages); font: 7.5pt 'Open Sans', Helvetica, sans-serif; color: #7a7a7a; }
}
@page land { size: A4 landscape; margin: 13mm 15mm 15mm 15mm; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { font-family: 'Merriweather', Georgia, serif; font-size: 9.5pt; line-height: 1.55; color: #333; margin: 0; }
.land { page: land; }
.title { margin: 0 0 4mm 0; padding-bottom: 4mm; border-bottom: 1.2pt solid #2079c7; }
.title h1 { font-family: 'Open Sans', Helvetica, sans-serif; font-weight: 700; font-size: 24pt; line-height: 1.2; color: #434343; margin: 0 0 2mm 0; }
.title .sub { font-family: 'Open Sans', Helvetica, sans-serif; font-size: 10.5pt; color: #2079c7; margin: 0; }
.title .name { font-size: 10pt; color: #434343; margin: 2mm 0 0 0; font-weight: 700; }
h2 { font-family: 'Open Sans', Helvetica, sans-serif; font-weight: 700; font-size: 10.5pt; letter-spacing: 0.06em; text-transform: uppercase; color: #2079c7; margin: 0 0 3mm 0; padding-bottom: 1.2mm; border-bottom: 0.6pt solid #d5e3f1; break-after: avoid; }
h2.brk { break-before: page; }
h3 { font-family: 'Open Sans', Helvetica, sans-serif; font-weight: 700; font-size: 9pt; color: #434343; margin: 5mm 0 2mm 0; break-after: avoid; }
.contents h2 { margin-top: 6mm; }
.contents ol { margin: 0 0 0 5mm; padding: 0; }
.contents li { margin: 0.6mm 0; }
.contents a { color: #333; text-decoration: none; }
.sources { font-size: 8.5pt; color: #555; }
.sources code, .src code { font-family: 'JetBrains Mono', 'DejaVu Sans Mono', Menlo, monospace; font-size: 0.92em; }
.sources code { white-space: nowrap; }
figure { margin: 0 0 6mm 0; break-inside: avoid; text-align: center; }
figure img { max-width: 100%%; border: 0.5pt solid #c9c9c9; }
.p figure img { max-height: 215mm; }
.land figure img { max-height: 150mm; }
figcaption { font-size: 8.3pt; font-style: italic; color: #555; margin-top: 1.8mm; text-align: left; }
figcaption b { font-style: normal; color: #434343; }
.src { font-family: 'Open Sans', Helvetica, sans-serif; font-size: 7.5pt; color: #7a7a7a; margin: 3mm 0 1mm 0; break-after: avoid; }
pre { font-family: 'JetBrains Mono', 'DejaVu Sans Mono', Menlo, monospace; background: #f4f5f7; border: 0.5pt solid #e1e4e8; border-radius: 2pt; padding: 2.5mm 3mm; margin: 0 0 4mm 0; white-space: pre-wrap; overflow-wrap: anywhere; line-height: 1.35; color: #24292e; font-variant-ligatures: none; font-feature-settings: 'liga' 0, 'calt' 0; }
"""


def esc(s):
    return html.escape(s, quote=True)


def build(num, spec, keep_html=False):
    pdir = ROOT / spec["dir"]
    evdir = pdir / "evidence"
    short = spec["title"].split(":")[0]
    outdir = evdir / SCRIPT_OUTPUT
    txt_cache, used = {}, {}

    def rel(fname):
        """Path of a txt file relative to evidence/: script output first, then hand-written notes."""
        if (outdir / fname).exists():
            return f"{SCRIPT_OUTPUT}/{fname}"
        if (evdir / fname).exists():
            return fname
        raise SystemExit(f"{spec['dir']}: {fname} not found in evidence/{SCRIPT_OUTPUT}/ or evidence/")

    def chunk(fname, match):
        if fname not in txt_cache:
            txt_cache[fname] = split_chunks((evdir / rel(fname)).read_text(encoding="utf-8"))
            used[fname] = set()
        chunks = txt_cache[fname]
        for i, (hdr, body) in enumerate(chunks):
            if match is None or (hdr and match in hdr):
                if match is None:
                    used[fname].update(range(len(chunks)))
                    return "\n\n".join(b for _, b in chunks)
                used[fname].add(i)
                return body
        raise SystemExit(f"{spec['dir']}: no chunk matching {match!r} in {fname}")

    # Render each section to a list of (orientation, html) blocks.
    fig_no = 0
    body_parts = []
    toc = []
    sources = set()
    for sn, (stitle, items) in enumerate(spec["sections"], 1):
        anchor = f"s{sn}"
        toc.append((anchor, f"{sn}. {stitle}"))
        blocks = []
        pending_h = []
        for it in items:
            if it[0] == "h":
                pending_h.append(f"<h3>{esc(it[1])}</h3>")
                continue
            if it[0] == "img":
                path = pdir / it[1]
                if not path.exists():
                    raise SystemExit(f"missing image {path}")
                sources.add(it[1])
                w, h = png_size(path)
                land = w >= WIDE_IMAGE_PX
                fig_no += 1
                style = ""
                if not land:
                    # portrait: scale to text width, but keep small images near native size
                    mm = min(174, w * 0.19)
                    style = f' style="width:{mm:.0f}mm"'
                html_ = (f'<figure><img src="{path.as_uri()}"{style} alt="">'
                         f'<figcaption><b>Figure {fig_no}.</b> {esc(it[2])}</figcaption></figure>')
            else:
                text = chunk(it[1], it[2])
                sources.add(rel(it[1]))
                fs, land = code_layout(text)
                html_ = (f'<div class="src">Source: <code>evidence/{esc(rel(it[1]))}</code></div>'
                         f'<pre style="font-size:{fs:.2f}pt">{esc(text)}</pre>')
            blocks.append(("land" if land else "p", "".join(pending_h) + html_))
            pending_h = []
        if pending_h:
            blocks.append(("p", "".join(pending_h)))
        # attach the section heading to the first block
        brk = ' class="brk"' if sn > 1 else ""
        o, first = blocks[0]
        blocks[0] = (o, f'<h2 id="{anchor}"{brk}>{sn}. {esc(stitle)}</h2>' + first)
        body_parts.extend(blocks)

    # Any txt chunk not referenced explicitly goes into a final section so nothing is lost.
    extra = []
    for fname, chunks in txt_cache.items():
        for i, (hdr, body) in enumerate(chunks):
            if i not in used[fname]:
                fs, land = code_layout(body)
                extra.append(("land" if land else "p",
                              f'<div class="src">Source: <code>evidence/{esc(rel(fname))}</code></div>'
                              f'<pre style="font-size:{fs:.2f}pt">{esc(body)}</pre>'))
    all_txt = sorted({p.name for p in outdir.glob("*.txt")} | {p.name for p in evdir.glob("*.txt")})
    for f in all_txt:
        if f not in txt_cache:
            body = (evdir / rel(f)).read_text(encoding="utf-8").strip("\n")
            fs, land = code_layout(body)
            sources.add(rel(f))
            extra.append(("land" if land else "p",
                          f'<div class="src">Source: <code>evidence/{esc(rel(f))}</code></div>'
                          f'<pre style="font-size:{fs:.2f}pt">{esc(body)}</pre>'))
    if extra:
        sn = len(spec["sections"]) + 1
        toc.append((f"s{sn}", f"{sn}. Additional output"))
        o, first = extra[0]
        extra[0] = (o, f'<h2 id="s{sn}" class="brk">{sn}. Additional output</h2>' + first)
        body_parts.extend(extra)

    n_img = fig_no
    gen = sorted(Path(t).name for t in sources if t.startswith(SCRIPT_OUTPUT + "/"))
    notes = sorted(t for t in sources if t.endswith(".txt") and "/" not in t)
    parts = []
    if n_img:
        parts.append(f'{n_img} screenshot{"s" if n_img != 1 else ""} in <code>screenshots/</code>')
    if gen:
        parts.append("script output in <code>" + SCRIPT_OUTPUT + "/</code> ("
                     + ", ".join(f"<code>{esc(t)}</code>" for t in gen) + ")")
    if notes:
        parts.append("notes in " + ", ".join(f"<code>{esc(t)}</code>" for t in notes))
    compiled = (" and ".join(parts) if len(parts) < 3
                else ", ".join(parts[:-1]) + " and " + parts[-1])
    head = (
        '<div class="p"><div class="title">'
        f'<h1>ValPay {esc(spec["title"])}</h1>'
        '<p class="sub">MIT 8103 Advanced Database Systems · Evidence</p>'
        '<p class="name">Valentine Efagene</p></div>'
        '<div class="contents"><h2>Contents</h2><ol>'
        + "".join(f'<li><a href="#{a}">{esc(t.split(". ", 1)[1])}</a></li>' for a, t in toc)
        + '</ol>'
        f'<p class="sources">Compiled from <code>{esc(spec["dir"])}/evidence</code>: '
        + compiled + '. Text output is reproduced verbatim.</p></div></div>'
    )

    # Group consecutive blocks of the same orientation into page containers.
    groups = []
    for o, h in body_parts:
        if groups and groups[-1][0] == o:
            groups[-1][1].append(h)
        else:
            groups.append((o, [h]))
    if groups and groups[0][0] == "p":
        # first section flows on after the contents on page 1
        groups[0] = ("p", [groups[0][1][0].replace(' class="brk"', '', 1)] + groups[0][1][1:])
    body = head + "".join(f'<div class="{o}">' + "".join(hs) + "</div>" for o, hs in groups)

    doc = (
        '<!doctype html><html lang="en-GB"><head><meta charset="utf-8">'
        f'<title>ValPay {esc(spec["title"])}: Evidence</title>'
        '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
        'family=Merriweather:ital,wght@0,400;0,700;1,400&family=Open+Sans:wght@400;600;700'
        '&family=JetBrains+Mono:wght@400&display=block">'
        f'<style>{CSS % {"short": short}}</style></head><body>{body}</body></html>'
    )

    out = evdir / "evidence-report.pdf"
    if keep_html:
        (Path(tempfile.gettempdir()) / f"evidence-p{num}.html").write_text(doc, encoding="utf-8")
    HTML(string=doc, base_url=str(pdir)).write_pdf(out)
    print(f"wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    nums = [int(a) for a in sys.argv[1:] if a.isdigit()] or sorted(REPORTS)
    for n in nums:
        build(n, REPORTS[n], keep_html="--keep-html" in sys.argv)
