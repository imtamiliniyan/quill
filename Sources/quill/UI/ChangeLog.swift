import Foundation

/// One dated batch of shipped changes, shown on the Change Log sidebar tab.
struct ChangeLogEntry: Identifiable {
    let id: String
    let label: String
    let date: String
    let changes: [String]
}

/// Offline fallback only — as of v0.1.0, the Change Log tab's primary
/// source is GitHub's real Releases (`GitHubReleases.swift`, fetched
/// live from the now-public `imtamiliniyan/quill` repo). This array is
/// what shows before that fetch lands, and what stays showing if it
/// fails (offline, rate-limited). Content is real, not invented: two
/// entries pulled from `git log`'s actual commit dates for the days
/// everything through Phase 4 was committed, one for the large batch
/// that shipped in-app across later sessions before this repo had any
/// tags — same "real number, not a guess" posture as `ModelRegistry`'s
/// sizes and dot ratings.
enum ChangeLog {
    static let entries: [ChangeLogEntry] = [
        ChangeLogEntry(
            id: "2026-08-20",
            label: "Enhancement Engine, more models, and fixes",
            date: "Aug 20, 2026",
            changes: [
                "New Enhancement Engine tab: connect OpenAI, Anthropic, Google, or OpenRouter — or run fully on-device with Local AI, no key needed. One clear \"Active\" badge shows which backend Rewrite and Auto Cleanup actually use.",
                "OpenRouter support, with a searchable picker over its full model catalog.",
                "Voice Engine's model list grew from 4 to 9 — three more Whisper sizes and two more Parakeet variants, including a smaller, faster 110M model.",
                "Auto Cleanup's filler-word list is now editable — add or remove words, or reset to the defaults.",
                "Fixed: Insights' \"Fixes Made by Quill\" card stayed locked for anyone using Google or OpenRouter instead of OpenAI/Anthropic.",
                "Fixed: opening Enhancement Engine could resize the main window unexpectedly.",
                "Fixed: onboarding's Continue button could be cropped off-screen once the model list grew past a handful of options.",
            ]
        ),
        ChangeLogEntry(
            id: "2026-08-11",
            label: "Personalization and control",
            date: "Aug 11, 2026",
            changes: [
                "Choose how dictation starts: Hold, Toggle, or Automatic.",
                "Text Formatting: lowercase first letter, space between dictations, smart capitalization.",
                "Light and dark theme.",
                "Manage downloaded transcription models — switch or delete them — right from Settings.",
            ]
        ),
        ChangeLogEntry(
            id: "2026-08-10",
            label: "First real release: Dictation, Insights, and Style",
            date: "Aug 10, 2026",
            changes: [
                "Menu bar model switcher, with live download progress.",
                "Full app window: Dictation history, Insights (words per minute, streaks, time saved), and Style (automatic cleanup plus your own API key for tone rewriting).",
                "Parakeet added as a second on-device transcription engine, alongside Whisper.",
                "First-run onboarding: permissions, model picker, real download progress.",
            ]
        ),
    ]
}
