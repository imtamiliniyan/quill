# Project Roadmap: Quill Launch & Validation Strategy

This roadmap details the progression from the initial Reddit validation campaign to a fully automated custom domain launch, plus the feature ideas under consideration beyond the current dictation app.

---

## Phase 1: Idea Validation (Current)
*   **Goal:** Share the concept on niche subreddits (e.g., `r/macapps`, `r/opensource`, `r/productivity`) to gauge interest and drive traffic.
*   **Hosting:** Active on the free Vercel subdomain (`quill-stt.vercel.app`).
*   **Waitlist Capture:** Active. Email and name entries are stored in the Firestore `waitlist` database.
*   **Email Status:** Currently runs in **Demo Mode**. The serverless function logs signup events to the console instead of sending real emails (saving cost and avoiding unverified spam folders).

---

## Phase 2: Traction & Custom Domain Setup (Post-Validation)
Once the Reddit posts get traction and a custom domain is worth investing in:

1.  **Register Domain:** Buy `quillmac.app` or `quillstt.com` via Hostinger or Namecheap.
2.  **Point to Vercel:**
    - Go to Vercel Dashboard → `quill` project → **Settings** → **Domains**.
    - Add the domain.
    - Copy the DNS records Vercel provides:
      - **A record** pointing to Vercel's IP (`76.76.21.21`) for the root domain.
      - **CNAME record** pointing to `cname.vercel-dns.com` for the `www` subdomain.
    - Paste these records into the domain registrar's DNS management panel.

---

## Phase 3: Branded Email Activation
To start sending verified, branded welcome emails to new signups:

1.  **Verify Domain in Brevo:**
    - Log in to the Brevo account.
    - Go to **Senders & IP** → **Domains** → **Add a Domain**.
    - Brevo will provide three **TXT records** (SPF and DKIM verification).
    - Add these TXT records to the domain registrar's DNS panel (this ensures emails arrive in the primary **Inbox** instead of Spam).
2.  **Enable Vercel Environment Variables:**
    - Go to Vercel Dashboard → `quill` project → **Settings** → **Environment Variables**.
    - Add:
      - `BREVO_API_KEY` = *Brevo SMTP API Key*
      - `BREVO_SENDER_EMAIL` = `waitlist@yourdomain.com` (or whatever address is verified)
      - `BREVO_SENDER_NAME` = `Quill`

*Once saved, Vercel will automatically redeploy, and all subsequent signups will instantly receive their welcome email.*

---

## Phase 4: Feature Ideas Under Consideration (Demand-Test First)

Not committed — each of these gets its own waitlist/interest signal before any engineering time goes in, same discipline as Phase 1. If a landing-page teaser for one of these doesn't pull signups, it doesn't get built.

### 4a. Local Grammar & Fluency Checker
Inspired by [Refine](https://refine.sh) (Mac-only, $38 lifetime, grammar/fluency/rewrite across 20+ apps). Quill's version of this would extend the existing **Style** feature (Auto Cleanup / Rewrite on demand) rather than being a separate product.

- **Primary engine (macOS 26+, Apple Intelligence–eligible hardware):** Apple's **Foundation Models framework** — on-device ~3B model exposed via a Swift API, zero bundled model weight, fully local.
- **Fallback engine (older macOS / non-Apple-Intelligence hardware, and non-Mac platforms if pursued):** **Gemma 3n** (Google's edge-optimized model, E2B/E4B variants) — same model Refine bundles today, and viable as a shared engine across platforms since Google built it for on-device deployment on phones and laptops, not just desktop.
- Keeps the "nothing leaves your Mac" story intact — no new BYOK/API-key exception needed for the core grammar pass, unlike Style's current Medium tier.
- Differentiation vs. Refine: Refine is Mac-only with Windows/Linux on a waitlist; if Quill ships local inference on more than one platform it closes a gap Refine hasn't closed yet.
- **Open question:** whether "cross-platform" means true on-device everywhere or on-device on Mac + a privacy-conscious cloud fallback elsewhere — decide before architecture work starts, not after.

### 4b. Local Meeting Capture & Transcription
Inspired by Granola's approach — no bot joins the call; it captures system audio + mic locally. Quill already has the on-device STT engine (WhisperKit/Parakeet); this would be a new capture mode feeding the same pipeline, plus notes generation using whichever local LLM 4a lands on.

- **Differentiator:** Granola still sends audio/notes to the cloud for summarization. A fully local capture-through-notes pipeline ("meeting notes that never leave your Mac") would be a real gap in the current market, not just parity.
- **Known hard part — diarization:** separating "who said what" in a multi-speaker system-audio mix is a distinct, heavier on-device ML problem than single-speaker STT. Needs a feasibility spike before it goes on a landing page.
- **Known hard part — recording consent law:** consent requirements vary by jurisdiction (one-party consent in most US states/federal law vs. two-party/all-party consent in ~11-13 states plus some other countries and require every participant to know). Granola's own approach: doesn't force disclosure, but offers an opt-in camera watermark + automated meeting-chat message, and pushes compliance responsibility to the user via ToS ("this is not legal advice"). If Quill builds this, ship the equivalent opt-in notification feature from day one rather than bolting it on later — same pattern, not a novel one.

---

## Working principle carried across all of Phase 4

Ideas surface fast (a Reddit scroll is enough to spawn several) — the filter is always demand first, architecture second. Nothing in 4a/4b gets scoped into an implementation plan until its own waitlist signal justifies it, same discipline that got Quill itself from idea to Phase 1.
