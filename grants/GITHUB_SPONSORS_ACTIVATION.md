# GitHub Sponsors Activation Guide

Step-by-step instructions for activating GitHub Sponsors on the 0pnMatrx repository. Estimated time: 20 minutes.

---

## Prerequisites

Before you start, make sure you have:

- A GitHub account with owner access to the 0pnMatrx repository
- A bank account or Stripe account for receiving payouts
- Your legal name and address for tax purposes (GitHub requires this for payouts)
- The `.github/FUNDING.yml` file already committed to the repository (it is included in this repo)

---

## Step 1: Navigate to GitHub Sponsors

1. Go to [github.com/sponsors](https://github.com/sponsors)
2. If you are logged in, you will see the GitHub Sponsors landing page
3. Click **"Get sponsored"** in the top right area of the page

If you do not see the "Get sponsored" option, make sure you are logged into the correct GitHub account (ItsDardanRexhepi).

---

## Step 2: Select Your Sponsored Account Type

1. GitHub will ask whether you want to be sponsored as an **individual** or as an **organization**
2. Select **individual** (the ItsDardanRexhepi account)
3. Click **Continue** to proceed to the profile setup

---

## Step 3: Set Up Your Sponsor Profile

Fill in the following fields:

- **Short description:** "Creator of 0pnMatrx -- keeping blockchain accessible and free for everyone"
- **Introduction:** Write a brief explanation of what 0pnMatrx is and why sponsorship matters. Reference the mission of keeping the platform free, funding infrastructure, and supporting iOS app maintenance
- **Featured work:** Link to the 0pnMatrx repository
- **Social links:** Add any relevant links (openmatrix.io, Twitter/X, etc.)

Click **Save** when done.

---

## Step 4: Create the Sponsorship Tiers

Create each of the following five tiers. For each tier, click **"Add a tier"** and fill in the details:

### Tier 1: Community Supporter

- **Amount:** $5/month
- **Name:** Community Supporter
- **Description:**
  ```
  For individuals who believe in the mission. Your name is listed in
  CONTRIBUTORS.md and you have our genuine gratitude. Every dollar
  keeps the free tier alive for people who need it most.
  ```
- **Availability:** Unlimited

### Tier 2: Platform Backer

- **Amount:** $25/month
- **Name:** Platform Backer
- **Description:**
  ```
  For developers and professionals who use 0pnMatrx. Your name and
  link appear in the README sponsors section. You get access to the
  private sponsors Discord channel and early access to release notes.
  Includes everything in Community Supporter.
  ```
- **Availability:** Unlimited

### Tier 3: Builder

- **Amount:** $100/month
- **Name:** Builder
- **Description:**
  ```
  For companies and teams who depend on 0pnMatrx. Your logo is
  displayed in the README. You get priority issue responses, influence
  on the development roadmap through quarterly feedback sessions, and
  a shoutout in the monthly project update. Includes everything in
  Platform Backer.
  ```
- **Availability:** Unlimited

### Tier 4: Infrastructure Partner

- **Amount:** $500/month
- **Name:** Infrastructure Partner
- **Description:**
  ```
  For organizations running 0pnMatrx at scale. Your logo is featured
  on the openmatrix.io landing page. You get a dedicated Slack channel
  with the core team, quarterly roadmap calls, and attribution in
  release announcements. Includes everything in Builder.
  ```
- **Availability:** Limited to 10

### Tier 5: Founding Sponsor

- **Amount:** $2,500/month
- **Name:** Founding Sponsor
- **Description:**
  ```
  For visionary organizations who want to shape 0pnMatrx permanently.
  White-label rights, custom component development priority, named in
  all press releases, direct access to the founding team, and a
  permanent place in project history. Includes everything in
  Infrastructure Partner.
  ```
- **Availability:** Limited to 5

After creating all five tiers, review them on the preview page to make sure the amounts, names, and descriptions are correct.

---

## Step 5: Link a Stripe Account for Payouts

1. On the payout setup page, click **"Connect with Stripe"**
2. If you already have a Stripe account, log in. If not, create one during this flow
3. Stripe will ask for:
   - Your legal name
   - Your date of birth
   - Your address
   - Your bank account details (routing number and account number) or debit card for payouts
   - Your Social Security Number or tax ID (required for US tax reporting)
4. Complete the Stripe onboarding process
5. Once connected, you will be redirected back to GitHub

GitHub uses Stripe Connect to handle all payouts. Funds are transferred according to your chosen payout schedule (typically monthly).

---

## Step 6: Configure Tax Information

1. GitHub will prompt you to fill in tax information (W-9 for US individuals, W-8BEN for non-US)
2. Complete the tax form within the GitHub interface
3. This is required before you can receive any payouts

---

## Step 7: Review and Publish Your Sponsors Profile

1. Review all sections: profile information, tiers, payout settings, and tax forms
2. Check the preview to make sure everything looks correct
3. Click **"Publish sponsor profile"** or **"Join the waitlist"** (depending on GitHub's current onboarding flow)

If there is a waitlist, GitHub typically approves profiles within a few business days.

---

## Step 8: Verify the FUNDING.yml Integration

Once your Sponsors profile is active:

1. Go to the 0pnMatrx repository on GitHub
2. Look for the **"Sponsor"** button with a heart icon near the top of the repository page
3. Click it to verify that it shows the correct links:
   - GitHub Sponsors (ItsDardanRexhepi)
   - Open Collective (openmatrix)
   - Custom URL (openmatrix.io/sponsor)

The **Sponsor** button appears automatically because the `.github/FUNDING.yml` file is already in the repository. If the button does not appear, verify that the file is on the default branch (main) and that the YAML syntax is valid.

---

## Step 9: Test the Flow

1. Open a private/incognito browser window
2. Navigate to the 0pnMatrx repository
3. Click the **Sponsor** button
4. Verify that the tier selection page loads and all five tiers are visible with correct pricing
5. Do not complete a test payment -- just verify the flow up to the payment step

---

## After Activation Checklist

Once GitHub Sponsors is live, complete these follow-up tasks:

- [ ] Announce sponsorship availability in the project's Discord/community channels
- [ ] Add a sponsorship mention to the next release notes
- [ ] Set up the Open Collective page at opencollective.com/openmatrix if not already done
- [ ] Update the openmatrix.io/sponsor page to link to the GitHub Sponsors profile
- [ ] Monitor the first few sponsorships to make sure Stripe payouts are configured correctly

---

## Troubleshooting

**The Sponsor button does not appear on the repository.**
- Make sure `.github/FUNDING.yml` is committed to the default branch (main)
- Verify the YAML is valid (no tabs, correct indentation)
- It can take a few minutes for GitHub to detect the file after pushing

**Stripe connection failed.**
- Try disconnecting and reconnecting through the GitHub Sponsors settings
- Make sure your browser is not blocking Stripe's OAuth redirect
- Contact GitHub Support if the issue persists

**Tier descriptions are not showing correctly.**
- Edit tiers through the GitHub Sponsors dashboard at github.com/sponsors/ItsDardanRexhepi/dashboard
- Make sure there are no unsupported characters in the description fields

**Payouts are not arriving.**
- Check the payout schedule in your GitHub Sponsors settings
- Verify your Stripe account is fully activated (no pending verification steps)
- GitHub holds funds for a short period before the first payout as a fraud prevention measure
