# VoiceLive Play 2

Reverse-engineering and replacement-editor project for TC-Helicon VoiceLive Play.

The current reference application is VoiceSupport 2. It works as a basic librarian, but the goal here is to understand its file, Cloud preset, and MIDI/SysEx behavior well enough to build a safer and more capable editor.

## Draft 1

Start here:

```text
docs/specs/voice-live-play-editor-draft-1.md
```

That document covers:

- how VoiceSupport 2 currently behaves
- how Cloud preset packs appear to work
- which local files matter
- what needs to be captured from filesystem and MIDI traffic
- safety rules for avoiding firmware/device damage
- a phased path from Python reverse-engineering tools to a future macOS editor

## Project Folders

```text
captures/       Raw MIDI, SysEx, screen, and filesystem captures
docs/research/  Notes from experiments and reverse-engineering sessions
docs/specs/     Product and technical design documents
samples/        Small copied test fixtures, not full device backups unless intentional
scripts/        One-off research scripts and future CLI prototypes
```

## Current Principle

Do not invent a patch format first. Observe exactly how VoiceSupport turns a Cloud preset dragged into a numbered slot into local workspace data and outgoing SysEx.

The first working milestone is read-only inspection. Device writes come later, only after backup, round-trip, and SysEx validation are proven.

