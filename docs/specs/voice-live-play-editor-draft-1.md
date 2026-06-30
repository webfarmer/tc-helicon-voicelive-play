# VoiceLive Play 2 - Draft 1 Technical Design

Date: 2026-06-30

## Purpose

VoiceSupport 2 is useful as a librarian, but it is not a real patch editor. The goal of this project is to build a safer, clearer tool for TC-Helicon VoiceLive Play that can eventually inspect, organize, edit, and send presets without depending on the old VoiceSupport 2 interface.

This draft is intentionally reverse-engineering first. The replacement editor must be based on observed VoiceSupport behavior and verified device traffic, not guesses.

## Current Reference Application

The installed reference application is:

```text
/Applications/VoiceSupport2.app
```

Observed version:

```text
VoiceSupport 2 v1.1.02 build 138
```

The app is a native macOS application. It does not appear to install a custom macOS driver for VoiceLive Play. The device is expected to communicate through class-compliant USB MIDI/audio, with VoiceSupport using MIDI SysEx for preset and device operations.

### Current UI Model

From observed use, VoiceSupport 2 presents:

- A left sidebar with the connected VoiceLive Play device, Backups, and Cloud.
- A main workspace grid of numbered preset slots.
- Toolbar actions:
  - Get Data
  - Apply Changes
  - Send Selected
  - Send Setup
  - Backup User
  - Backup Selected
  - Backup All
  - Select User
  - Optimize Space
  - Toggle View
  - Find Preset
  - Undo / Redo
  - Import / Export
- A lower details panel with:
  - Preset name
  - Tag flags such as Favorite, Showcase, Songs, Pop, Rock, Alternative, Country, Hip Hop/Rap, Dance, Echo, Doubling, Reverb, Harmony, HardTune, Megaphone, Extreme, Character.

### Current App Behavior To Replicate

VoiceSupport 2 can:

- Detect the VoiceLive Play over USB MIDI.
- Read current presets from the device into a workspace grid.
- Back up all or selected presets.
- Rename and tag presets.
- Reorder presets by dragging between numbered slots.
- Show preset packs under Cloud.
- Let the user drag Cloud presets or packs into workspace slots.
- Send selected slots or changed workspace data back to the device.

VoiceSupport 2 does not provide a meaningful sound design editor for VoiceLive Play effect parameters.

## Known Local Data

The working support data is installed at:

```text
~/Library/Application Support/TC-Helicon/VoiceSupport 2/
```

Important files:

```text
masterDescriptor.xml
deviceList.xml
VoiceLive Play/caps.xml
VoiceLive Play/firmware.xml
VoiceLive Play/rules.xml
VoiceLive Play/packs/*.tch
VoiceLive Play/packs/*.xml
VoiceLive Play/packs/packs.zip
```

The raw downloaded working set also exists at:

```text
/Users/paul/VoiceLive Play/
```

### Descriptor Evidence

`masterDescriptor.xml` identifies VoiceLive Play as:

```xml
<product name="VoiceLive Play" sysexId="69" allVersSupportGenSyxID="yes">
```

It points VoiceSupport to:

```text
VoiceSupport2/Descriptors/VoiceLive Play/caps.xml
VoiceSupport2/Descriptors/VoiceLive Play/firmware.xml
VoiceSupport2/Descriptors/VoiceLive Play/rules.xml
VoiceSupport2/Presets/VoiceLive Play/packs.zip
```

`caps.xml` says the VoiceLive Play has:

```text
numPresets=501
presetNameLength=15
presetTagCount=17
activePresetZero=yes
```

Build profile for current observed firmware:

```text
VoiceLive Play 1.5.00 build 74
presetVersion=170
setupVersion=200
```

## Cloud Preset Pack Behavior

The Cloud workflow is central. The replacement app must replicate what VoiceSupport does when a Cloud preset is dragged into a slot.

### Observed Cloud Data

Cloud packs are represented as paired files:

```text
Modern Rock Pack.xml
Modern Rock Pack.tch
```

Example metadata from `Modern Rock Pack.xml`:

```xml
<ARCHIVE>
  <uuid>d5d6bf5c5e34441fa3152814b23c7df5</uuid>
  <md5>1e62a51e6b0184d4915fb339f6a34275</md5>
  <arVersion>132</arVersion>
  <product sysexId="69"/>
  <buildNo>65</buildNo>
  <author name="TC-Helicon" id="1"/>
  <title>Modern Rock Pack</title>
  <description>Modern Rock billboard toppers from the end of 2015 through Spring 2016. Rock on!</description>
  <linkImage>ModernRockPack.png</linkImage>
  <linkData>Modern Rock Pack.tch</linkData>
</ARCHIVE>
```

