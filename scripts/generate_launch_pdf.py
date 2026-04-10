"""Generate the 0pnMatrx Launch Manual PDF.

Creates a professionally formatted PDF containing every step, piece of copy,
and command needed to launch the platform.
"""

import os
import sys
from datetime import datetime

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib.colors import HexColor, white, black
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
    KeepTogether, HRFlowable,
)


# ── Colors ──────────────────────────────────────────────────────────────
GREEN = HexColor("#00ff41")
DARK_GREEN = HexColor("#003b00")
BG_DARK = HexColor("#0a0a0a")
BG_CARD = HexColor("#141414")
BORDER = HexColor("#1e1e1e")
TEXT_MAIN = HexColor("#333333")
TEXT_MUTED = HexColor("#666666")
ACCENT_BG = HexColor("#f0fff0")
CODE_BG = HexColor("#f5f5f5")
COPY_BG = HexColor("#fffff0")
WARN_BG = HexColor("#fff8f0")


def build_styles():
    """Create all paragraph styles for the PDF."""
    ss = getSampleStyleSheet()
    styles = {}

    styles["cover_title"] = ParagraphStyle(
        "CoverTitle", parent=ss["Title"],
        fontSize=32, leading=40, textColor=HexColor("#111111"),
        alignment=TA_CENTER, spaceAfter=12,
    )
    styles["cover_sub"] = ParagraphStyle(
        "CoverSub", parent=ss["Normal"],
        fontSize=14, leading=20, textColor=TEXT_MUTED,
        alignment=TA_CENTER, spaceAfter=6,
    )
    styles["cover_date"] = ParagraphStyle(
        "CoverDate", parent=ss["Normal"],
        fontSize=11, leading=16, textColor=TEXT_MUTED,
        alignment=TA_CENTER, spaceAfter=4,
    )
    styles["section_num"] = ParagraphStyle(
        "SectionNum", parent=ss["Heading1"],
        fontSize=22, leading=28, textColor=HexColor("#006600"),
        spaceBefore=20, spaceAfter=6,
    )
    styles["section_title"] = ParagraphStyle(
        "SectionTitle", parent=ss["Heading1"],
        fontSize=18, leading=24, textColor=HexColor("#111111"),
        spaceBefore=16, spaceAfter=8,
    )
    styles["subsection"] = ParagraphStyle(
        "Subsection", parent=ss["Heading2"],
        fontSize=14, leading=18, textColor=HexColor("#222222"),
        spaceBefore=14, spaceAfter=6,
    )
    styles["body"] = ParagraphStyle(
        "Body", parent=ss["Normal"],
        fontSize=11, leading=15, textColor=TEXT_MAIN,
        alignment=TA_LEFT, spaceAfter=8,
    )
    styles["body_small"] = ParagraphStyle(
        "BodySmall", parent=ss["Normal"],
        fontSize=9.5, leading=13, textColor=TEXT_MAIN,
        alignment=TA_LEFT, spaceAfter=6,
    )
    styles["code"] = ParagraphStyle(
        "Code", parent=ss["Normal"],
        fontName="Courier", fontSize=9, leading=12,
        textColor=HexColor("#333333"),
        spaceAfter=4, leftIndent=8,
    )
    styles["box_label"] = ParagraphStyle(
        "BoxLabel", parent=ss["Normal"],
        fontName="Helvetica-Bold", fontSize=9, leading=12,
        textColor=HexColor("#006600"), spaceAfter=2,
    )
    styles["copy_text"] = ParagraphStyle(
        "CopyText", parent=ss["Normal"],
        fontSize=10, leading=14, textColor=TEXT_MAIN,
        spaceAfter=4, leftIndent=6, rightIndent=6,
    )
    styles["toc_entry"] = ParagraphStyle(
        "TocEntry", parent=ss["Normal"],
        fontSize=11, leading=16, textColor=TEXT_MAIN,
        spaceAfter=3, leftIndent=20,
    )
    styles["toc_section"] = ParagraphStyle(
        "TocSection", parent=ss["Normal"],
        fontName="Helvetica-Bold", fontSize=12, leading=18,
        textColor=HexColor("#006600"), spaceAfter=4,
    )
    styles["tweet"] = ParagraphStyle(
        "Tweet", parent=ss["Normal"],
        fontSize=10, leading=14, textColor=TEXT_MAIN,
        spaceAfter=2, leftIndent=6,
    )
    styles["email_body"] = ParagraphStyle(
        "EmailBody", parent=ss["Normal"],
        fontSize=10, leading=14, textColor=TEXT_MAIN,
        spaceAfter=4, leftIndent=6,
    )
    return styles


def copy_box(label, text, styles, bg=COPY_BG):
    """Create a bordered 'COPY THIS' box."""
    content = []
    content.append(Paragraph(label, styles["box_label"]))
    # Handle multi-line text
    for line in text.split("\n"):
        if line.strip():
            safe = line.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            content.append(Paragraph(safe, styles["copy_text"]))
        else:
            content.append(Spacer(1, 4))

    t = Table([[content]], colWidths=[6.5 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("BOX", (0, 0), (-1, -1), 1, HexColor("#ccccaa")),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
    ]))
    return t


