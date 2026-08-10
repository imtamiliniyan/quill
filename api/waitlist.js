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

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('[waitlist] Firestore write failed:', err);
    return res.status(500).json({ error: 'Failed to save. Please try again.' });
  }
}