The `.tch` file is binary. It starts with readable archive metadata:

```text
0.1.0.1.132.0
VoiceLive Play
0.1.3.0.65.28
```

The `.tch` body contains preset records and SysEx-like byte sequences. TC-Helicon SysEx messages observed in firmware and pack data use manufacturer prefix:

```text
F0 00 01 38 ...
```

### Cloud Drag Hypothesis

When a user drags a Cloud preset into a workspace slot, VoiceSupport probably:

1. Loads pack metadata from `.xml`.
2. Loads pack data from `.tch`.
3. Parses one or more preset records from the `.tch`.
4. Converts or validates preset data against current `caps.xml` and firmware build.
5. Inserts the preset into the in-memory workspace grid at the target slot.
6. Marks the workspace as dirty.
7. On Send Selected or Apply Changes, emits one or more SysEx messages to write the slot.

This hypothesis must be verified with filesystem and MIDI captures.

## Reverse Engineering Plan

The project should capture three layers separately: cloud/file, workspace/backup, and MIDI/SysEx.

### Layer 1: Cloud And Local Files

Capture what VoiceSupport reads when Cloud is expanded and when a Cloud preset is dragged into a slot.

Tools:

- `fs_usage` for file activity.
- `lsof` for open files.
- A controlled copy of `~/Library/Application Support/TC-Helicon/VoiceSupport 2`.
- Hashes before and after drag operations.

Questions to answer:

- Does VoiceSupport read `packs.zip` directly?
- Does it unzip to a temp folder?
- Does it parse individual `.tch` files directly?
- Does dragging a Cloud item create `working.tch`, `sync.tch`, or another temporary file?
- Is the workspace state stored immediately or only after backup/export?

### Layer 2: Preset Archive Format

Build a read-only parser for `.tch` files.

Initial parser goals:

- Read archive header.
- Identify product name and product SysEx ID.
- Extract preset count.
- Extract preset names.
- Identify record boundaries.
- Extract raw SysEx blocks.
- Preserve unknown bytes exactly.

Round-trip requirement:

```text
decode .tch -> encode .tch -> byte-identical output
```

No write-to-device work should happen until read-only parsing can round-trip known files.

### Layer 3: MIDI And SysEx

Capture exactly what VoiceSupport sends and receives.

Operations to capture:

- Device detection.
- Get Data.
- Backup Selected.
- Backup All.
- Drag Cloud preset into slot, then Send Selected.
- Rename preset, then Send Selected.
- Change tag, then Send Selected.
- Send Setup.

Tools:

- Snoize MIDI Monitor for human-readable inspection.
- Python with CoreMIDI via `mido` and `python-rtmidi`.
- Optional virtual MIDI loopback if VoiceSupport traffic can be routed or mirrored.

Questions to answer:

- What SysEx command reads one preset?
- What SysEx command writes one preset?
- How is the target preset slot encoded?
- Is there a checksum?
- Is the preset name stored inside the same SysEx block?
- Are tags stored inside the same preset block or separate metadata?
- Does VoiceSupport split one preset into multiple SysEx packets?
- Does the device acknowledge writes?

## Safety Model

The project must avoid bricking or corrupting the VoiceLive Play.

### Allowed In Early Milestones

- Reading local files.
- Parsing `.tch`, `.xml`, and `.syx`.
- Capturing MIDI/SysEx passively.
- Reading presets from the device.
- Writing test data only to an unused preset slot after proven round-trip.

### Not Allowed Until Explicitly Implemented And Reviewed

- Firmware updates.
- Bootloader commands.
- Bulk device writes.
- Sending hand-edited unknown binary data.
- Writing to all slots.
- Sending setup/global data.

### Write Safety Rules

Before any device write:

1. Confirm connected device name and firmware build.
2. Confirm target slot.
3. Require a fresh backup file.
4. Validate message length and checksum if known.
5. Write one slot only.
6. Read the slot back and compare.
7. Keep a recovery backup ready in VoiceSupport.

## Proposed Replacement Architecture

The project should be built in phases.

### Phase 1: Python Reverse-Engineering Toolkit

Purpose: learn the format safely.

Modules:

- `vlp2.files`
  - Locate support data.
  - Read descriptors.
  - Read pack metadata.
- `vlp2.tch`
  - Parse `.tch` archive headers.
  - Extract preset records.
  - Round-trip encode.
- `vlp2.sysex`
  - Split and classify SysEx messages.
  - Identify manufacturer, product, command, payload.