def run_box(label, cmd, styles):
    """Create a bordered 'RUN THIS' code box."""
    content = []
    content.append(Paragraph(label, styles["box_label"]))
    for line in cmd.split("\n"):
        safe = line.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        content.append(Paragraph(safe, styles["code"]))

    t = Table([[content]], colWidths=[6.5 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), CODE_BG),
        ("BOX", (0, 0), (-1, -1), 1, HexColor("#cccccc")),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
    ]))
    return t


def tier_table(styles):
    """GitHub Sponsors tier table."""
    data = [
        ["Tier", "Price", "Description"],
        ["Community Supporter", "$5/mo", "Name in README, Discord role"],
        ["Platform Backer", "$25/mo", "Logo in README, early access"],
        ["Builder", "$100/mo", "Logo + link, feature votes, private channel"],
        ["Infrastructure Partner", "$500/mo", "Large logo, roadmap influence, monthly call"],
        ["Founding Sponsor", "$2,500/mo", "Top placement, co-marketing, dedicated support"],
    ]
    t = Table(data, colWidths=[1.8 * inch, 1 * inch, 3.7 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), HexColor("#006600")),
        ("TEXTCOLOR", (0, 0), (-1, 0), white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.5, HexColor("#cccccc")),
        ("BACKGROUND", (0, 1), (-1, -1), white),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    return t


def revenue_table(styles):
    """14-stream revenue table."""
    data = [
        ["#", "Stream", "Type", "Est. MRR @ 1K Users"],
        ["1", "Pro subscriptions", "Recurring", "$499"],
        ["2", "Enterprise subscriptions", "Recurring", "$400"],
        ["3", "Glasswing audits", "One-time", "$2,990"],
        ["4", "Template packs", "One-time", "$490"],
        ["5", "Plugin marketplace", "Rev share", "Variable"],
        ["6", "GitHub Sponsors", "Donation", "Variable"],
        ["7", "Referral credits", "Growth", "Reduces CAC"],
        ["8", "Metered API", "Usage", "Variable"],
        ["9", "Protocol referrals", "Automatic", "% of volume"],
        ["10", "Glasswing badges", "Annual", "$412"],
        ["11", "Certification exams", "One-time", "$1,000"],
        ["12", "Educational content", "One-time", "$590"],
        ["13", "Corporate sponsors", "Recurring", "Variable"],
        ["14", "Professional conversion", "Service", "$1,497"],
    ]
    t = Table(data, colWidths=[0.4 * inch, 2 * inch, 1 * inch, 1.8 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), HexColor("#006600")),
        ("TEXTCOLOR", (0, 0), (-1, 0), white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.5, HexColor("#cccccc")),
        ("BACKGROUND", (0, 1), (-1, -1), white),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    return t


def add_page_number(canvas, doc):
    """Add page numbers to every page."""
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(TEXT_MUTED)
    canvas.drawCentredString(
        letter[0] / 2, 0.5 * inch,
        f"0pnMatrx Launch Manual  |  Page {doc.page}"
    )
    canvas.restoreState()


