# Quill landing page v2 — build brief

**Status:** replaces `landing/index.html` + `landing/styles.css` once built. Those files stay in place untouched until this is ready to swap in.

**Reference:** [Aceai](https://aceai.nextjsshop-preview.workers.dev/) (a paid Next.js template on nextjsshop.com, ₹10,707). This brief borrows its **layout pattern, color mood, and component shapes** — measured directly from the live page's computed styles — but every word of copy below is original, written for Quill, and no assets (logo, icons, fonts, images) are reused from it. Do not screenshot or copy Aceai's actual markup/CSS/images; rebuild from the tokens and structure described here.

---

## 1. Design system

### Colors

| Token | Value | Use |
|---|---|---|
| `--bg-top` | `#FFF3EE` | Page background gradient start |
| `--bg-bottom` | `#FFF9F6` | Page background gradient end (`linear-gradient(to bottom, ...)`) |
| `--surface` | `#FFFFFF` | Cards, floating nav pill |
| `--ink` | `#1A1A1A` | Primary text (near-black, not pure black) |
| `--ink-dim` | `rgba(26,26,26,0.6)` | Secondary text |
| `--ink-dimmer` | `rgba(26,26,26,0.4)` | Tertiary/caption text |
| `--glow-a` | `#D1C2F4` | Blurred accent blob, lavender |
| `--glow-b` | `#FFDC61` | Blurred accent blob, warm gold |
| `--accent-strip` | `linear-gradient(90deg, #FFE0D6, #FFB7A5, #FFC3BC, #F4C2F0)` | Thin decorative divider/underline |
| `--dark-surface` | `#2A2A2A` | Contrast sections (trust block, final CTA) |
| `--dark-ink` | `#FFFFFF` | Text on dark surface |
| `--quill-accent` | `#B5D1FF` | Quill's own app accent — use sparingly (icon strokes, one detail in the trust section) so the page still visually threads back to the actual app, not just the reference |

Buttons: primary CTA is a pill (`border-radius: 999px`) filled with a `linear-gradient(135deg, #2D2D2D 10%, #000000 100%)`, white text. Secondary CTA is the same pill shape, outlined, transparent fill.

Cards: `border-radius: 24px`, white surface, soft shadow, sitting on the peach gradient background.

Nav: floating white pill (`border-radius: 22px`), sticky at top with a small margin from the viewport edge (not flush), containing logo + links + CTA button.

### Typography

- **Headlines:** a light-weight (300) warm serif. The reference uses a paid custom font ("Galica") — do not use it. Use **Fraunces** (Google Fonts, weight 300) or **Instrument Serif** as a free equivalent with the same rounded, warm character. Self-host the woff2 rather than pulling from Google's CDN at runtime — a privacy-pitched dictation app shouldn't make a live third-party font request from its own landing page.
- **Body:** keep Quill's existing system stack — `-apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif` — for continuity with the app and for legibility at body sizes (the reference's body font doesn't need copying, only its restraint: plain, quiet, gets out of the way of the serif headlines).
- Hero H1: ~72–88px desktop, weight 300, tight line-height (~1.05).

### Motifs to reuse structurally

- A large, softly blurred two-color gradient blob (`--glow-a` → `--glow-b`) positioned behind the hero product visual — not a hard shape, heavy blur (~30px), low enough opacity to read as ambient light rather than a graphic.
- One dark-surface (`--dark-surface`) full-bleed section breaking up the light page — reserved for Quill's actual strongest claim (see Section 6 below), same as the reference reserves it for its trust/security pitch.
- Footer background transitions into a soft gradient (peach → dusty pink/lavender) rather than staying flat.

---

## 2. Stack recommendation

Reference is Next.js + Tailwind + TypeScript. Two honest options:

- **Recommended: stay plain HTML/CSS/vanilla JS**, matching the current `landing/` approach and the existing plan's reasoning — one page with a form doesn't need a framework's build step or dependency surface, and it stays a zero-build static deploy on Vercel. Structurally recreate the sections below with plain markup + the tokens above.
- **Alternative:** if Antigravity's own defaults strongly prefer scaffolding Next.js/Tailwind, that's acceptable too.

**Waitlist form + backend are Antigravity's responsibility, not this brief's.** Capture **name + email** (not email-only like the current page's Formspree stub) so there's something to address a launch email to. Storage, validation, and the eventual "we're live" notification send are out of scope here — Antigravity owns that end to end. This brief only covers the form's visual placement/styling within the page (see Hero and Final CTA sections below), not its backend.

Either way: self-contained, no server, deploys as a static site.

---

## 3. Page structure & copy (section order matches the reference)

### Nav (floating white pill)

- Logo: Quill mark (reuse `#quill-mark` SVG symbol already defined in the current `landing/index.html`)
- Links: `Features`, `Privacy`
- CTA (dark pill): `Join the waitlist` → scrolls to the waitlist form

No "Log In" — Quill has no account system, ever. Don't add one to match the reference's SaaS nav pattern.

### Hero

- No eyebrow label — go straight into the headline, matching the reference's restraint.
- **Headline** (serif, light, 2 lines):
  > Speak, and it's typed —
  > *nothing leaves this Mac.*
- **Subhead:**
  > Quill transcribes on-device and types directly into whatever you're focused on. No subscription, no account, no audio ever leaving your Mac.
- **Primary CTA** (dark pill button): `Join the Waitlist` — opens/scrolls to the waitlist form, which takes **name + email** (two fields, not email-only). Field styling/placement is this brief's concern; the actual capture/storage/notify-on-launch backend is Antigravity's, per Section 2 above.
- **"Works with" row**, small caption + icon row: `Works in every app you already use` — reuse the existing floating-icon glyph set (Messages, Slack, Notes, Terminal, etc.) already built in the current landing page, rendered small and inline rather than as the floating scattered cluster.
- **Four pill chips** under the CTA (matches reference's "Draft e-mails / Find a file / Organize inbox / Sort by priority" row):
  `Dictate an email` · `Chat on Slack` · `Drop a quick note` · `Write code comments`
- **Hero visual:** a real screenshot of the Quill app (Dictation or Style tab) in a rounded window-chrome frame, sitting in front of the `--glow-a`/`--glow-b` blurred blob. Not an illustration — an actual product screenshot, same as the reference uses a real (mocked) product UI, not decorative art.

### "How it works" (3 steps, replaces reference's "We help professionals save their time")

Section header: `Dictation without the ceremony`

1. **Hold `fn`, speak, release** — *No record button, no stop button.*
2. **It types where your cursor already is** — *No copy-paste, no app switching.*
3. **Nothing leaves this Mac** — *Transcription runs on the Neural Engine, fully offline.*

### Features (5 alternating blocks — eyebrow + heading + 2 short paragraphs + no fake CTA link per block, since there's nothing to click through to yet)

1. **On-device, always** — *Runs on the Neural Engine* — Every word is transcribed locally via CoreML. Nothing is uploaded, recorded remotely, or used to train anything — there's no server in the loop at all.
2. **Auto Cleanup** — *Filler words gone before you see them* — Light mode strips "um," "uh," and stray filler words locally, instantly, for free. Medium goes further with tone-aware rewriting, using your own API key — entirely opt-in.
3. **Switch models on the fly** — *WhisperKit or Parakeet, your call* — Swap transcription engines live from the menu bar, no restart, with real download progress the first time a model's needed.
4. **Works everywhere you type** — *Even the apps that fight back* — Native text fields, browser forms, and Electron apps like Slack and VS Code — Quill's injection handles all of them, including the ones that normally drop synthetic keystrokes.
5. **See your own patterns** — *Dictation history & Insights* — Words-per-minute, a streak calendar, and a record of what got cleaned up — all stored locally, never synced anywhere.

### Pricing → replace entirely with a "Free" section (Quill has no tiers; do not invent any)

Section header: `Free. Not "free trial."`

One card, not three:
> **$0, forever.**
> On-device transcription and Light Auto Cleanup cost nothing and always will. If you turn on Medium's tone rewriting, you bring your own OpenAI or Anthropic key and pay that provider directly — Quill never sees a cent either way.

CTA: `Join the Waitlist`

Optional small comparison line beneath it (factual, matches the app's existing tagline — don't invent numbers beyond this):
> Wispr Flow and Gladio charge a monthly subscription for the same core idea. Quill doesn't.

### Trust section (the one dark `--dark-surface` block — this is Quill's strongest actual claim, use it here)

Headline (with one gradient-highlighted word, same treatment as the reference):
> Actually private, not just *promised*.

2×2 icon grid (outline icons, `--quill-accent` + `--glow-a` tones):
- **On-device transcription** — Every word is processed on this Mac's Neural Engine. Nothing is sent anywhere by default.
- **No account, ever** — There's no sign-up, no login, no user database to breach.
- **No telemetry** — Quill doesn't track usage, doesn't phone home, doesn't know you exist.
- **One clearly-marked exception** — Style's Medium tier sends text to your own API key, only when you turn it on, only to the provider you chose.

Do **not** add SOC2/GDPR/CASA/CCPA-style compliance badges like the reference's footer — those would be false claims for a small local app with no backend.

### FAQ (accordion)

- **What is Quill?** A free, on-device dictation app for macOS. Hold a key, speak, and it types what you said into whatever's focused.
- **Does it need an internet connection?** No — transcription runs entirely offline on the Neural Engine. The only exception is Auto Cleanup's optional Medium tier, which you have to turn on yourself.
- **What happens to my audio?** It's processed in memory and discarded. Nothing is recorded to disk or sent anywhere unless you've explicitly enabled Medium.
- **Is it really free?** Yes. On-device transcription and Light cleanup are free forever. Medium is opt-in and uses your own API key, billed by OpenAI or Anthropic directly.
- **Which Macs does it support?** Apple Silicon Macs (M1 or newer) running macOS 14+.
- **How is this different from Wispr Flow or Gladio?** Same core idea — hotkey dictation that types for you — but free, open, and local-first instead of a paid cloud subscription.

### Final CTA (second, smaller dark `--dark-surface` card)

> **Ready to stop typing?**
> Join the waitlist — free for macOS on Apple Silicon.

Chip row beneath (replaces reference's "free trial / 30-second setup / money-back guarantee" — Quill's honest equivalents):
`Free, forever` · `10-second setup` · `Nothing leaves your Mac`

### Footer

- Quill mark, centered
- Links: `Home`, `Features`, `Privacy`, `GitHub` (link only once the repo is public — omit or point at the waitlist otherwise)
- No social icon row unless real accounts exist to link — don't add placeholder Discord/TikTok/Instagram icons like the reference has
- No compliance badges (see Trust section note above)
- `© 2026 Quill.` — no "All rights reserved" boilerplate needed for a project this size, but harmless if kept

---

## 4. Explicit non-goals (what NOT to carry over from the reference)

- No testimonials section — Quill has zero real users right now; a fabricated quote would be a fabricated quote, full stop. Add this section later, for real, once there's someone to quote.
- No pricing tiers, no "$X/month," no annual/monthly toggle — Quill isn't a SaaS subscription product.
- No fake compliance badges (SOC2/GDPR/CASA/CCPA) — none of that applies to a small local Mac app.
- No "Log In" — there's no account system.
- No copying the reference's actual copy, images, icons, or font file — structure and color tokens only, per the top of this doc.

---

## 5. Verification once built

- Visually compare section-by-section against this brief (not against the reference site directly) to confirm intent was followed, not the letter of Aceai's design.
- Confirm the waitlist form submits name + email to whatever Antigravity wired up on the backend — this replaces the current page's Formspree stub (`YOUR_FORM_ID`, email-only) entirely rather than reusing it.
- Check mobile layout — reference is responsive; new build should collapse the same way the current `landing/styles.css` already does (nav links hide under 768px, form stacks under 640px) unless redesigned intentionally.
- Run it past a private/incognito browser check once deployed, same as any other landing page change.
