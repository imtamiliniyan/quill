// api/waitlist.js — Vercel Serverless Function
// Receives { email, name } from the landing page form and writes
// to Firebase Firestore using the Admin SDK.
// Credentials are read exclusively from environment variables —
// never from the client or source code.

import admin from 'firebase-admin';

// Initialise the Admin SDK once per cold-start
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId:   process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      // Vercel stores \n as a literal escape sequence; restore real newlines
      privateKey:  process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

const db = admin.firestore();

export default async function handler(req, res) {
  // ── CORS ────────────────────────────────────────────────────────────────
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST')   return res.status(405).json({ error: 'Method not allowed' });

  // ── Validate payload ────────────────────────────────────────────────────
  const { email, name } = req.body ?? {};

  if (!email || !name) {
    return res.status(400).json({ error: 'email and name are required' });
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ error: 'Invalid email address' });
  }

  // ── Write to Firestore ──────────────────────────────────────────────────
  try {
    await db.collection('waitlist').add({
      email:     email.toLowerCase().trim(),
      name:      name.trim(),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      source:    req.headers.origin ?? 'landing-page',
    });

    // ── Send Welcome Email via Brevo ──────────────────────────────────────
    const apiKey = process.env.BREVO_API_KEY;
    if (apiKey) {
      try {
        const emailResponse = await fetch('https://api.brevo.com/v3/smtp/email', {
          method: 'POST',
          headers: {
            'accept': 'application/json',
            'api-key': apiKey,
            'content-type': 'application/json'
          },
          body: JSON.stringify({
            sender: {
              name: process.env.BREVO_SENDER_NAME || 'Quill',
              email: process.env.BREVO_SENDER_EMAIL || 'waitlist@updates.quill.chat'
            },
            to: [
              { email, name }
            ],
            subject: "You're on the list — Welcome to Quill",
            htmlContent: `
              <html>
                <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #1a1a1a; max-width: 600px; margin: 0 auto; padding: 40px 20px;">
                  <h1 style="font-family: Georgia, serif; font-weight: 300; font-size: 32px; margin-bottom: 24px;">Welcome to Quill, ${name}.</h1>
                  <p style="font-size: 16px; line-height: 1.6; color: #4a4a4a; margin-bottom: 16px;">
                    Thank you for joining the waitlist! We are hard at work building Quill to bring on-device, privacy-first dictation to macOS.
                  </p>
                  <p style="font-size: 16px; line-height: 1.6; color: #4a4a4a; margin-bottom: 24px;">
                    Because Quill transcribes locally on your Mac's Apple Silicon Neural Engine, <strong>none of your voice data or transcripts ever leave your device</strong>.
                  </p>
                  <hr style="border: 0; border-top: 1px solid #eaeaea; margin: 32px 0;" />
                  <p style="font-size: 12px; color: #999999; text-align: center;">
                    Quill — Speak, and it's typed. Stored locally.
                  </p>
                </body>
              </html>
            `
          })
        });

        if (!emailResponse.ok) {
          const errBody = await emailResponse.text();
          console.error('[waitlist] Brevo email API returned an error:', errBody);
        } else {
          console.log('[waitlist] Welcome email sent successfully via Brevo to:', email);
        }
      } catch (emailErr) {
        console.error('[waitlist] Failed to send welcome email via Brevo:', emailErr);
      }
    } else {
      console.warn('[waitlist] BREVO_API_KEY environment variable is not configured. Skipping email dispatch (Demo Mode).');
    }

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('[waitlist] Firestore write failed:', err);
    return res.status(500).json({ error: 'Failed to save. Please try again.' });
  }
}
