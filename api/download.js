// api/download.js — Vercel Serverless Function
// Redirects to the .dmg asset on the newest GitHub Release, whatever
// its exact filename happens to be (currently "Quill OSS <version>.dmg").
//
// Exists because the landing page needs one stable URL to link to
// ("Download for Mac"), but the actual asset filename carries the
// version number and changes every release — GitHub's own
// `releases/latest/download/<name>` shortcut only works for an exact,
// unchanging filename, which this isn't. Resolving the real asset via
// the public Releases API and 302'ing to it keeps the landing page's
// link permanently correct with zero edits on every release.

const REPO = 'imtamiliniyan/quill';

export default async function handler(req, res) {
  try {
    const response = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
      headers: { Accept: 'application/vnd.github+json' },
    });

    if (!response.ok) {
      throw new Error(`GitHub API returned ${response.status}`);
    }

    const release = await response.json();
    const dmgAsset = (release.assets ?? []).find((asset) => asset.name.endsWith('.dmg'));

    if (!dmgAsset) {
      throw new Error('latest release has no .dmg asset');
    }

    // Cached at Vercel's edge so a burst of clicks doesn't hammer the
    // GitHub API — short enough that a fresh release shows up quickly.
    res.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate=3600');
    res.redirect(302, dmgAsset.browser_download_url);
  } catch (err) {
    console.error('[download] Failed to resolve latest .dmg asset:', err);
    // Fall back to the releases page itself — worse than a direct
    // download, but never a dead link.
    res.redirect(302, `https://github.com/${REPO}/releases/latest`);
  }
}