- `vlp2.diff`
  - Compare preset files and backups.
  - Highlight changed offsets and candidate fields.
- `vlp2.midi`
  - List MIDI ports.
  - Passive capture.
  - Later: safe single-slot send.

Command examples:

```bash
vlp2 inspect-pack "Modern Rock Pack.tch"
vlp2 list-presets "Modern Rock Pack.tch"
vlp2 diff-preset before.tch after.tch
vlp2 midi-monitor
vlp2 send-slot --slot 300 --preset extracted/adv-of-lifetime.bin
```

### Phase 2: Local Web UI

Purpose: fast iteration on usability without committing to native UI too early.

Shape:

- Local backend handles files, parsing, and CoreMIDI.
- Browser UI shows preset library, slot grid, and inspector.
- No hosted/cloud dependency.

Views:

- Device status.
- Preset grid.
- Cloud pack browser.
- Backup browser.
- Preset inspector.
- Diff view.
- Safe send dialog.

### Phase 3: Native macOS App

Purpose: polished daily-use replacement.

Likely stack:

- SwiftUI shell.
- CoreMIDI device layer.
- Reuse parser logic via Swift port, Python service, or Rust library.

Native app advantages:

- Better MIDI integration.
- Better local file permissions.
- Cleaner drag/drop.
- Better long-term Mac usability.

## Future Patch Editor

Real patch editing requires parameter mapping.

Approach:

1. Pick one factory preset.
2. Back it up.
3. Change one parameter on hardware.
4. Back up again.
5. Diff before/after.
6. Repeat across parameters.

Parameter groups to map:

- Harmony
- Delay
- Reverb
- Double
- HardTune
- Megaphone
- uMod
- Transducer/character
- Tone/correction
- Preset name
- Tags

The editor must show unknown parameters as raw fields until mapped. The first editable release should only expose parameters that have been verified by repeated diffs.

## Draft UI Direction

The replacement app should not copy VoiceSupport 2 exactly. It should preserve the working concepts and improve the weak parts.

Core screens:

- Library
  - All packs, backups, and device presets.
  - Search and tags.
- Device
  - 500-slot grid.
  - Clear dirty state.
  - Backup before write.
- Patch Inspector
  - Preset name, tags, raw metadata.
  - Known effect parameters as they are mapped.
- Compare
  - Before/after diff.
  - Human-readable field changes where known.
- Send
  - Explicit target slot.
  - Safety checklist.
  - Read-back verification.

## Milestones

### Milestone 0: Evidence Capture

Deliverables:

- Record exact VoiceSupport workflows.
- Capture file activity for Cloud drag.
- Capture MIDI activity for Get Data, Backup, Send Selected.
- Save captures under `captures/`.

### Milestone 1: Read-Only Pack Inspector

Deliverables:

- Python CLI.
- Parse pack XML.
- Parse `.tch` header.
- Extract visible preset names.
- Report product/build compatibility.

### Milestone 2: Round-Trip Parser

Deliverables:

- Decode/encode `.tch` with byte-identical output.
- Unit tests against all local packs.
- Unknown fields preserved.

### Milestone 3: Backup And SysEx Inspector

Deliverables:

- Parse VoiceSupport backup/export files.
- Split SysEx messages.
- Compare outgoing VoiceSupport SysEx to `.tch` records.

### Milestone 4: Safe Single-Slot Sender

Deliverables:

- List MIDI ports.
- Confirm VoiceLive Play target.
- Send one known-good preset to one chosen slot.
- Read back and verify.

### Milestone 5: Basic Editor Prototype

Deliverables:

- Rename preset.
- Change tags.
- Modify first verified effect parameter group.
- Save and send to one slot.

## Open Questions

- Where exactly does VoiceSupport store workspace state after a Cloud drag?
- Does `Export` produce `.syx`, `.tch`, XML, or another format depending on selection?
- Is the toolbar `Import` only for `.syx`, or does it accept `.tch` under specific app states?
- How are preset slots encoded in write SysEx?
- Does the device have a checksum or CRC requirement for preset writes?
- Which MIDI port is input vs output for VoiceLive Play on macOS?
- Can SysEx traffic from VoiceSupport be passively mirrored, or do we need controlled replay using Python?

## Immediate Next Actions

1. Create a file activity capture while expanding Cloud and dragging one preset into an empty slot.
2. Create a MIDI capture while sending that one slot.
3. Export or back up the resulting slot.
4. Compare:
   - Source `.tch`
   - Workspace/export/backup artifact
   - Captured outgoing SysEx
5. Start the read-only `.tch` parser only after the above capture artifacts are saved.