def build_pdf(output_path):
    """Build the complete launch manual PDF."""
    doc = SimpleDocTemplate(
        output_path, pagesize=letter,
        topMargin=0.8 * inch, bottomMargin=0.8 * inch,
        leftMargin=0.9 * inch, rightMargin=0.9 * inch,
        title="0pnMatrx Launch Manual",
        author="Dardan Rexhepi",
    )
    styles = build_styles()
    story = []

    # ═══════════════════════════════════════════════════════════════════
    # COVER PAGE
    # ═══════════════════════════════════════════════════════════════════
    story.append(Spacer(1, 2 * inch))
    story.append(Paragraph("0pnMatrx Launch Manual", styles["cover_title"]))
    story.append(Spacer(1, 16))
    story.append(Paragraph(
        "Everything you need to launch.<br/>Open, find your step, copy, paste, done.",
        styles["cover_sub"],
    ))
    story.append(Spacer(1, 24))
    story.append(Paragraph("April 2026", styles["cover_date"]))
    story.append(Paragraph("Confidential", styles["cover_date"]))
    story.append(Spacer(1, 1.5 * inch))
    story.append(HRFlowable(width="60%", thickness=1, color=HexColor("#006600")))
    story.append(PageBreak())

    # ═══════════════════════════════════════════════════════════════════
    # TABLE OF CONTENTS
    # ═══════════════════════════════════════════════════════════════════
    story.append(Paragraph("Table of Contents", styles["section_title"]))
    story.append(Spacer(1, 12))
    toc_items = [
        ("Section 1", "DO TODAY (Est. 2 hours)", [
            "1.1 GitHub Sponsors Setup",
            "1.2 Gumroad -- Template Packs",
            "1.3 Gumroad -- Education Courses",
        ]),
        ("Section 2", "THIS WEEK (Est. 5 hours)", [
            "2.1 Stripe Setup",
            "2.2 Grant Submissions",
            "2.3 Open Collective",
            "2.4 Email Accounts",
            "2.5 Domain and Server",
        ]),
        ("Section 3", "BEFORE MAY 14 (Est. 6 hours)", [
            "3.1 Apple Developer Account",
            "3.2 App Store Connect",
            "3.3 Privacy Policy and Terms",
            "3.4 APNs Setup",
            "3.5 GitHub CI Secrets",
            "3.6 Deploy the Contracts",
            "3.7 Rotate Compromised Credentials",
        ]),
        ("Section 4", "MAY 21 LAUNCH DAY", [
            "4.1 X Thread (10 tweets)",
            "4.2 Single Announcement Tweet",
            "4.3 Product Hunt Submission",
            "4.4 Reddit Posts",
            "4.5 Hacker News Show HN",
            "4.6 Discord Setup",
        ]),
        ("Section 5", "AFTER LAUNCH", [
            "5.1 Vitalik Buterin Email",
            "5.2 Cohl Furey Email",
            "5.3 Aave Partner Email",
            "5.4 1inch Partner Email",
            "5.5 Nansen Signup",
            "5.6 X API Setup",
            "5.7 Chainlink Setup",
        ]),
        ("Section 6", "REVENUE STREAMS SUMMARY", []),
    ]
    for section, title, subs in toc_items:
        story.append(Paragraph(
            f"<b>{section}</b> -- {title}", styles["toc_section"],
        ))
        for sub in subs:
            story.append(Paragraph(f"    {sub}", styles["toc_entry"]))
    story.append(PageBreak())

    # ═══════════════════════════════════════════════════════════════════
    # SECTION 1: DO TODAY
    # ═══════════════════════════════════════════════════════════════════
    story.append(Paragraph("Section 1 -- DO TODAY", styles["section_num"]))
    story.append(Paragraph("Estimated time: 2 hours", styles["body"]))

    # 1.1 GitHub Sponsors
    story.append(Paragraph("1.1 GitHub Sponsors Setup", styles["subsection"]))
    steps = [
        "1. Go to https://github.com/sponsors/ItsDardanRexhepi",
        '2. Click "Get sponsored" (or "Set up sponsors profile")',
        "3. Complete the profile: country, bank account for payouts",
        "4. Create each tier using the table below (copy names and descriptions exactly):",
    ]
    for s in steps:
        story.append(Paragraph(s, styles["body"]))
    story.append(Spacer(1, 6))
    story.append(tier_table(styles))
    story.append(Spacer(1, 8))
    story.append(Paragraph(
        "5. Connect Stripe for payouts (same Stripe account used for subscriptions)",
        styles["body"],
    ))
    story.append(Paragraph("6. Publish your sponsors profile", styles["body"]))
    story.append(Paragraph(
        '7. Verify the "Sponsor" button appears on the repo page',
        styles["body"],
    ))
    story.append(Paragraph(
        "Your sponsor page URL: https://github.com/sponsors/ItsDardanRexhepi",
        styles["body"],
    ))

    # 1.2 Gumroad Template Packs
    story.append(Paragraph("1.2 Gumroad -- Template Packs", styles["subsection"]))
    gumroad_packs = [
        ("DeFi Essentials Pack", "$49", "5 production-ready Solidity contracts for DeFi: lending pool, staking vault, token swap router, yield aggregator, flash loan receiver. Audited with Glasswing."),
        ("Creator Economy Pack", "$49", "5 contracts for creators: NFT collection with royalties, marketplace with escrow, subscription NFT, revenue splitter, auction house. ERC-721 and ERC-1155."),
        ("Business Operations Pack", "$49", "5 contracts for business: payroll automation, invoice factoring, escrow service, multi-sig treasury, vesting schedule. Production-ready with full test suites."),
        ("Complete Bundle (All 3)", "$119", "All 15 Solidity contracts from all three packs. Save $28."),
    ]
    for name, price, desc in gumroad_packs:
        story.append(copy_box(
            f"COPY THIS -- Gumroad Product: {name}",
            f"Product Name: {name}\nPrice: {price}\nDescription: {desc}\nTags: solidity, smart contracts, ethereum, base, defi, nft, web3, 0pnMatrx",
            styles,
        ))
        story.append(Spacer(1, 6))
    story.append(Paragraph(
        "Upload instructions: Go to gumroad.com > New Product > Digital Product. "
        "Paste the name, price, and description. Upload the .zip file from "
        "the templates/ directory. Add the cover image. Publish.",
        styles["body"],
    ))

    # 1.3 Gumroad Education Courses
    story.append(Paragraph("1.3 Gumroad -- Education Courses", styles["subsection"]))
    courses = [
        ("Introduction to 0pnMatrx -- Build with AI + Blockchain", "$49",
         "Learn the platform from scratch. Build a plugin, deploy a contract, integrate with the SDK. 6 modules + 5 exercises with solutions."),
        ("Smart Contract Security with Glasswing", "$79",
         "Why contracts get hacked, reentrancy deep-dive, access control patterns, using Glasswing, pre-deployment checklist. Includes vulnerable + fixed contract code."),
        ("DeFi from Scratch", "$49",
         "How DeFi actually works. Getting a loan through Trinity, NFT royalties, DAO governance, staking and yield. No prerequisites."),
        ("Complete Course Bundle (All 3)", "$149",
         "All three courses. Save $28. Includes all exercises, solutions, and contract code."),
    ]
    for name, price, desc in courses:
        story.append(copy_box(
            f"COPY THIS -- Gumroad Course: {name}",
            f"Product Name: {name}\nPrice: {price}\nDescription: {desc}\nTags: blockchain, AI, smart contracts, Web3, education, 0pnMatrx, security, DeFi",
            styles,
        ))
        story.append(Spacer(1, 6))

    story.append(PageBreak())

    # ═══════════════════════════════════════════════════════════════════
    # SECTION 2: THIS WEEK
    # ═══════════════════════════════════════════════════════════════════
    story.append(Paragraph("Section 2 -- THIS WEEK", styles["section_num"]))
    story.append(Paragraph("Estimated time: 5 hours", styles["body"]))

    # 2.1 Stripe
    story.append(Paragraph("2.1 Stripe Setup", styles["subsection"]))
    story.append(Paragraph(
        "Run the Stripe automation script to create all products and prices:",
        styles["body"],
    ))
    story.append(run_box(
        "RUN THIS",
        "STRIPE_SECRET_KEY=sk_live_xxx python scripts/stripe_setup.py",
        styles,
    ))
    story.append(Spacer(1, 6))
    story.append(Paragraph(
        "The script creates 12 products, prints each price ID, and writes "
        "a .env.stripe file. Copy those values into your .env file.",
        styles["body"],
    ))
    story.append(Paragraph("Webhook setup:", styles["body"]))
    story.append(Paragraph(
        "1. Go to Stripe Dashboard > Developers > Webhooks", styles["body"],
    ))
    story.append(Paragraph(
        "2. Add endpoint: https://openmatrix.io/subscription/webhook", styles["body"],
    ))
    story.append(Paragraph(
        "3. Select events: checkout.session.completed, customer.subscription.updated, "
        "customer.subscription.deleted, invoice.payment_succeeded, invoice.payment_failed",
        styles["body"],
    ))
    story.append(Paragraph(
        "4. Copy the signing secret and add to .env as STRIPE_WEBHOOK_SECRET",
        styles["body"],
    ))

    # 2.2 Grant Submissions
    story.append(Paragraph("2.2 Grant Submissions", styles["subsection"]))
    grants = [
        ("Base Ecosystem Fund", "$150,000", "https://base.org/grants", "launch/grants/base-ecosystem-fund-submission.md"),
        ("Ethereum Foundation ESP", "$75,000", "https://esp.ethereum.foundation", "launch/grants/ethereum-foundation-submission.md"),
        ("Optimism RPGF", "Retroactive", "https://app.optimism.io/retropgf", "launch/grants/optimism-rpgf-submission.md"),
        ("Gitcoin Grants", "Community", "https://grants.gitcoin.co", "launch/grants/gitcoin-submission.md"),
    ]
    for name, amount, url, file in grants:
        story.append(Paragraph(
            f"<b>{name}</b> -- {amount}", styles["body"],
        ))
        story.append(Paragraph(
            f"URL: {url}", styles["body_small"],
        ))
        story.append(Paragraph(
            f"Copy from: {file}", styles["body_small"],
        ))
        story.append(Spacer(1, 4))

    # 2.3 Open Collective
    story.append(Paragraph("2.3 Open Collective", styles["subsection"]))
    story.append(Paragraph("1. Go to https://opencollective.com/create", styles["body"]))
    story.append(Paragraph("2. Collective name: 0pnMatrx (openmatrix)", styles["body"]))
    story.append(copy_box(
        "COPY THIS -- Open Collective Description",
        "0pnMatrx is a free, open-source AI agent platform for blockchain. "
        "Three AI agents provide conversational access to 30 blockchain services on Base. "
        "No token. No gas fees. MIT licensed. Contributions fund infrastructure, development, "
        "the iOS app, and community programs.",
        styles,
    ))
    story.append(Spacer(1, 4))
    story.append(Paragraph(
        "Tiers: Bronze ($500/mo), Silver ($1,000/mo), Gold ($2,500/mo), Platinum ($5,000/mo)",
        styles["body"],
    ))
    story.append(Paragraph(
        "Fund allocation: 40% infrastructure, 30% development, 20% iOS, 10% community",
        styles["body"],
    ))

    # 2.4 Email Accounts
    story.append(Paragraph("2.4 Email Accounts", styles["subsection"]))
    emails = [
        ("support@openmatrix.io", "General user support and deletion requests"),
        ("privacy@openmatrix.io", "Privacy policy inquiries and data requests"),
        ("security@openmatrix.io", "Vulnerability reports and security issues"),
    ]
    for email, purpose in emails:
        story.append(Paragraph(f"<b>{email}</b> -- {purpose}", styles["body"]))

    # 2.5 Domain and Server
    story.append(Paragraph("2.5 Domain and Server", styles["subsection"]))
    story.append(Paragraph("DNS: Create an A record pointing openmatrix.io to your server IP.", styles["body"]))
    story.append(run_box("RUN THIS -- DNS A Record Format", "openmatrix.io.  A  YOUR_SERVER_IP  TTL=300", styles))
    story.append(Spacer(1, 6))
    story.append(run_box(
        "RUN THIS -- Start the gateway",
        "docker compose up -d\ncurl -sf https://openmatrix.io/health",
        styles,
    ))

    story.append(PageBreak())

    # ═══════════════════════════════════════════════════════════════════
    # SECTION 3: BEFORE MAY 14
    # ═══════════════════════════════════════════════════════════════════
    story.append(Paragraph("Section 3 -- BEFORE MAY 14", styles["section_num"]))
    story.append(Paragraph("Estimated time: 6 hours", styles["body"]))

    # 3.1 Apple Developer
    story.append(Paragraph("3.1 Apple Developer Account", styles["subsection"]))
    story.append(Paragraph("1. Go to https://developer.apple.com/enroll/", styles["body"]))
    story.append(Paragraph("2. Sign in with your Apple ID", styles["body"]))
    story.append(Paragraph("3. Enroll as Individual ($99/year)", styles["body"]))
    story.append(Paragraph("4. Complete identity verification", styles["body"]))
    story.append(Paragraph("5. Wait for approval (usually 24-48 hours)", styles["body"]))

    # 3.2 App Store Connect
    story.append(Paragraph("3.2 App Store Connect", styles["subsection"]))
    story.append(Paragraph(
        "Create the app in App Store Connect. Use the copy from launch/app-store-listing.md "
        "for every field. Key fields:",
        styles["body"],
    ))
    story.append(copy_box("COPY THIS -- App Name", "MTRX", styles))
    story.append(Spacer(1, 4))
    story.append(copy_box("COPY THIS -- Subtitle", "AI Agent \xb7 Blockchain \xb7 Free", styles))
    story.append(Spacer(1, 4))
    story.append(Paragraph("Full description: see launch/app-store-listing.md", styles["body"]))
    story.append(copy_box(
        "COPY THIS -- Keywords",
        "ai agent,blockchain,defi,smart contracts,crypto wallet,nft,dao,trinity,neo,openmatrix,free,web3",
        styles,
    ))
    story.append(Spacer(1, 4))
    story.append(Paragraph("In-App Purchase Product IDs:", styles["body"]))
    iap_data = [
        ["Product ID", "Type", "Price"],
        ["io.openmatrix.mtrx.pro.monthly", "Auto-Renewable Sub", "$4.99/mo"],
        ["io.openmatrix.mtrx.enterprise.monthly", "Auto-Renewable Sub", "$19.99/mo"],
    ]
    iap_t = Table(iap_data, colWidths=[2.8 * inch, 1.8 * inch, 1.2 * inch])
    iap_t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), HexColor("#006600")),
        ("TEXTCOLOR", (0, 0), (-1, 0), white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.5, HexColor("#cccccc")),
        ("BACKGROUND", (0, 1), (-1, -1), white),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    story.append(iap_t)
    story.append(Spacer(1, 6))
    story.append(Paragraph(
        "Screenshots: Open launch/screenshots/generate.html in Chrome. "
        "Screenshot each phone frame. Upload under iPhone 6.7-inch Display.",
        styles["body"],
    ))

    # 3.3 Privacy & Terms
    story.append(Paragraph("3.3 Privacy Policy and Terms", styles["subsection"]))
    story.append(Paragraph(
        "Already built. Verify they are live at:", styles["body"],
    ))
    story.append(Paragraph("https://openmatrix.io/privacy", styles["body"]))
    story.append(Paragraph("https://openmatrix.io/terms", styles["body"]))
    story.append(Paragraph(
        'Paste these URLs into App Store Connect under "App Information" > '
        '"Privacy Policy URL" and the Terms of Service field.',
        styles["body"],
    ))

    # 3.4 APNs
    story.append(Paragraph("3.4 APNs Setup", styles["subsection"]))
    story.append(Paragraph("1. Go to developer.apple.com > Certificates, Identifiers, Profiles", styles["body"]))
    story.append(Paragraph("2. Create a new Key > Enable Apple Push Notifications service (APNs)", styles["body"]))
    story.append(Paragraph("3. Download the .p8 key file", styles["body"]))
    story.append(Paragraph("4. Note the Key ID and Team ID", styles["body"]))
    story.append(Paragraph("5. Add to .env:", styles["body"]))
    story.append(run_box("RUN THIS -- .env variables", "APNS_KEY_ID=your_key_id\nAPNS_TEAM_ID=your_team_id\nAPNS_KEY_PATH=/path/to/AuthKey.p8", styles))

    # 3.5 GitHub CI Secrets
    story.append(Paragraph("3.5 GitHub CI Secrets", styles["subsection"]))
    secrets_data = [
        ["Secret Name", "How to Generate"],
        ["STRIPE_SECRET_KEY", "Stripe Dashboard > API Keys"],
        ["STRIPE_WEBHOOK_SECRET", "Stripe Dashboard > Webhooks > Signing Secret"],
        ["BASE_RPC_URL", "Your Base RPC provider (Alchemy/Infura)"],
        ["DEPLOYER_PRIVATE_KEY", "Your deployment wallet private key"],
        ["APNS_KEY_BASE64", "base64 -i AuthKey.p8"],
        ["APNS_KEY_ID", "From Apple Developer Portal"],
        ["APNS_TEAM_ID", "From Apple Developer Portal"],
    ]
    sec_t = Table(secrets_data, colWidths=[2.2 * inch, 4.3 * inch])
    sec_t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), HexColor("#006600")),
        ("TEXTCOLOR", (0, 0), (-1, 0), white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.5, HexColor("#cccccc")),
        ("BACKGROUND", (0, 1), (-1, -1), white),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    story.append(sec_t)
    story.append(Spacer(1, 6))
    story.append(run_box(
        "RUN THIS -- Generate base64 values",
        "base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy\n# Paste into GitHub > Settings > Secrets > APNS_KEY_BASE64",
        styles,
    ))

    # 3.6 Deploy Contracts
    story.append(Paragraph("3.6 Deploy the Contracts", styles["subsection"]))
    story.append(Paragraph("Set these three env vars first:", styles["body"]))
    story.append(run_box(
        "RUN THIS -- Set env vars",
        "export BASE_RPC_URL=https://mainnet.base.org\nexport DEPLOYER_PRIVATE_KEY=your_private_key\nexport NEOSAFE_ADDRESS=0x46fF491D7054A6F500026B3E81f358190f8d8Ec5",
        styles,
    ))
    story.append(Spacer(1, 6))
    story.append(run_box(
        "RUN THIS -- Deploy all contracts",
        "bash scripts/deploy_and_configure.sh",
        styles,
    ))
    story.append(Spacer(1, 6))
    story.append(Paragraph(
        "Success looks like: each contract address printed, config updated, "
        "health check returning 200.",
        styles["body"],
    ))

    # 3.7 Rotate Credentials
    story.append(Paragraph("3.7 Rotate Compromised Credentials", styles["subsection"]))
    story.append(Paragraph("BotFather sequence for each Telegram bot:", styles["body"]))
    story.append(copy_box(
        "COPY THIS -- BotFather Messages",
        "1. Open @BotFather in Telegram\n2. Send: /revoke\n3. Select the bot (Trinity/Neo/Morpheus)\n4. Copy the new token\n5. Update .env with the new token\n6. Restart the gateway",
        styles,
    ))
    story.append(Spacer(1, 4))
    story.append(Paragraph(
        "NeoWrite key: Generate a new key at the NeoWrite console. "
        "Update NEOWRITE_API_KEY in .env.",
        styles["body"],
    ))
    story.append(Paragraph(
        "Coinbase key: Go to Coinbase Developer Platform > API Keys > Create new key. "
        "Update COINBASE_API_KEY and COINBASE_API_SECRET in .env.",
        styles["body"],
    ))
    story.append(run_box(
        "RUN THIS -- After updating all keys",
        "bash scripts/rotate_credentials.sh\ndocker compose restart gateway",
        styles,
    ))

    story.append(PageBreak())

    # ═══════════════════════════════════════════════════════════════════
    # SECTION 4: LAUNCH DAY
    # ═══════════════════════════════════════════════════════════════════
    story.append(Paragraph("Section 4 -- MAY 21 LAUNCH DAY", styles["section_num"]))

    # 4.1 X Thread
    story.append(Paragraph("4.1 X Thread (10 Tweets)", styles["subsection"]))
    tweets = [
        ("1/10", "I built an AI agent that does blockchain for you.\n\nNo token. No gas fees. No wallet setup.\n\nJust talk to Trinity.\n\nShe handles the rest.\n\nIt's called 0pnMatrx, and it launches May 21.\n\nHere's what it is and why I built it."),
        ("2/10", "0pnMatrx is a free, open-source AI agent platform for blockchain.\n\n3 AI agents. 30 services. All on Base (Ethereum L2).\n\nYou don't need to know anything about crypto. You just need to know what you want.\n\nTrinity figures out the how."),
        ("3/10", "Meet the agents:\n\nTrinity -- your conversational interface. Talk naturally, she translates intent into action.\n\nNeo -- the executor. Handles every on-chain transaction.\n\nMorpheus -- your guide. Explains what's happening and why."),
        ("4/10", "Trinity isn't a chatbot with a wallet bolted on.\n\nShe understands 30 blockchain services: swaps, staking, lending, bridging, ENS, attestations, NFTs, and more.\n\nOne sentence from you. One transaction from her."),
        ("5/10", "The free tier is real free.\n\n$0/month. No trial. No credit card. No token purchase.\n\nPro is $4.99/mo. Enterprise is $19.99/mo.\n\nEvery tier gets Trinity. Every tier gets blockchain access. No gas fees on any plan."),
        ("6/10", "The MTRX iOS app launches May 21, 2026.\n\nNative SwiftUI. StoreKit 2 subscriptions. Biometric auth.\n\nBlockchain AI in your pocket. No browser extensions. No seed phrases on your phone."),
        ("7/10", "It's fully open source. MIT licensed.\n\n329+ tests passing. Plugin architecture. One-command install.\n\nFork it. Extend it. Build your own agents on top.\n\nhttps://github.com/ItsDardanRexhepi/0pnMatrx"),
        ("8/10", "I built the entire platform in 40 days. Solo.\n\nBackend, frontend, iOS app, 3 AI agents, 30 services, test suite, docs.\n\nNo team. No funding. No VC. Just the conviction that blockchain should be accessible to everyone."),
        ("9/10", "I dedicated 0pnMatrx to Vitalik Buterin, with a 1% proceeds commitment EAS-attested on-chain.\n\nBecause the tools that change the world should be free, and the people who inspire them should be honored."),
        ("10/10", "0pnMatrx launches May 21, 2026.\n\nWebsite: https://openmatrix.io\nGitHub: https://github.com/ItsDardanRexhepi/0pnMatrx\n\nStar the repo. Download the app. Talk to Trinity.\n\nThe matrix is open."),
    ]
    for num, text in tweets:
        story.append(copy_box(f"COPY THIS -- Tweet {num}", text, styles))
        story.append(Spacer(1, 4))

    # 4.2 Single Tweet
    story.append(Paragraph("4.2 Single Announcement Tweet", styles["subsection"]))
    story.append(copy_box(
        "COPY THIS -- Standalone Tweet",
        "I built a free, open-source AI agent that does blockchain for you. No token. No gas fees. Just talk to Trinity.\n\n3 agents. 30 services. MIT licensed. Built solo in 40 days.\n\nMTRX app launches May 21.\n\nhttps://openmatrix.io",
        styles,
    ))

    # 4.3 Product Hunt
    story.append(Paragraph("4.3 Product Hunt Submission", styles["subsection"]))
    story.append(copy_box("COPY THIS -- PH Name", "MTRX -- AI Agent Platform for Everyone", styles))
    story.append(Spacer(1, 4))
    story.append(copy_box("COPY THIS -- PH Tagline", "Free blockchain AI agent. No token. No fees. Just Trinity.", styles))
    story.append(Spacer(1, 4))
    story.append(copy_box(
        "COPY THIS -- PH Description",
        "0pnMatrx is a free, open-source AI agent platform for blockchain. 3 AI agents -- Trinity (conversation), Neo (execution), Morpheus (guidance) -- handle 30 blockchain services on Base. No gas fees, no token, no wallet setup. MIT licensed. MTRX iOS app included.",
        styles,
    ))
    story.append(Spacer(1, 4))
    story.append(Paragraph(
        "Topics: Artificial Intelligence, Blockchain, iOS, Open Source, FinTech",
        styles["body"],
    ))
    story.append(Paragraph(
        "Gallery images: Open launch/producthunt/gallery-images.html, screenshot each image.",
        styles["body"],
    ))
    story.append(Paragraph(
        "First comment (maker comment): See launch/announcements.md for the full 500-word maker comment.",
        styles["body"],
    ))

    story.append(PageBreak())

    # 4.4 Reddit Posts
    story.append(Paragraph("4.4 Reddit Posts", styles["subsection"]))
    subreddits = [
        ("r/ethereum", "0pnMatrx: Free, open-source AI agent platform for Ethereum (Base L2) -- MIT licensed, 30 services, EAS attestations on-chain"),
        ("r/defi", "Built a free AI agent that handles DeFi for you -- Aave lending, Uniswap swaps, Lido staking, 1inch aggregation, all through conversation"),
        ("r/opensource", "0pnMatrx: MIT-licensed AI agent platform for blockchain -- one-command install, plugin architecture, 329+ tests, built solo in 40 days"),
        ("r/iOSProgramming", "MTRX -- SwiftUI app with StoreKit 2 subscriptions, biometric auth, and AI agents for blockchain. Launching May 21."),
        ("r/SideProject", "I built a complete AI agent platform for blockchain in 40 days, solo. 3 agents, 30 services, iOS app, 329+ tests."),
    ]
    for sub, title in subreddits:
        story.append(copy_box(
            f"COPY THIS -- {sub} Title",
            title,
            styles,
        ))
        story.append(Spacer(1, 2))
    story.append(Paragraph(
        "Full post bodies for each subreddit: see launch/announcements.md",
        styles["body"],
    ))

    # 4.5 Hacker News
    story.append(Paragraph("4.5 Hacker News Show HN", styles["subsection"]))
    story.append(copy_box(
        "COPY THIS -- HN Title",
        "Show HN: 0pnMatrx -- Open-source AI agent platform for blockchain (Base/L2)",
        styles,
    ))
    story.append(Spacer(1, 4))
    story.append(Paragraph("Full body: see launch/announcements.md", styles["body"]))

    # 4.6 Discord
    story.append(Paragraph("4.6 Discord Setup", styles["subsection"]))
    story.append(Paragraph(
        "Follow the complete setup guide in launch/discord-setup.md. "
        "All welcome messages, rules, and pinned posts are ready to copy-paste.",
        styles["body"],
    ))

    story.append(PageBreak())

    # ═══════════════════════════════════════════════════════════════════
    # SECTION 5: AFTER LAUNCH
    # ═══════════════════════════════════════════════════════════════════
    story.append(Paragraph("Section 5 -- AFTER LAUNCH", styles["section_num"]))

    # 5.1 Vitalik
    story.append(Paragraph("5.1 Vitalik Buterin Email", styles["subsection"]))
    story.append(copy_box("COPY THIS -- To", "vitalik@ethereum.org", styles))
    story.append(Spacer(1, 4))
    story.append(copy_box(
        "COPY THIS -- Subject",
        "0pnMatrx -- open-source platform dedicated to you, with 1% proceeds commitment on-chain",
        styles,
    ))
    story.append(Spacer(1, 4))
    story.append(Paragraph("Full email body: see launch/announcements.md", styles["body"]))

    # 5.2 Cohl Furey
    story.append(Paragraph("5.2 Cohl Furey Email", styles["subsection"]))
    story.append(copy_box(
        "COPY THIS -- Subject",
        "arXiv endorsement request -- Unified Rexhepi Framework: Pin-structure and Cl(6)_C Clifford algebra chain for three-generation fermion structure",
        styles,
    ))
    story.append(Spacer(1, 4))
    story.append(Paragraph("Full email body: see launch/announcements.md", styles["body"]))

    # 5.3 Aave
    story.append(Paragraph("5.3 Aave Partner Email", styles["subsection"]))
    story.append(copy_box(
        "COPY THIS -- Subject",
        "Integration partner application -- 0pnMatrx AI agent platform (Aave v3 on Base)",
        styles,
    ))
    story.append(Spacer(1, 4))
    story.append(Paragraph("Full email body: see launch/announcements.md", styles["body"]))

    # 5.4 1inch
    story.append(Paragraph("5.4 1inch Partner Email", styles["subsection"]))
    story.append(copy_box(
        "COPY THIS -- Subject",
        "Partner program application -- 0pnMatrx AI agent platform (DEX aggregation on Base)",
        styles,
    ))
    story.append(Spacer(1, 4))
    story.append(Paragraph(
        "Referrer address: 0x46fF491D7054A6F500026B3E81f358190f8d8Ec5",
        styles["body"],
    ))
    story.append(Paragraph("Full email body: see launch/announcements.md", styles["body"]))

    # 5.5 Nansen
    story.append(Paragraph("5.5 Nansen Signup", styles["subsection"]))
    story.append(Paragraph("URL: https://app.nansen.ai", styles["body"]))
    story.append(Paragraph("After signup, add to .env:", styles["body"]))
    story.append(run_box("RUN THIS", "NANSEN_API_KEY=your_nansen_key", styles))

    # 5.6 X API
    story.append(Paragraph("5.6 X API Setup", styles["subsection"]))
    story.append(Paragraph("URL: https://developer.x.com/en/portal/dashboard", styles["body"]))
    story.append(Paragraph("Create a project and app. Add to .env:", styles["body"]))
    story.append(run_box(
        "RUN THIS",
        "TWITTER_API_KEY=your_key\nTWITTER_API_SECRET=your_secret\nTWITTER_ACCESS_TOKEN=your_token\nTWITTER_ACCESS_SECRET=your_access_secret",
        styles,
    ))

    # 5.7 Chainlink
    story.append(Paragraph("5.7 Chainlink Setup", styles["subsection"]))
    story.append(Paragraph("1. Register at https://chain.link/", styles["body"]))
    story.append(Paragraph("2. Get VRF subscription on Base", styles["body"]))
    story.append(Paragraph("3. Update openmatrix.config.json:", styles["body"]))
    story.append(run_box(
        "RUN THIS -- Config fields to update",
        '"vrf_coordinator": "YOUR_VRF_COORDINATOR_ADDRESS"\n"vrf_key_hash": "YOUR_VRF_KEY_HASH"\n"vrf_subscription_id": "YOUR_VRF_SUBSCRIPTION_ID"',
        styles,
    ))

    story.append(PageBreak())

    # ═══════════════════════════════════════════════════════════════════
    # SECTION 6: REVENUE STREAMS
    # ═══════════════════════════════════════════════════════════════════
    story.append(Paragraph("Section 6 -- REVENUE STREAMS SUMMARY", styles["section_num"]))
    story.append(Spacer(1, 8))
    story.append(revenue_table(styles))
    story.append(Spacer(1, 12))

    # Projections
    story.append(Paragraph("Revenue Projections", styles["subsection"]))
    proj_data = [
        ["Users", "Estimated MRR", "Estimated ARR"],
        ["100", "$1,500 - $3,000", "$18,000 - $36,000"],
        ["1,000", "$9,328", "$111,936"],
        ["10,000", "$50,000 - $80,000", "$600,000 - $960,000"],
    ]
    proj_t = Table(proj_data, colWidths=[1.5 * inch, 2.2 * inch, 2.2 * inch])
    proj_t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), HexColor("#006600")),
        ("TEXTCOLOR", (0, 0), (-1, 0), white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("GRID", (0, 0), (-1, -1), 0.5, HexColor("#cccccc")),
        ("BACKGROUND", (0, 1), (-1, -1), white),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("ALIGN", (1, 0), (-1, -1), "CENTER"),
    ]))
    story.append(proj_t)
    story.append(Spacer(1, 16))
    story.append(Paragraph(
        "<b>Nothing here requires more code. Everything is built.</b>",
        styles["body"],
    ))

    story.append(PageBreak())

    # ═══════════════════════════════════════════════════════════════════
    # BACK COVER
    # ═══════════════════════════════════════════════════════════════════
    story.append(Spacer(1, 2.5 * inch))
    story.append(Paragraph(
        "Built by Dardan Rexhepi and Neo. April 2026.",
        styles["cover_sub"],
    ))
    story.append(Spacer(1, 24))
    story.append(Paragraph(
        "The code is done. Now go launch.",
        styles["cover_title"],
    ))
    story.append(Spacer(1, 24))
    story.append(HRFlowable(width="40%", thickness=1, color=HexColor("#006600")))

    # ── Build ──
    doc.build(story, onFirstPage=add_page_number, onLaterPages=add_page_number)
    print(f"PDF generated: {output_path}")


if __name__ == "__main__":
    output = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "launch", "LAUNCH_MANUAL.pdf",
    )
    build_pdf(output)
