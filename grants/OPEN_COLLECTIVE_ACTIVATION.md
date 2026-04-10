# Open Collective Activation Guide for 0pnMatrx

This document contains the step-by-step manual process for creating and activating the 0pnMatrx Open Collective. Estimated total time: 30 minutes of setup work, followed by 1-3 business days waiting for approval from Open Source Collective.

---

## Step 1: Create the Collective

1. Go to [https://opencollective.com/create](https://opencollective.com/create)
2. Sign in with your GitHub account (the account that owns the 0pnMatrx repository)
3. Choose "Open Source" as the collective category
4. Set the collective name to **openmatrix**
5. Set the URL slug to **openmatrix** (this gives you `opencollective.com/openmatrix`)
6. Write the description: "Free, open source AI agent platform built for the people"
7. Upload the project logo if available
8. Click "Create Collective"

## Step 2: Apply to Open Source Collective as Fiscal Host

The fiscal host handles legal entity status, banking, tax compliance, and invoice generation so you do not need to create a separate legal entity for the project.

1. After creating the collective, go to Settings > Fiscal Host
2. Search for **Open Source Collective** (this is a 501(c)(6) nonprofit organization)
3. Click "Apply"
4. In the application form:
   - Link the GitHub repository: `https://github.com/ItsDardanRexhepi/0pnMatrx`
   - Confirm the repository has an OSI-approved open-source license (check that the LICENSE file in the repo qualifies)
   - Describe the project: "0pnMatrx is a free, open-source AI agent platform combining blockchain infrastructure, decentralized protocols, and an iOS app. We are seeking transparent community funding to sustain development, hosting, and community programs."
   - Mention the number of GitHub stars, contributors, and any other traction metrics
5. Submit the application
6. Wait for approval -- Open Source Collective typically reviews applications within 1-3 business days. You will receive an email notification when approved or if they need additional information.

**Important:** Open Source Collective requires that the project is genuinely open source with an OSI-approved license. They will check the repository. Make sure the LICENSE file is in order before applying.

## Step 3: Connect the GitHub Repository

1. Go to your collective's Settings > Connected Accounts
2. Click "Connect GitHub"
3. Authorize the Open Collective GitHub app
4. Select the repository: `ItsDardanRexhepi/0pnMatrx`
5. This connection enables:
   - Automatic display of repository stats on the collective page
   - The ability for contributors to be recognized based on their GitHub contributions
   - Verification that the collective is legitimately tied to the project

## Step 4: Set Up Sponsor Tiers

Create four corporate tiers and one individual tier. Go to Settings > Tiers and create the following:

### Individual Contribution (flexible)

- **Name:** Supporter
- **Type:** Donation
- **Amount type:** Flexible (any amount)
- **Interval:** One-time or monthly
- **Description:** "Support 0pnMatrx development at any amount. Every dollar funds open-source AI infrastructure."

### Bronze Corporate -- $500/month

- **Name:** Bronze Corporate Sponsor
- **Type:** Membership
- **Amount:** $500
- **Interval:** Monthly
- **Description:** "Company logo in README, named in changelog. Invoice and tax receipt included."
- **Button text:** "Become a Bronze Sponsor"

### Silver Corporate -- $1,000/month

- **Name:** Silver Corporate Sponsor
- **Type:** Membership
- **Amount:** $1,000
- **Interval:** Monthly
- **Description:** "Logo on landing page, monthly dev update call. Everything in Bronze included. Invoice and tax receipt included."
- **Button text:** "Become a Silver Sponsor"

### Gold Corporate -- $2,500/month

- **Name:** Gold Corporate Sponsor
- **Type:** Membership
- **Amount:** $2,500
- **Interval:** Monthly
- **Description:** "Dedicated integration support, roadmap influence. Everything in Silver included. Invoice and tax receipt included."
- **Button text:** "Become a Gold Sponsor"

### Platinum Corporate -- $5,000/month

- **Name:** Platinum Corporate Sponsor
- **Type:** Membership
- **Amount:** $5,000
- **Interval:** Monthly
- **Description:** "White-label rights, 10 Enterprise licenses free, quarterly strategic review. Everything in Gold included. Invoice and tax receipt included."
- **Button text:** "Become a Platinum Sponsor"

## Step 5: Configure Stripe for Payouts

Open Source Collective handles payouts, but you need to ensure the collective can receive funds through Stripe (the payment processor Open Collective uses).

1. Go to Settings > Receiving Money
2. Verify that Stripe is listed as an active payment method (this is configured by the fiscal host, but confirm it is enabled)
3. If prompted, connect a Stripe account or confirm the fiscal host's Stripe integration
4. Test with a small self-contribution ($1) to verify the payment flow works end to end
5. Confirm the contribution appears on the collective's public ledger

For payouts (submitting expenses to receive funds):

1. Go to Settings > Payout Methods
2. Add a payout method -- options include:
   - **PayPal:** Enter the PayPal email address
   - **Bank transfer (via TransferWise/Wise):** Enter bank account details
   - **Other:** Contact Open Source Collective for alternative arrangements
3. Submit a test expense (e.g., a small hosting cost) to verify the payout flow

## Step 6: Add the Badge to README

Once the collective is approved and live, add the Open Collective badge to the project README.md.

Add this markdown near the top of README.md, in the badges section:

```markdown
[![Open Collective](https://img.shields.io/opencollective/all/openmatrix?label=Open%20Collective&logo=open-collective)](https://opencollective.com/openmatrix)
```

This badge dynamically displays the total number of financial contributors (backers + sponsors) and links directly to the collective page.

If the README already has a badges section, place the Open Collective badge alongside the existing badges. If there is no badges section, add it immediately below the project title.

## Step 7: Post-Activation Checklist

After the collective is approved and live, verify the following:

- [ ] Collective page is publicly accessible at `https://opencollective.com/openmatrix`
- [ ] GitHub repository is connected and showing stats
- [ ] All five tiers (Supporter, Bronze, Silver, Gold, Platinum) are visible on the collective page
- [ ] Stripe payment flow works (test with a $1 contribution, then refund it)
- [ ] Payout method is configured and verified
- [ ] README badge is live and showing correct data
- [ ] The `opencollective.json` file at the repo root matches the collective settings
- [ ] The `docs/OPEN_COLLECTIVE.md` document links to the correct collective URL
- [ ] A welcome post is published on the collective page explaining the project and how funds will be used

---

## Timeline Summary

| Task | Time Required |
|---|---|
| Create collective and fill out profile | 5 minutes |
| Apply to Open Source Collective | 10 minutes |
| Wait for approval | 1-3 business days |
| Connect GitHub repository | 5 minutes |
| Set up all five tiers | 10 minutes |
| Configure Stripe and test payments | 5 minutes |
| Add README badge | 2 minutes |
| Post-activation verification | 5 minutes |
| **Total active work** | **~30 minutes** |
| **Total elapsed time (including approval wait)** | **1-3 days** |

---

**Open Collective create page:** [https://opencollective.com/create](https://opencollective.com/create)

**Open Source Collective (fiscal host):** [https://oscollective.org](https://oscollective.org)

**GitHub repository:** [https://github.com/ItsDardanRexhepi/0pnMatrx](https://github.com/ItsDardanRexhepi/0pnMatrx)
