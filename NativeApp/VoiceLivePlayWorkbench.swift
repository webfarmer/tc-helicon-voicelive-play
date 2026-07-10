import SwiftUI
import Foundation
import CoreMIDI
import AppKit
import UniformTypeIdentifiers

struct Catalog: Decodable {
    let generatedAt: String?
    let source: String?
    let packs: [PresetPack]
}

struct PresetPack: Decodable, Identifiable {
    var id: String { uuid }
    let title: String
    let description: String?
    let productSysexId: Int?
    let buildNo: Int?
    let uuid: String
    let linkImage: String?
    let xmlFile: String?
    let tchFile: String?
    let presetCount: Int
    let sysexBlockCount: Int
    let presetNames: [String]
}

struct WorkspaceSlot: Identifiable, Codable {
    let id: Int
    var name: String
    var payloadName: String? = nil
    var source: String
    var dirty: Bool
    var payloadMessages: [Data]? = nil
}

struct WorkspaceSnapshot: Codable {
    var slots: [WorkspaceSlot]
    var source: String
    var report: String
}

struct BackupArchive: Identifiable {
    var id: String { xmlPath }
    let title: String
    let xmlPath: String
    let dataPath: String
    let presetNames: [String]
    let slots: [WorkspaceSlot]?
}

struct BoardArchive: Identifiable, Codable {
    let id: String
    var title: String
    var slots: [WorkspaceSlot]
    var report: String
    var updatedAt: String
}

struct CustomPreset: Identifiable, Codable {
    let id: String
    var title: String
    var payloadName: String?
    var source: String
    var notes: String
    var payloadMessages: [Data]? = nil
    var updatedAt: String
}

struct AppBackupArchive: Identifiable, Codable {
    let id: String
    var title: String
    var slots: [WorkspaceSlot]
    var report: String
    var updatedAt: String
}

struct CloudSearchResult: Identifiable {
    let id: String
    let packTitle: String
    let presetName: String
}

struct DeviceStatus {
    var connected = false
    var midiConfirmed = false
    var title = "Checking..."
    var detail = "Device scan will start after the UI loads"
}

struct PresetSysexPayload {
    let slotID: Int
    let name: String
    let source: String
    let messages: [Data]
}

struct PushProgress {
    var isActive = false
    var total = 0
    var completed = 0
    var currentSlot = 0
    var currentPreset = ""
    var log: [String] = []

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

enum FocusArea {
    case boards
    case backups
    case cloud
    case presets
    case workspace
}

enum PushResult {
    case success
    case failure(String)
}

enum PushEvent {
    case started(index: Int, total: Int, slotID: Int, name: String)
    case completed(index: Int, total: Int, slotID: Int, name: String)
}

struct EffectControl: Identifiable {
    let id: Int
    let section: String
    let name: String
    let kind: EffectControlKind
    let packetIndex: Int
    let byteOffset: Int
}

enum EffectControlKind {
    case toggle
    case level
    case choice([String])
}

struct PresetTemplate: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let sourcePreset: String
}

struct FirmwareUpdateInfo: Identifiable {
    var id: String { version }
    let version: String
    let pubDate: String
    let notes: [String]
    let link: String
    let localPath: String?
}

struct PackCard: View {
    let pack: PresetPack
    let imageURL: URL?
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let imageURL, let nsImage = NSImage(contentsOf: imageURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: tileColors(for: pack.title),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(initials(pack.title))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("generated")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.28))
                                .cornerRadius(4)
                        }
                        .padding(5)
                    }
                }
            }
            .frame(height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(pack.title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(pack.presetCount) presets")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(7)
        .frame(minHeight: 142, alignment: .top)
        .background(selected ? Color(red: 0.86, green: 0.92, blue: 1.0) : Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.blue : Color.gray.opacity(0.25), lineWidth: selected ? 2 : 1)
        )
        .cornerRadius(8)
    }

    func initials(_ title: String) -> String {
        let words = title
            .replacingOccurrences(of: "Factory", with: "")
            .split(separator: " ")
            .filter { !$0.isEmpty }
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "VL" : String(letters).uppercased()
    }

    func tileColors(for title: String) -> [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.09, green: 0.47, blue: 0.79), Color(red: 0.20, green: 0.72, blue: 0.57)],
            [Color(red: 0.55, green: 0.21, blue: 0.63), Color(red: 0.94, green: 0.44, blue: 0.40)],
            [Color(red: 0.87, green: 0.49, blue: 0.12), Color(red: 0.98, green: 0.79, blue: 0.21)],
            [Color(red: 0.18, green: 0.25, blue: 0.40), Color(red: 0.35, green: 0.55, blue: 0.75)],
            [Color(red: 0.13, green: 0.55, blue: 0.32), Color(red: 0.63, green: 0.80, blue: 0.25)],
        ]
        let index = abs(title.hashValue) % palettes.count
        return palettes[index]
    }
}

struct PackBrowserRow: View {
    let pack: PresetPack
    let imageURL: URL?
    let selected: Bool

    var body: some View {
        HStack(spacing: 8) {
            PackThumbnail(imageURL: imageURL, fallback: pack.title)
                .frame(width: 20, height: 20)
            Text(displayTitle(pack.title))
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(selected ? .white : .primary)
            Spacer()
            Text("\(pack.presetCount)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(selected ? .white.opacity(0.85) : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color(red: 0.10, green: 0.46, blue: 0.78) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(selected ? Color.white.opacity(0.75) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(3)
        .contentShape(Rectangle())
    }

    func displayTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "Factory", with: "")
            .replacingOccurrences(of: "Songs/Artists", with: "Songs")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct BackupRow: View {
    let backup: BackupArchive
    let selected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("▣")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(selected ? .white : Color(red: 0.10, green: 0.46, blue: 0.78))
            VStack(alignment: .leading, spacing: 2) {
                Text(backup.title)
                    .font(.system(size: 11, weight: selected ? .bold : .regular))
                    .lineLimit(1)
                Text("\(backup.presetNames.count) presets")
                    .font(.system(size: 9))
                    .foregroundColor(selected ? .white.opacity(0.80) : .secondary)
            }
            .foregroundColor(selected ? .white : .primary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color(red: 0.10, green: 0.46, blue: 0.78) : Color.clear)
        .cornerRadius(3)
        .contentShape(Rectangle())
    }
}

struct CustomPresetRow: View {
    let preset: CustomPreset
    let detail: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("▤")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(selected ? .white : Color(red: 0.10, green: 0.46, blue: 0.78))
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.title)
                    .font(.system(size: 11, weight: selected ? .bold : .regular))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundColor(selected ? .white.opacity(0.80) : .secondary)
                    .lineLimit(1)
            }
            .foregroundColor(selected ? .white : .primary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color(red: 0.10, green: 0.46, blue: 0.78) : Color.clear)
        .cornerRadius(3)
        .contentShape(Rectangle())
    }
}

struct EffectSectionView: View {
    let title: String
    let controls: [EffectControl]
    let value: (EffectControl) -> Int
    let setValue: (EffectControl, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
            ForEach(controls) { control in
                HStack(spacing: 10) {
                    Text(control.name)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 104, alignment: .leading)
                    switch control.kind {
                    case .toggle:
                        Toggle("", isOn: Binding(
                            get: { value(control) >= 64 },
                            set: { setValue(control, $0 ? 127 : 0) }
                        ))
                        .labelsHidden()
                    case .level:
                        Slider(
                            value: Binding(
                                get: { Double(value(control)) },
                                set: { setValue(control, Int($0.rounded())) }
                            ),
                            in: 0...127,
                            step: 1
                        )
                        Text("\(value(control))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .frame(width: 30, alignment: .trailing)
                    case .choice(let options):
                        Picker("", selection: Binding(
                            get: { min(value(control) % max(options.count, 1), max(options.count - 1, 0)) },
                            set: { setValue(control, $0) }
                        )) {
                            ForEach(Array(options.enumerated()), id: \.offset) { index, label in
                                Text(label).tag(index)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.96, green: 0.98, blue: 0.99))
        .overlay(Rectangle().stroke(Color.black.opacity(0.18), lineWidth: 1))
    }
}

struct BoardRow: View {
    let board: BoardArchive
    let selected: Bool
    let loaded: Bool
    let dropTarget: Bool
    let loadAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("▦")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(selected ? .white : Color(red: 0.10, green: 0.46, blue: 0.78))
            VStack(alignment: .leading, spacing: 2) {
                Text(board.title)
                    .font(.system(size: 11, weight: selected ? .bold : .regular))
                    .lineLimit(1)
                Text("\(board.report) · \(board.updatedAt)")
                    .font(.system(size: 9))
                    .foregroundColor(selected ? .white.opacity(0.80) : .secondary)
            }
            .foregroundColor(selected ? .white : .primary)
            Spacer()
            if selected {
                Button(loaded ? "Loaded" : "Load") {
                    loadAction()
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(loaded ? Color.black.opacity(0.35) : Color.black)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
                .disabled(loaded)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color(red: 0.10, green: 0.46, blue: 0.78) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(dropTarget ? Color.black : Color.clear, lineWidth: 3)
        )
        .cornerRadius(3)
        .contentShape(Rectangle())
    }
}

struct PackThumbnail: View {
    let imageURL: URL?
    let fallback: String

    var body: some View {
        ZStack {
            if let imageURL, let nsImage = NSImage(contentsOf: imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(red: 0.55, green: 0.63, blue: 0.68))
                Text(String(fallback.prefix(1)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

struct WorkspaceCell: View {
    let slot: WorkspaceSlot
    let selected: Bool
    let dropTarget: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(String(format: "%03d", slot.id))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor((selected || slot.dirty || dropTarget) ? .white : .secondary)
                Spacer()
                if slot.dirty {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
            }
            Text(slot.name)
                .font(.system(size: 10, weight: slot.name == "BLANK PRESET" ? .regular : .semibold))
                .foregroundColor((selected || slot.dirty || dropTarget) ? .white : .primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(6)
        .frame(minHeight: 52, maxHeight: 52)
        .background(cellBackground)
        .overlay(
            Rectangle()
                .stroke(dropTarget ? Color.orange : Color.black, lineWidth: dropTarget ? 3 : (selected ? 2 : 1))
        )
        .contentShape(Rectangle())
    }

    var cellBackground: Color {
        if dropTarget {
            return Color(red: 0.08, green: 0.08, blue: 0.08)
        }
        if selected {
            return slot.dirty ? Color(red: 0.16, green: 0.16, blue: 0.16) : Color.black
        }
        if slot.dirty {
            return Color(red: 0.24, green: 0.24, blue: 0.24)
        }
        return slot.name == "BLANK PRESET"
            ? Color(red: 0.86, green: 0.91, blue: 0.93)
            : Color(red: 0.49, green: 0.65, blue: 0.84)
    }
}

struct PresetRow: View {
    let name: String
    let selected: Bool

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 12, weight: selected ? .bold : .regular))
                .foregroundColor(selected ? .white : .primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color(red: 0.10, green: 0.46, blue: 0.78) : Color.clear)
        .contentShape(Rectangle())
    }
}

struct PresetGridCell: View {
    let name: String
    let selected: Bool

    var body: some View {
        Text(name)
            .font(.system(size: 11, weight: selected ? .bold : .regular))
            .foregroundColor(selected ? .white : .primary)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(selected ? Color.black : Color.white)
            .overlay(Rectangle().stroke(Color.gray.opacity(0.20), lineWidth: 1))
            .contentShape(Rectangle())
    }
}

struct SearchPresetGridCell: View {
    let result: CloudSearchResult
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(result.presetName)
                .font(.system(size: 11, weight: selected ? .bold : .regular))
                .foregroundColor(selected ? .white : .primary)
                .lineLimit(1)
            Text(result.packTitle)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(selected ? .white.opacity(0.82) : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(selected ? Color(red: 0.10, green: 0.46, blue: 0.78) : Color.white)
        .overlay(Rectangle().stroke(Color.gray.opacity(0.20), lineWidth: 1))
        .contentShape(Rectangle())
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        let content = WorkbenchView()
            .frame(minWidth: 1180, minHeight: 760)

        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 1512, height: 889),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoiceLive Play Workbench"
        window.identifier = NSUserInterfaceItemIdentifier("VoiceLivePlayWorkbenchMainWindow")
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 1180, height: 760)
        if let screen = NSScreen.screens.min(by: { $0.visibleFrame.minX < $1.visibleFrame.minX }) {
            let visible = screen.visibleFrame
            let width = min(1512, visible.width - 80)
            let height = min(889, visible.height - 80)
            let origin = NSPoint(x: visible.minX + 40, y: visible.maxY - height - 40)
            window.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct WorkbenchView: View {
    @State private var catalog = Catalog(generatedAt: nil, source: nil, packs: [])
    @State private var selectedPackID: String?
    @State private var selectedPreset: String?
    @State private var selectedPresetSourceTitle: String?
    @State private var selectedSlotID = 1
    @State private var search = ""
    @State private var workspace = Self.voiceSupportSnapshot()
    @State private var workspaceSource = "Loaded presets"
    @State private var workspaceReport = "249/500"
    @State private var boards: [BoardArchive] = []
    @State private var customPresets: [CustomPreset] = []
    @State private var selectedBoardID: String?
    @State private var selectedCustomPresetID: String?
    @State private var loadedBoardID: String?
    @State private var loadedBoardBaseline: BoardArchive?
    @State private var dropTargetBoardID: String?
    @State private var dropTargetSlotID: Int?
    @State private var boardNameDraft = ""
    @State private var renamingBoardID: String?
    @State private var copiedBoard: BoardArchive?
    @State private var copiedSlot: WorkspaceSlot?
    @State private var backups: [BackupArchive] = []
    @State private var selectedBackupID: String?
    @State private var backupsExpanded = true
    @State private var cloudExpanded = true
    @State private var device = DeviceStatus()
    @State private var activeArea: FocusArea = .workspace
    @State private var showingDeviceImage = false
    @State private var pushProgress = PushProgress()
    @State private var showingPushProgress = false
    @State private var showingFirmwareSheet = false
    @State private var devicePullDataPath: String?
    @State private var endpointStatus = "Checking endpoint..."
    @State private var latestFirmware = "Unknown"
    @State private var firmwareUpdates: [FirmwareUpdateInfo] = []
    @State private var status = "Loading workbench..."

    private let root = URL(fileURLWithPath: Bundle.main.bundlePath)
        .deletingLastPathComponent()

    var deviceIconURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/TC-Helicon/VoiceSupport 2/VoiceLive Play/icon.png")
    }

    var selectedPack: PresetPack? {
        guard let selectedPackID else { return nil }
        return catalog.packs.first { $0.id == selectedPackID }
    }

    var selectedBackup: BackupArchive? {
        guard let selectedBackupID else { return nil }
        return backups.first { $0.id == selectedBackupID }
    }

    var selectedBoard: BoardArchive? {
        guard let selectedBoardID else { return nil }
        return boards.first { $0.id == selectedBoardID }
    }

    var loadedBoard: BoardArchive? {
        guard let loadedBoardID else { return nil }
        return boards.first { $0.id == loadedBoardID }
    }

    var selectedCustomPreset: CustomPreset? {
        guard let selectedCustomPresetID else { return nil }
        return customPresets.first { $0.id == selectedCustomPresetID }
    }

    var filteredPresets: [String] {
        let presets = selectedPack?.presetNames ?? []
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return presets }
        return presets.filter { $0.lowercased().contains(needle) }
    }

    var cloudSearchResults: [CloudSearchResult] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return catalog.packs.flatMap { pack in
            pack.presetNames
                .filter { preset in
                    preset.lowercased().contains(needle)
                        || pack.title.lowercased().contains(needle)
                }
                .map { preset in
                    CloudSearchResult(
                        id: "\(pack.uuid)::\(preset)",
                        packTitle: pack.title,
                        presetName: preset
                    )
                }
        }
    }

    var occupiedSlots: Int {
        workspace.filter { $0.name != "BLANK PRESET" }.count
    }

    var effectSections: [String] {
        ["μMod", "Delay", "Reverb", "Harmony", "Double", "HardTune", "Transducer"]
    }

    var effectControls: [EffectControl] {
        let control = ["Off", "On", "Hit"]
        let modStyles = [
            "MICROMOD CLONE", "MICROMOD WIDER", "THICKEN", "LIGHT CHORUS", "MEDIUM CHORUS", "WIDE CHORUS",
            "MONO CHORUS", "FAST ROTOR", "FLANGER", "FLANGE FEEDBACK", "FLANGE NEGATIVE", "MONO FLANGE",
            "SOFT FLANGE", "PANNER", "TUBE", "UP TUBE", "DOWN TUBE", "DOWN & UP TUBE", "RISE AND FALL",
            "OTTAWA WIDE", "CYLON MONO", "CYLON STEREO", "ALIEN VOICEOVER", "UNDERWATER"
        ]
        let delayStyles = [
            "QUARTER", "EIGHTH", "TRIPLET", "DOTTED", "LONGDOT", "LONGTRIP", "SIXTEENTH",
            "PINGPONG 1", "PINGPONG 2", "PINGPONG 3", "MULTITAP 1", "MULTITAP 2", "MULTITAP 3",
            "MULTITAP 4", "MULTITAP 5", "MULTITAP 6", "CLASSICSLAP", "SINGLESLAP"
        ]
        let delayFilters = [
            "Digital", "Tape", "Analog", "Radio", "Megaphone", "Cell Phone", "Lo-Fi",
            "Hi Cut 1", "Hi Cut 2", "Hi Cut 3", "Low Cut 1", "Low Cut 2", "Low Cut 3"
        ]
        let reverbStyles = [
            "SMOOTH PLATE", "REFLECTION PLATE", "THIN PLATE", "BRIGHT PLATE", "REAL PLATE",
            "REAL PLATE LONG", "JAZZ PLATE", "QUICK PLATE", "SOFT HALL", "AMSTERDAM HALL",
            "BROADWAY HALL", "SNAPPY ROOM", "LIBRARY", "DARK ROOM", "MUSIC CLUB", "STUDIO ROOM",
            "WAREHOUSE", "BOUNCY ROOM", "BRIGHT CHAMBER", "WOODEN CHAMBER", "ST. JOSEPH CHURCH",
            "DOME CHAPEL", "HOCKEY ARENA", "MUSEUM", "INDOOR ARENA", "COZY CORNER", "THIN SPRING",
            "FULL SPRING"
        ]
        let harmonyStyles = [
            "HIGH", "HIGHER", "LOW", "LOWER", "OCTAVE UP", "OCTAVE DOWN", "HIGH & LOW",
            "HIGH & HIGHER", "HIGH & LOWER", "HIGHER & LOWER", "HIGHER & LOW", "LOWER & LOW",
            "OCT DOWN & UP", "OCT DOWN & HIGHER", "OCT DOWN & HIGH", "OCT DOWN & LOW",
            "OCT DOWN & LOWER", "OCT UP & HIGHER", "OCT UP & HIGH", "OCT UP & LOW",
            "OCT UP & LOWER", "+7 SEMITONES", "-5 SEMITONES", "+7 & -5 SEMITONES",
            "+12 & +7 SEMITONES", "+12 & -5 SEMITONES", "-12 & +7 SEMITONES", "-12 & -5 SEMITONES"
        ]
        let harmonyKeys = ["Auto", "C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
        let harmonyScales = ["MAJOR 1", "MAJOR 2", "MAJOR 3", "MINOR 1", "MINOR 2", "MINOR 3"]
        let doubleStyles = [
            "1 VOICE TIGHT", "1 VOICE LOOSE", "2 VOICES TIGHT", "2 VOICES LOOSE", "SHOUT",
            "1 VOICE OCT UP", "1 VOICE OCT DOWN", "2 VOICES OCT UP", "2 VOICES OCT DOWN", "OCT UP & OCT DOWN"
        ]
        let hardTuneStyles = ["POP", "COUNTRY GLISS", "ROBOT", "CORRECT NATURAL", "CORRECT CHROMATIC", "DRONE", "GENDER BENDER"]
        let transducerStyles = ["MEGAPHONE", "RADIO", "ON THE PHONE", "OVERDRIVE", "BUZZ CUT", "STACK", "TWEED", "COMBO"]
        let routing = ["Output", "FX"]

        return [
            EffectControl(id: 0, section: "μMod", name: "Control", kind: .choice(control), packetIndex: 0, byteOffset: 0),
            EffectControl(id: 1, section: "μMod", name: "Level", kind: .level, packetIndex: 0, byteOffset: 1),
            EffectControl(id: 2, section: "μMod", name: "Style", kind: .choice(modStyles), packetIndex: 0, byteOffset: 2),

            EffectControl(id: 3, section: "Delay", name: "Control", kind: .choice(control), packetIndex: 0, byteOffset: 8),
            EffectControl(id: 4, section: "Delay", name: "Feedback", kind: .level, packetIndex: 0, byteOffset: 9),
            EffectControl(id: 5, section: "Delay", name: "Style", kind: .choice(delayStyles), packetIndex: 0, byteOffset: 10),
            EffectControl(id: 6, section: "Delay", name: "Filter Style", kind: .choice(delayFilters), packetIndex: 0, byteOffset: 11),

            EffectControl(id: 7, section: "Reverb", name: "Control", kind: .choice(control), packetIndex: 0, byteOffset: 16),
            EffectControl(id: 8, section: "Reverb", name: "Level", kind: .level, packetIndex: 0, byteOffset: 17),
            EffectControl(id: 9, section: "Reverb", name: "Decay", kind: .level, packetIndex: 0, byteOffset: 18),
            EffectControl(id: 10, section: "Reverb", name: "Style", kind: .choice(reverbStyles), packetIndex: 0, byteOffset: 19),

            EffectControl(id: 11, section: "Harmony", name: "Control", kind: .choice(control), packetIndex: 1, byteOffset: 0),
            EffectControl(id: 12, section: "Harmony", name: "Level", kind: .level, packetIndex: 1, byteOffset: 1),
            EffectControl(id: 13, section: "Harmony", name: "Key", kind: .choice(harmonyKeys), packetIndex: 1, byteOffset: 2),
            EffectControl(id: 14, section: "Harmony", name: "Style", kind: .choice(harmonyStyles), packetIndex: 1, byteOffset: 3),
            EffectControl(id: 15, section: "Harmony", name: "Scale", kind: .choice(harmonyScales), packetIndex: 1, byteOffset: 4),

            EffectControl(id: 16, section: "Double", name: "Control", kind: .choice(control), packetIndex: 1, byteOffset: 8),
            EffectControl(id: 17, section: "Double", name: "Level", kind: .level, packetIndex: 1, byteOffset: 9),
            EffectControl(id: 18, section: "Double", name: "Style", kind: .choice(doubleStyles), packetIndex: 1, byteOffset: 10),

            EffectControl(id: 19, section: "HardTune", name: "Control", kind: .choice(control), packetIndex: 1, byteOffset: 16),
            EffectControl(id: 20, section: "HardTune", name: "Shift", kind: .level, packetIndex: 1, byteOffset: 17),
            EffectControl(id: 21, section: "HardTune", name: "Gender", kind: .level, packetIndex: 1, byteOffset: 18),
            EffectControl(id: 22, section: "HardTune", name: "Style", kind: .choice(hardTuneStyles), packetIndex: 1, byteOffset: 19),

            EffectControl(id: 23, section: "Transducer", name: "Control", kind: .choice(control), packetIndex: 1, byteOffset: 24),
            EffectControl(id: 24, section: "Transducer", name: "Drive", kind: .level, packetIndex: 1, byteOffset: 25),
            EffectControl(id: 25, section: "Transducer", name: "Filter", kind: .level, packetIndex: 1, byteOffset: 26),
            EffectControl(id: 26, section: "Transducer", name: "Style", kind: .choice(transducerStyles), packetIndex: 1, byteOffset: 27),
            EffectControl(id: 27, section: "Transducer", name: "Routing", kind: .choice(routing), packetIndex: 1, byteOffset: 28),
            EffectControl(id: 28, section: "Transducer", name: "Gate Threshold", kind: .level, packetIndex: 1, byteOffset: 29),
            EffectControl(id: 29, section: "Transducer", name: "Gain", kind: .level, packetIndex: 1, byteOffset: 30),
        ]
    }

    var presetTemplates: [PresetTemplate] {
        [
            PresetTemplate(id: "clean", title: "Clean vocal", subtitle: "A neutral starting point", sourcePreset: "PRACTICE ROOM"),
            PresetTemplate(id: "mod", title: "μMod / chorus", subtitle: "Chorus, flange, rotor, panner and thickening", sourcePreset: "NICE CHORUS"),
            PresetTemplate(id: "delay", title: "Delay", subtitle: "Tempo echo, ping-pong, multitap and slap styles", sourcePreset: "1/4 DELAY"),
            PresetTemplate(id: "reverb", title: "Reverb", subtitle: "Plate, hall, room, chamber, arena and spring spaces", sourcePreset: "GORGEOUS HALL"),
            PresetTemplate(id: "harmony", title: "Harmony", subtitle: "High, low, octave and fixed-interval backing voices", sourcePreset: "POP DUO"),
            PresetTemplate(id: "double", title: "Double", subtitle: "One or two voices, tight/loose, shout and octave doubles", sourcePreset: "DOUBLE UP"),
            PresetTemplate(id: "hardtune", title: "HardTune", subtitle: "Pop, robot, natural correction and gender styles", sourcePreset: "AUTOTUNE RADIO"),
            PresetTemplate(id: "transducer", title: "Transducer", subtitle: "Megaphone, radio, phone, overdrive and amp colors", sourcePreset: "MEGAPHONE"),
        ]
    }

    var selectedSlot: WorkspaceSlot? {
        workspace.first { $0.id == selectedSlotID }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                toolbar
                mainArea
                statusBar
            }
        }
        .background(Color(red: 0.93, green: 0.95, blue: 0.96))
        .onDeleteCommand {
            handleDeleteCommand()
        }
        .onMoveCommand { direction in
            handleMoveCommand(direction)
        }
        .onAppear {
            loadCatalog()
            loadBoards()
            loadCustomPresets()
            loadBackups()
            loadWorkspace()
            refreshDevice()
            checkEndpoint()
            loadFirmware()
        }
        .sheet(isPresented: $showingDeviceImage) {
            deviceImagePreview
        }
        .sheet(isPresented: $showingPushProgress) {
            pushProgressSheet
        }
        .sheet(isPresented: $showingFirmwareSheet) {
            firmwareSheet
        }
    }

    var deviceImagePreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("VoiceLive Play")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Close") { showingDeviceImage = false }
                    .keyboardShortcut(.cancelAction)
            }
            if let image = NSImage(contentsOf: deviceIconURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 520, height: 360)
                    .background(Color.black.opacity(0.04))
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
            } else {
                Text("Device image not found.")
                    .foregroundColor(.secondary)
                    .frame(width: 520, height: 240)
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    var pushProgressSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(pushProgress.isActive ? "Pushing to VoiceLive Play" : "Push Complete")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                if !pushProgress.isActive {
                    Button("Close") {
                        showingPushProgress = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(pushProgress.completed) of \(pushProgress.total)")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if pushProgress.currentSlot > 0 {
                        Text("Slot \(pushProgress.currentSlot)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .cornerRadius(4)
                    }
                }
                ProgressView(value: pushProgress.fraction)
                    .progressViewStyle(.linear)
                Text(pushProgress.currentPreset.isEmpty ? "Preparing preset transfer..." : pushProgress.currentPreset)
                    .font(.system(size: 14, weight: .semibold))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(pushProgress.log.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
            }
            .frame(height: 160)
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 1))

            if pushProgress.isActive {
                Text("Keep the VoiceLive Play connected until this finishes.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .frame(width: 520)
        .interactiveDismissDisabled(pushProgress.isActive)
    }

    var firmwareSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("VoiceLive Play Firmware")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Close") { showingFirmwareSheet = false }
                    .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Catalog")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 78, alignment: .leading)
                    Text(firmwareUpdates.isEmpty ? "No local firmware catalog found" : "VoiceSupport local catalog")
                        .font(.system(size: 13, weight: .semibold))
                }
                HStack {
                    Text("Latest")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 78, alignment: .leading)
                    Text(firmwareUpdates.last?.version ?? "No firmware catalog found")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .padding(10)
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 1))

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(firmwareUpdates) { update in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(update.version)
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                                Text(update.localPath == nil ? "Not downloaded" : "Downloaded")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(update.localPath == nil ? .orange : .green)
                            }
                            if !update.pubDate.isEmpty {
                                Text(update.pubDate)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            ForEach(update.notes, id: \.self) { note in
                                Text("• \(note)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(9)
                        .background(Color.white)
                        .overlay(Rectangle().stroke(Color.black.opacity(0.18), lineWidth: 1))
                    }
                }
            }
            .frame(height: 300)

            HStack {
                Button("Check Firmware") {
                    loadFirmware()
                    checkEndpoint()
                    status = "Checked local firmware catalog."
                }
                Button("Fetch Latest") {
                    fetchLatestFirmware()
                }
                .disabled(firmwareUpdates.last?.localPath != nil || firmwareUpdates.last?.link.isEmpty != false)
                Spacer()
                Button("Show Folder") {
                    NSWorkspace.shared.open(firmwareFolderURL())
                }
                Button("Open VoiceSupport 2") {
                    openVoiceSupport()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Firmware flashing is handed to VoiceSupport 2 because it is the TC-Helicon updater path. This app can check and fetch firmware files, but it will not blindly flash firmware over MIDI.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 620)
        .onAppear {
            loadFirmware()
        }
    }

    var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                if let icon = NSImage(contentsOf: deviceIconURL) {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 84)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingDeviceImage = true
                        }
                } else {
                    Text("VL")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 84, height: 64)
                        .background(Color(red: 0.09, green: 0.47, blue: 0.79))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("VoiceLive Play")
                        .font(.system(size: 15, weight: .bold))
                    Text("Board: \(workspaceReport)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(device.connected ? (device.midiConfirmed ? Color.green : Color.orange) : Color.red)
                            .frame(width: 8, height: 8)
                        Text(device.connected ? device.detail : "Not connected")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        Button("Reconnect") { refreshDevice() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            .padding(14)

            Divider()

            boardsSection

            HStack(spacing: 8) {
                Text(backupsExpanded ? "▾" : "▸")
                    .foregroundColor(.secondary)
                Text("Backups")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button("Create Backup Now") { createBackupNow() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                backupsExpanded.toggle()
            }

            if backupsExpanded {
                if backups.isEmpty {
                    Text("No VoiceSupport backups found")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(backups) { backup in
                            BackupRow(backup: backup, selected: selectedBackupID == backup.id)
                                .onTapGesture {
                                    clearFocus()
                                    activeArea = .backups
                                    selectedCustomPresetID = nil
                                    applyBackup(backup)
                                }
                                .contextMenu {
                                    Button("Load Backup") {
                                        clearFocus()
                                        activeArea = .backups
                                        selectedCustomPresetID = nil
                                        applyBackup(backup)
                                    }
                                    Button("Delete Backup") {
                                        selectedBackupID = backup.id
                                        activeArea = .backups
                                        deleteBackup(backup)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }

            HStack(spacing: 8) {
                Text(cloudExpanded ? "▾" : "▸")
                    .foregroundColor(.secondary)
                Text("Cloud")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, cloudExpanded ? 0 : 8)
            .contentShape(Rectangle())
            .onTapGesture {
                cloudExpanded.toggle()
            }

            if cloudExpanded {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(catalog.packs) { pack in
                            PackBrowserRow(
                                pack: pack,
                                imageURL: packArtworkURL(pack),
                                selected: pack.id == selectedPackID
                            )
                            .onTapGesture {
                                clearFocus()
                                activeArea = .cloud
                                selectedPackID = pack.id
                                selectedBackupID = nil
                                selectedCustomPresetID = nil
                                selectedPreset = nil
                                selectedPresetSourceTitle = nil
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
                .frame(maxHeight: 260)
            }

            customPresetsSection
        }
        .frame(width: 330)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.86, green: 0.90, blue: 0.92))
    }

    var boardsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Boards")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button("Import") { importBoards() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Add Board") { addBoard() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if boards.isEmpty {
                Text("No saved boards yet")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(boards) { board in
                            if renamingBoardID == board.id {
                                TextField("Board name", text: $boardNameDraft)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .onSubmit {
                                        renameSelectedBoard()
                                    }
                            } else {
                                BoardRow(
                                    board: board,
                                    selected: selectedBoardID == board.id,
                                    loaded: loadedBoardID == board.id,
                                    dropTarget: dropTargetBoardID == board.id,
                                    loadAction: { loadBoard(board) }
                                )
                                    .onTapGesture {
                                        clearFocus()
                                        activeArea = .boards
                                        selectedBoardID = board.id
                                        boardNameDraft = board.title
                                    }
                                    .contextMenu {
                                        Button("Copy Board") {
                                            copiedBoard = board
                                            status = "Copied board: \(board.title)"
                                        }
                                        Button("Export Boards") {
                                            exportBoards()
                                        }
                                        Button("Paste Over Board") {
                                            selectedBoardID = board.id
                                            pasteCopiedBoard(over: board)
                                        }
                                        .disabled(copiedBoard == nil)
                                        Button("Clear Board") {
                                            selectedBoardID = board.id
                                            clearBoard(board)
                                        }
                                        Button("Rename") {
                                            selectedBoardID = board.id
                                            boardNameDraft = board.title
                                            renamingBoardID = board.id
                                        }
                                        Button("Remove") {
                                            selectedBoardID = board.id
                                            removeSelectedBoard()
                                        }
                                    }
                                    .onDrop(
                                        of: [UTType.text],
                                        isTargeted: Binding(
                                            get: { dropTargetBoardID == board.id },
                                            set: { isTargeted in
                                                dropTargetBoardID = isTargeted ? board.id : nil
                                            }
                                        )
                                    ) { providers in
                                        dropTargetBoardID = nil
                                        return dropPreset(providers, onto: board)
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            Divider()
        }
    }

    var customPresetsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Text("Presets")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button("Add Preset") { addCustomPreset() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if customPresets.isEmpty {
                Text("No custom presets yet")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(customPresets) { preset in
                        CustomPresetRow(
                            preset: preset,
                            detail: customPresetDetail(preset),
                            selected: selectedCustomPresetID == preset.id
                        )
                            .onTapGesture {
                                clearFocus()
                                selectCustomPreset(preset.id)
                            }
                            .contextMenu {
                                Button("Remove") {
                                    removeCustomPreset(preset)
                                }
                            }
                            .onDrag {
                                let payload = preset.payloadName ?? preset.title
                                return NSItemProvider(object: "\(preset.title)\t\(preset.source)\t\(payload)\tcustom:\(preset.id)" as NSString)
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
    }

    var toolbar: some View {
        HStack(spacing: 8) {
            Spacer()
            Button("Firmware") {
                loadFirmware()
                showingFirmwareSheet = true
            }
            Button("Push to Device") { pushCurrentBoardToDevice() }
                .disabled(!device.midiConfirmed || occupiedSlots == 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    var metrics: some View {
        HStack(spacing: 0) {
            metric("Device", device.connected ? "Connected" : "Missing")
            metric("Endpoint", endpointStatus)
            metric("Firmware", latestFirmware)
            metric("Workspace", workspaceReport)
        }
        .background(Color.white)
        .overlay(Rectangle().stroke(Color.gray.opacity(0.2)))
    }

    func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .overlay(Rectangle().stroke(Color.gray.opacity(0.12)))
    }

    var mainArea: some View {
        HStack(spacing: 1) {
            packPresetPane
                .frame(width: 430)
            workspacePane
        }
        .background(Color.gray.opacity(0.3))
    }

    var packPresetPane: some View {
        if selectedCustomPreset != nil && selectedPreset == nil {
            AnyView(customPresetPane.id(selectedCustomPresetID ?? ""))
        } else {
            AnyView(cloudPresetPane)
        }
    }

    var cloudPresetPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedPack.map { "Cloud - \($0.title)" } ?? "Cloud Presets")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }

            if let pack = selectedPack {
                HStack(alignment: .center, spacing: 10) {
                    PackThumbnail(imageURL: packArtworkURL(pack), fallback: pack.title)
                        .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(pack.presetCount) presets")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(pack.description ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                TextField("Search presets in \(pack.title)", text: $search)
                    .textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 132), spacing: 1),
                            GridItem(.flexible(minimum: 132), spacing: 1)
                        ],
                        spacing: 1
                    ) {
                        ForEach(filteredPresets, id: \.self) { preset in
                            PresetGridCell(name: preset, selected: selectedPreset == preset)
                                .onTapGesture {
                                    clearFocus()
                                    activeArea = .presets
                                    selectedCustomPresetID = nil
                                    selectedPreset = preset
                                    selectedPresetSourceTitle = pack.title
                                }
                                .onTapGesture(count: 2) {
                                    selectedCustomPresetID = nil
                                    selectedPreset = preset
                                    selectedPresetSourceTitle = pack.title
                                    placeSelectedPresetInSelectedSlot()
                            }
                            .onDrag {
                                NSItemProvider(object: "\(preset)\t\(pack.title)" as NSString)
                            }
                        }
                    }
                    .padding(1)
                }
                .background(Color.white)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.35)))
                if selectedPreset != nil {
                    HStack {
                        Spacer()
                        Button("Place selected preset") {
                            placeSelectedPresetInSelectedSlot()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.98, green: 0.99, blue: 1.0))
    }

    var customPresetPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Effect Builder")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }

            if let preset = selectedCustomPreset,
               let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Title")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 44, alignment: .leading)
                        TextField("Preset name", text: Binding(
                            get: { customPresets[index].title },
                            set: { value in
                                customPresets[index].title = value
                                customPresets[index].updatedAt = Self.nowStamp()
                                persistCustomPresets()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    if customPresets[index].source == "Template" {
                        HStack(spacing: 8) {
                            Text("Type")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Picker("", selection: Binding(
                                get: { customPresets[index].payloadName ?? "" },
                                set: { value in
                                    if let template = presetTemplates.first(where: { $0.sourcePreset == value }) {
                                        applyTemplate(template, toCustomPresetAt: index)
                                    }
                                }
                            )) {
                                ForEach(presetTemplates) { template in
                                    Text(template.title).tag(template.sourcePreset)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }
                }
                .padding(10)
                .background(Color.white)
                .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 1))

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(effectSections, id: \.self) { section in
                            let controls = effectControls.filter { $0.section == section }
                            EffectSectionView(
                                title: section,
                                controls: controls,
                                value: { control in
                                    effectValue(for: customPresets[index], control: control)
                                },
                                setValue: { control, value in
                                    updateEffectValue(forCustomPresetAt: index, control: control, value: value)
                                }
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            TextEditor(text: Binding(
                                get: { customPresets[index].notes },
                                set: { value in
                                    customPresets[index].notes = value
                                    customPresets[index].updatedAt = Self.nowStamp()
                                    persistCustomPresets()
                                }
                            ))
                            .font(.system(size: 12))
                            .frame(height: 70)
                            .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 1))
                        }
                    }
                }
                .background(Color.white)
                .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 1))

                HStack {
                    Button("Save") {
                        saveCustomPreset(at: index)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Place preset in selected slot") {
                        placePreset(
                            customPresets[index].title,
                            payloadName: customPresets[index].payloadName ?? customPresets[index].title,
                            source: customPresets[index].source,
                            intoSlot: selectedSlotID,
                            payloadMessages: customPresets[index].payloadMessages
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(customPresets[index].payloadMessages == nil && customPresets[index].payloadName == nil)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(red: 0.98, green: 0.99, blue: 1.0))
    }

    var workspacePane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(loadedBoard?.title ?? "Current Board")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\(workspaceReport) | local edits only")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Button("Save as Board") { saveWorkspaceAsBoard() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Reload") { reloadCurrentBoard() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Pull from Device") { pullFromDevice() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 82, maximum: 112), spacing: 1)],
                    spacing: 1
                ) {
                    ForEach(workspace) { slot in
                        WorkspaceCell(
                            slot: slot,
                            selected: selectedSlotID == slot.id,
                            dropTarget: dropTargetSlotID == slot.id
                        )
                        .onTapGesture {
                            clearFocus()
                            activeArea = .workspace
                            selectedSlotID = slot.id
                            selectedPreset = nil
                            selectedPresetSourceTitle = nil
                        }
                        .contextMenu {
                            Button("Copy") {
                                copySlot(slot.id)
                            }
                            Button("Paste") {
                                pasteSlot(slot.id)
                            }
                            .disabled(copiedSlot == nil)
                            Button("Edit Preset") {
                                editSlotAsPreset(slot.id)
                            }
                            .disabled(slot.name == "BLANK PRESET")
                            Button("Save as Preset") {
                                saveSlotAsPreset(slot.id, openBuilder: false)
                            }
                            .disabled(slot.name == "BLANK PRESET")
                            Button("Rename") {
                                renameSlot(slot.id)
                            }
                            .disabled(slot.name == "BLANK PRESET")
                            Button("Clear") {
                                clearSlot(slot.id)
                            }
                        }
                        .onDrop(
                            of: [UTType.text],
                            isTargeted: Binding(
                                get: { dropTargetSlotID == slot.id },
                                set: { isTargeted in
                                    dropTargetSlotID = isTargeted ? slot.id : nil
                                }
                            )
                        ) { providers in
                            dropTargetSlotID = nil
                            return dropPreset(providers, ontoSlot: slot.id)
                        }
                    }
                }
                .padding(1)
            }
            .background(Color.gray.opacity(0.25))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
            workspaceSlotDetail
        }
        .padding(14)
        .background(Color(red: 0.98, green: 0.99, blue: 1.0))
    }

    var workspaceSlotDetail: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(selectedSlot?.name ?? "No preset selected")
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Text("Slot \(selectedSlotID)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black)
                    .cornerRadius(4)
            }
            if !slotDetailText.isEmpty {
                Text(slotDetailText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.98, green: 0.99, blue: 1.0))
        .overlay(Rectangle().stroke(Color.black.opacity(0.65), lineWidth: 1))
    }

    var slotDetailText: String {
        guard let selectedSlot else {
            return "Choose a workspace slot to inspect it."
        }
        return presetDescription(for: selectedSlot.name)
    }

    func presetDescription(for name: String) -> String {
        guard name != "BLANK PRESET" else { return "" }
        return ""
    }

    func firstBlankSlotID(in slots: [WorkspaceSlot]) -> Int {
        slots.first(where: { $0.name == "BLANK PRESET" })?.id ?? 1
    }

    func clearFocus() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    func confirm(_ message: String, informativeText: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func handleDeleteCommand() {
        clearFocus()
        switch activeArea {
        case .boards:
            guard let board = selectedBoard else { return }
            if confirm("Delete \(board.title)?", informativeText: "This removes the board from the local board list.") {
                removeSelectedBoard()
            }
        case .workspace:
            guard let slot = selectedSlot else { return }
            if confirm("Clear slot \(slot.id)?", informativeText: "This clears \(slot.name) from the current board/workspace.") {
                clearSlot(slot.id)
            }
        case .backups:
            guard let backup = selectedBackup else { return }
            deleteBackup(backup)
        default:
            break
        }
    }

    func handleMoveCommand(_ direction: MoveCommandDirection) {
        clearFocus()
        switch activeArea {
        case .boards:
            moveBoardSelection(direction)
        case .backups:
            moveBackupSelection(direction)
        case .cloud:
            movePackSelection(direction)
        case .presets:
            movePresetSelection(direction)
        case .workspace:
            moveWorkspaceSelection(direction)
        }
    }

    func moveIndex(current: Int, count: Int, direction: MoveCommandDirection, columns: Int = 1) -> Int {
        guard count > 0 else { return current }
        let delta: Int
        switch direction {
        case .up:
            delta = -columns
        case .down:
            delta = columns
        case .left:
            delta = -1
        case .right:
            delta = 1
        @unknown default:
            delta = 0
        }
        return min(max(current + delta, 0), count - 1)
    }

    func moveBoardSelection(_ direction: MoveCommandDirection) {
        guard !boards.isEmpty else { return }
        let current = boards.firstIndex(where: { $0.id == selectedBoardID }) ?? 0
        let next = moveIndex(current: current, count: boards.count, direction: direction)
        selectedBoardID = boards[next].id
        boardNameDraft = boards[next].title
    }

    func moveBackupSelection(_ direction: MoveCommandDirection) {
        guard !backups.isEmpty else { return }
        let current = backups.firstIndex(where: { $0.id == selectedBackupID }) ?? 0
        let next = moveIndex(current: current, count: backups.count, direction: direction)
        applyBackup(backups[next])
        activeArea = .backups
    }

    func movePackSelection(_ direction: MoveCommandDirection) {
        guard !catalog.packs.isEmpty else { return }
        let current = catalog.packs.firstIndex(where: { $0.id == selectedPackID }) ?? 0
        let next = moveIndex(current: current, count: catalog.packs.count, direction: direction)
        selectedPackID = catalog.packs[next].id
        selectedPreset = nil
        selectedPresetSourceTitle = nil
    }

    func movePresetSelection(_ direction: MoveCommandDirection) {
        if selectedCustomPresetID != nil {
            guard !customPresets.isEmpty else { return }
            let current = customPresets.firstIndex(where: { $0.id == selectedCustomPresetID }) ?? 0
            let next = moveIndex(current: current, count: customPresets.count, direction: direction)
            selectedCustomPresetID = customPresets[next].id
            selectedPreset = nil
            selectedPresetSourceTitle = nil
            activeArea = .presets
            return
        }
        let presets = filteredPresets
        guard !presets.isEmpty else { return }
        let current = presets.firstIndex(where: { $0 == selectedPreset }) ?? 0
        let next = moveIndex(current: current, count: presets.count, direction: direction, columns: 2)
        selectedPreset = presets[next]
        selectedPresetSourceTitle = selectedPack?.title
    }

    func moveWorkspaceSelection(_ direction: MoveCommandDirection) {
        let current = max(0, selectedSlotID - 1)
        let next = moveIndex(current: current, count: workspace.count, direction: direction, columns: 8)
        selectedSlotID = next + 1
        selectedPreset = nil
        selectedPresetSourceTitle = nil
    }

    var statusBar: some View {
        Text(status)
            .font(.system(size: 12))
            .foregroundColor(Color(red: 0.19, green: 0.33, blue: 0.42))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(red: 0.85, green: 0.89, blue: 0.92))
    }

    func loadCatalog() {
        let path = root.appendingPathComponent("data/voiceSupportCatalog.json")
        do {
            let data = try Data(contentsOf: path)
            catalog = try JSONDecoder().decode(Catalog.self, from: data)
            selectedPackID = catalog.packs.first?.id
            status = "Loaded \(catalog.packs.count) local preset packs."
        } catch {
            status = "Failed to load catalog: \(error.localizedDescription)"
        }
    }

    func loadBackups() {
        let manifest = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/TC-Helicon/VoiceSupport 2/VoiceLive Play/data/VoiceLive Play_backup.xml")
        guard let text = try? String(contentsOf: manifest, encoding: .utf8) else {
            backups = []
            loadAppBackups()
            return
        }
        let archivePaths = Self.values(in: text, tag: "archive")
        backups = archivePaths.compactMap { xmlPath in
            guard let archiveText = try? String(contentsOfFile: xmlPath, encoding: .utf8) else { return nil }
            let title = Self.firstValue(in: archiveText, tag: "title") ?? URL(fileURLWithPath: xmlPath).deletingPathExtension().lastPathComponent
            let dataPath = Self.firstValue(in: archiveText, tag: "linkData")
                ?? URL(fileURLWithPath: xmlPath).deletingPathExtension().appendingPathExtension("tch").path
            let names = Self.extractPresetNames(from: dataPath)
            return BackupArchive(title: title, xmlPath: xmlPath, dataPath: dataPath, presetNames: names, slots: nil)
        }
        loadAppBackups()
    }

    func boardsPath() -> URL {
        root.appendingPathComponent("boards.json")
    }

    func customPresetsPath() -> URL {
        root.appendingPathComponent("custom-presets.json")
    }

    func appBackupsPath() -> URL {
        root.appendingPathComponent("app-backups.json")
    }

    func loadCustomPresets() {
        let path = customPresetsPath()
        guard let data = try? Data(contentsOf: path),
              let saved = try? JSONDecoder().decode([CustomPreset].self, from: data) else {
            customPresets = []
            return
        }
        customPresets = saved
    }

    func persistCustomPresets() {
        do {
            let data = try JSONEncoder().encode(customPresets)
            try data.write(to: customPresetsPath())
        } catch {
            status = "Preset save failed: \(error.localizedDescription)"
        }
    }

    func loadAppBackups() {
        let path = appBackupsPath()
        guard let data = try? Data(contentsOf: path),
              let saved = try? JSONDecoder().decode([AppBackupArchive].self, from: data) else {
            return
        }
        let appBackups = saved.map { backup in
            BackupArchive(
                title: backup.title,
                xmlPath: "app-backup:\(backup.id)",
                dataPath: "",
                presetNames: backup.slots.filter { $0.name != "BLANK PRESET" }.map { $0.name },
                slots: backup.slots
            )
        }
        backups.insert(contentsOf: appBackups, at: 0)
    }

    func persistAppBackup(_ backup: AppBackupArchive) {
        let path = appBackupsPath()
        var saved: [AppBackupArchive] = []
        if let data = try? Data(contentsOf: path),
           let decoded = try? JSONDecoder().decode([AppBackupArchive].self, from: data) {
            saved = decoded
        }
        saved.insert(backup, at: 0)
        do {
            let data = try JSONEncoder().encode(saved)
            try data.write(to: path)
        } catch {
            status = "Backup save failed: \(error.localizedDescription)"
        }
    }

    func deleteBackup(_ backup: BackupArchive) {
        let isWorkbenchBackup = backup.xmlPath.hasPrefix("app-backup:")
        let informative = isWorkbenchBackup
            ? "This deletes the backup from the Workbench backup list."
            : "This removes the backup from the VoiceSupport backup list and moves its local backup files to Trash."
        guard confirm("Delete \(backup.title)?", informativeText: informative) else {
            status = "Backup delete cancelled."
            return
        }

        if isWorkbenchBackup {
            deletePersistedAppBackup(backup)
        } else {
            deleteVoiceSupportBackup(backup)
        }

        backups.removeAll { $0.id == backup.id }
        if selectedBackupID == backup.id {
            selectedBackupID = backups.first?.id
        }
        status = "Deleted backup: \(backup.title)"
    }

    func deletePersistedAppBackup(_ backup: BackupArchive) {
        let id = backup.xmlPath.replacingOccurrences(of: "app-backup:", with: "")
        let path = appBackupsPath()
        guard let data = try? Data(contentsOf: path),
              var saved = try? JSONDecoder().decode([AppBackupArchive].self, from: data) else {
            return
        }
        saved.removeAll { $0.id == id }
        do {
            let data = try JSONEncoder().encode(saved)
            try data.write(to: path)
        } catch {
            status = "Backup delete failed: \(error.localizedDescription)"
        }
    }

    func deleteVoiceSupportBackup(_ backup: BackupArchive) {
        let manifest = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/TC-Helicon/VoiceSupport 2/VoiceLive Play/data/VoiceLive Play_backup.xml")

        if var text = try? String(contentsOf: manifest, encoding: .utf8) {
            let exactLine = "      <archive>\(backup.xmlPath)</archive>\n"
            if text.contains(exactLine) {
                text = text.replacingOccurrences(of: exactLine, with: "")
            } else {
                text = text.replacingOccurrences(of: "<archive>\(backup.xmlPath)</archive>", with: "")
            }
            try? text.write(to: manifest, atomically: true, encoding: .utf8)
        }

        trashFileIfPresent(backup.xmlPath)
        trashFileIfPresent(backup.dataPath)
    }

    func trashFileIfPresent(_ path: String) {
        guard !path.isEmpty,
              FileManager.default.fileExists(atPath: path) else {
            return
        }
        let url = URL(fileURLWithPath: path)
        var trashedURL: NSURL?
        try? FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
    }

    func loadBoards() {
        let path = boardsPath()
        guard let data = try? Data(contentsOf: path),
              let saved = try? JSONDecoder().decode([BoardArchive].self, from: data) else {
        boards = []
        boardNameDraft = ""
        loadedBoardID = nil
        loadedBoardBaseline = nil
        return
        }
        boards = saved
        selectedBoardID = boards.first?.id
        loadedBoardID = nil
        loadedBoardBaseline = nil
        boardNameDraft = boards.first?.title ?? ""
        renamingBoardID = nil
    }

    func persistBoards() {
        do {
            let data = try JSONEncoder().encode(boards)
            try data.write(to: boardsPath())
        } catch {
            status = "Board save failed: \(error.localizedDescription)"
        }
    }

    func addBoard() {
        createBoardFromWorkspace(renameImmediately: false)
    }

    func selectCustomPreset(_ id: String) {
        activeArea = .presets
        selectedCustomPresetID = id
        selectedPreset = nil
        selectedPresetSourceTitle = nil
        status = customPresets.first(where: { $0.id == id }).map { "Selected preset: \($0.title)" } ?? status
    }

    func addCustomPreset() {
        let fallbackTemplate = presetTemplates.first
        let fallbackSource = fallbackTemplate.flatMap { sourceTitle(forPreset: $0.sourcePreset) } ?? "Cloud"
        let fallbackPayload = fallbackTemplate?.sourcePreset
        let messages = fallbackPayload.flatMap { resolvePayloadMessages(source: fallbackSource, payloadName: $0) }
        let preset = CustomPreset(
            id: UUID().uuidString,
            title: "New Preset",
            payloadName: fallbackPayload,
            source: "Template",
            notes: fallbackTemplate?.subtitle ?? "",
            payloadMessages: messages,
            updatedAt: Self.nowStamp()
        )
        customPresets.insert(preset, at: 0)
        selectCustomPreset(preset.id)
        persistCustomPresets()
        status = "Added new clean preset. Choose a type and edit the effects."
    }

    func customPresetDetail(_ preset: CustomPreset) -> String {
        if preset.source == "Template",
           let payloadName = preset.payloadName,
           let template = presetTemplates.first(where: { $0.sourcePreset == payloadName }) {
            return template.title
        }
        if preset.source == "Template" {
            return "Custom template"
        }
        return "Saved from board"
    }

    func sourceTitle(forPreset presetName: String) -> String? {
        catalog.packs.first { pack in
            pack.presetNames.contains { $0.caseInsensitiveCompare(presetName) == .orderedSame }
        }?.title
    }

    func applyTemplate(_ template: PresetTemplate, toCustomPresetAt index: Int) {
        let source = sourceTitle(forPreset: template.sourcePreset) ?? selectedPack?.title ?? "Cloud"
        guard let messages = resolvePayloadMessages(source: source, payloadName: template.sourcePreset) else {
            status = "Could not load \(template.title). Try selecting a cloud pack first."
            return
        }

        customPresets[index].payloadName = template.sourcePreset
        customPresets[index].source = source
        customPresets[index].payloadMessages = messages
        customPresets[index].notes = template.subtitle
        if customPresets[index].title == "New Preset" || customPresets[index].title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            customPresets[index].title = template.title
        }
        customPresets[index].updatedAt = Self.nowStamp()
        persistCustomPresets()
        status = "Started \(customPresets[index].title) from \(template.title)."
    }

    func saveCustomPreset(at index: Int) {
        guard customPresets.indices.contains(index) else { return }
        let cleaned = customPresets[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            status = "Preset name cannot be empty."
            return
        }
        customPresets[index].title = cleaned
        customPresets[index].updatedAt = Self.nowStamp()
        persistCustomPresets()
        status = "Saved preset: \(cleaned)"
    }

    func editSlotAsPreset(_ slotID: Int) {
        saveSlotAsPreset(slotID, openBuilder: true)
    }

    func saveSlotAsPreset(_ slotID: Int, openBuilder: Bool) {
        guard workspace.indices.contains(slotID - 1) else {
            status = "Slot \(slotID) is not available."
            return
        }
        let slot = workspace[slotID - 1]
        guard slot.name != "BLANK PRESET" else {
            status = "Blank slots cannot be saved as presets."
            return
        }

        let messages = slot.payloadMessages ?? resolvePayloadMessages(source: slot.source, payloadName: slot.payloadName ?? slot.name)
        let preset = CustomPreset(
            id: UUID().uuidString,
            title: slot.name,
            payloadName: slot.payloadName ?? slot.name,
            source: slot.source,
            notes: "Saved from board slot \(slotID)",
            payloadMessages: messages,
            updatedAt: Self.nowStamp()
        )
        customPresets.insert(preset, at: 0)
        persistCustomPresets()

        if openBuilder {
            selectCustomPreset(preset.id)
            status = "Editing preset from slot \(slotID): \(slot.name)"
        } else {
            activeArea = .workspace
            status = "Saved slot \(slotID) as preset: \(slot.name)"
        }
    }

    func attachStartingSound(toCustomPresetAt index: Int) {
        let source: String
        let payloadName: String

        if let slot = selectedSlot, slot.name != "BLANK PRESET" {
            source = slot.source
            payloadName = slot.payloadName ?? slot.name
        } else if let selectedPreset {
            source = selectedPresetSourceTitle ?? selectedPack?.title ?? "Cloud"
            payloadName = selectedPreset
        } else {
            status = "Select a board slot or cloud preset first."
            return
        }

        guard let messages = resolvePayloadMessages(source: source, payloadName: payloadName) else {
            status = "Could not load the starting sound for \(payloadName)."
            return
        }

        customPresets[index].payloadName = payloadName
        customPresets[index].source = source
        customPresets[index].payloadMessages = messages
        customPresets[index].updatedAt = Self.nowStamp()
        persistCustomPresets()
        status = "Loaded starting sound: \(payloadName)"
    }

    func effectValue(for preset: CustomPreset, control: EffectControl) -> Int {
        guard let messages = preset.payloadMessages,
              messages.indices.contains(control.packetIndex) else {
            return 0
        }
        return Self.effectByteValue(in: messages[control.packetIndex], offset: control.byteOffset)
    }

    func updateEffectValue(forCustomPresetAt index: Int, control: EffectControl, value: Int) {
        guard customPresets.indices.contains(index) else { return }
        if customPresets[index].payloadMessages == nil {
            if let template = presetTemplates.first {
                applyTemplate(template, toCustomPresetAt: index)
            } else {
                attachStartingSound(toCustomPresetAt: index)
            }
        }
        guard var messages = customPresets[index].payloadMessages,
              messages.indices.contains(control.packetIndex) else {
            status = "Choose a sound type before editing this preset."
            return
        }

        messages[control.packetIndex] = Self.settingEffectByte(
            in: messages[control.packetIndex],
            offset: control.byteOffset,
            value: value
        )
        customPresets[index].payloadMessages = messages
        customPresets[index].updatedAt = Self.nowStamp()
        persistCustomPresets()
    }

    static func effectByteValue(in message: Data, offset: Int) -> Int {
        let index = 8 + offset
        guard message.indices.contains(index) else { return 0 }
        return Int(message[index] & 0x7F)
    }

    static func settingEffectByte(in message: Data, offset: Int, value: Int) -> Data {
        var bytes = [UInt8](message)
        let index = 8 + offset
        guard bytes.indices.contains(index) else { return message }
        bytes[index] = UInt8(max(0, min(127, value)))
        if bytes.count > 109 {
            let checksumRange = 7..<108
            let checksum = checksumRange.reduce(0) { partial, i in
                partial + Int(bytes[i])
            } & 0x7F
            bytes[108] = UInt8(checksum)
        }
        return Data(bytes)
    }

    func removeCustomPreset(_ preset: CustomPreset) {
        customPresets.removeAll { $0.id == preset.id }
        if selectedCustomPresetID == preset.id {
            selectedCustomPresetID = customPresets.first?.id
        }
        persistCustomPresets()
        status = "Removed custom preset: \(preset.title)"
    }

    func createBackupNow() {
        let backup = AppBackupArchive(
            id: UUID().uuidString,
            title: "Workbench Backup - \(Self.nowStamp())",
            slots: workspace,
            report: workspaceReport,
            updatedAt: Self.nowStamp()
        )
        persistAppBackup(backup)
        let display = BackupArchive(
            title: backup.title,
            xmlPath: "app-backup:\(backup.id)",
            dataPath: "",
            presetNames: backup.slots.filter { $0.name != "BLANK PRESET" }.map { $0.name },
            slots: backup.slots
        )
        backups.insert(display, at: 0)
        status = "Created backup: \(backup.title). Current board was not changed."
    }

    func saveWorkspaceAsBoard() {
        createBoardFromWorkspace(renameImmediately: true)
    }

    func createBoardFromWorkspace(renameImmediately: Bool) {
        let report = "\(occupiedSlots)/500"
        let board = BoardArchive(
            id: UUID().uuidString,
            title: "Board \(boards.count + 1)",
            slots: workspace,
            report: report,
            updatedAt: Self.nowStamp()
        )
        boards.insert(board, at: 0)
        selectedBoardID = board.id
        loadedBoardID = board.id
        loadedBoardBaseline = board
        boardNameDraft = board.title
        renamingBoardID = renameImmediately ? board.id : nil
        selectedBackupID = nil
        workspaceSource = board.title
        workspaceReport = report
        selectedSlotID = firstBlankSlotID(in: workspace)
        activeArea = .workspace
        persistBoards()
        status = renameImmediately
            ? "Saved current workspace as a new board. Enter a board name."
            : "Added board: \(board.title). Changes will save to this board while it is selected."
    }

    func loadSelectedBoard() {
        guard let board = selectedBoard else {
            status = "Select a board first."
            return
        }
        loadBoard(board)
    }

    func loadBoard(_ board: BoardArchive) {
        workspace = board.slots
        workspaceSource = board.title
        workspaceReport = board.report
        selectedSlotID = firstBlankSlotID(in: workspace)
        selectedBackupID = nil
        selectedBoardID = board.id
        loadedBoardID = board.id
        loadedBoardBaseline = board
        boardNameDraft = board.title
        renamingBoardID = nil
        status = "Loaded board: \(board.title)"
    }

    func reloadCurrentBoard() {
        guard let savedBoard = loadedBoardBaseline else {
            resetWorkspace()
            return
        }
        workspace = savedBoard.slots
        workspaceSource = savedBoard.title
        workspaceReport = savedBoard.report
        selectedSlotID = firstBlankSlotID(in: workspace)
        selectedBoardID = savedBoard.id
        loadedBoardID = savedBoard.id
        boardNameDraft = savedBoard.title
        status = "Reloaded board: \(savedBoard.title)"
    }

    func pullFromDevice() {
        guard let path = latestDeviceSyncPath() else {
            status = "No VoiceSupport device sync cache found. Open VoiceSupport and sync the device once, then pull again."
            return
        }
        let names = Self.extractPresetNames(from: path)
        guard !names.isEmpty else {
            status = "Device sync cache did not contain readable presets."
            return
        }

        workspace = (1...500).map { id in
            let name = id <= names.count ? names[id - 1] : "BLANK PRESET"
            return WorkspaceSlot(
                id: id,
                name: name,
                payloadName: name == "BLANK PRESET" ? nil : name,
                source: "Device",
                dirty: false
            )
        }
        devicePullDataPath = path
        workspaceSource = "Device"
        workspaceReport = "\(names.count)/500"
        selectedSlotID = firstBlankSlotID(in: workspace)
        selectedBoardID = nil
        loadedBoardID = nil
        loadedBoardBaseline = nil
        selectedBackupID = nil
        status = "Pulled \(names.count) presets from the connected device view."
    }

    func latestDeviceSyncPath() -> String? {
        let dataRoot = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/TC-Helicon/VoiceSupport 2/VoiceLive Play/data")
        guard let enumerator = FileManager.default.enumerator(
            at: dataRoot,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var candidates: [(url: URL, modified: Date)] = []
        for case let url as URL in enumerator {
            guard ["sync.tch", "working.tch"].contains(url.lastPathComponent) else { continue }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            candidates.append((url, values?.contentModificationDate ?? .distantPast))
        }

        return candidates.sorted { $0.modified > $1.modified }.first?.url.path
    }

    func renameSelectedBoard() {
        guard let id = selectedBoardID,
              let index = boards.firstIndex(where: { $0.id == id }) else {
            status = "Select a board to rename."
            return
        }
        let cleaned = boardNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            status = "Board name cannot be empty."
            return
        }
        boards[index].title = cleaned
        boards[index].updatedAt = Self.nowStamp()
        if loadedBoardID == id {
            workspaceSource = cleaned
            loadedBoardBaseline = boards[index]
        }
        renamingBoardID = nil
        persistBoards()
        status = "Renamed board: \(cleaned)"
    }

    func removeSelectedBoard() {
        guard let id = selectedBoardID,
              let index = boards.firstIndex(where: { $0.id == id }) else {
            status = "Select a board to remove."
            return
        }
        let removed = boards.remove(at: index)
        if loadedBoardID == removed.id {
            loadedBoardID = nil
            loadedBoardBaseline = nil
        }
        selectedBoardID = boards.first?.id
        boardNameDraft = boards.first?.title ?? ""
        renamingBoardID = nil
        persistBoards()
        status = "Removed board: \(removed.title)"
    }

    func clearBoard(_ board: BoardArchive) {
        guard let index = boards.firstIndex(where: { $0.id == board.id }) else {
            status = "Board not found."
            return
        }
        let blank = Self.blankWorkspace(source: board.title)
        boards[index].slots = blank
        boards[index].report = "0/500"
        boards[index].updatedAt = Self.nowStamp()
        if loadedBoardID == board.id {
            workspace = blank
            workspaceSource = board.title
            workspaceReport = "0/500"
            selectedSlotID = firstBlankSlotID(in: workspace)
            loadedBoardBaseline = boards[index]
        }
        persistBoards()
        status = "Cleared board: \(board.title)"
    }

    func pasteCopiedBoard(over board: BoardArchive) {
        guard let copiedBoard,
              let index = boards.firstIndex(where: { $0.id == board.id }) else {
            status = "Copy a board first."
            return
        }
        let pastedSlots = copiedBoard.slots.map {
            WorkspaceSlot(id: $0.id, name: $0.name, payloadName: $0.payloadName, source: copiedBoard.title, dirty: true, payloadMessages: $0.payloadMessages)
        }
        let report = "\(pastedSlots.filter { $0.name != "BLANK PRESET" }.count)/500"
        boards[index].slots = pastedSlots
        boards[index].report = report
        boards[index].updatedAt = Self.nowStamp()
        if loadedBoardID == board.id {
            workspace = pastedSlots
            workspaceSource = board.title
            workspaceReport = report
            selectedSlotID = firstBlankSlotID(in: workspace)
            loadedBoardBaseline = boards[index]
        }
        persistBoards()
        status = "Pasted \(copiedBoard.title) over \(board.title)."
    }

    func dropPreset(_ providers: [NSItemProvider], onto board: BoardArchive) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? String else { return }
            let parts = text.components(separatedBy: "\t")
            let presetName = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sourceTitle = parts.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Cloud"
            let payloadName = parts.dropFirst(2).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? presetName
            let customID = parts.dropFirst(3).first?.replacingOccurrences(of: "custom:", with: "")
            guard !presetName.isEmpty else { return }

            DispatchQueue.main.async {
                let messages = customID.flatMap { id in customPresets.first { $0.id == id }?.payloadMessages }
                addPreset(presetName, payloadName: payloadName, source: sourceTitle, toNextBlankSlotIn: board, payloadMessages: messages)
            }
        }
        return true
    }

    func dropPreset(_ providers: [NSItemProvider], ontoSlot slotID: Int) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? String else { return }
            let parts = text.components(separatedBy: "\t")
            let presetName = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sourceTitle = parts.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Cloud"
            let payloadName = parts.dropFirst(2).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? presetName
            let customID = parts.dropFirst(3).first?.replacingOccurrences(of: "custom:", with: "")
            guard !presetName.isEmpty else { return }

            DispatchQueue.main.async {
                let messages = customID.flatMap { id in customPresets.first { $0.id == id }?.payloadMessages }
                placePreset(presetName, payloadName: payloadName, source: sourceTitle, intoSlot: slotID, payloadMessages: messages)
            }
        }
        return true
    }

    func addPreset(_ presetName: String, payloadName: String, source: String, toNextBlankSlotIn board: BoardArchive, payloadMessages: [Data]? = nil) {
        guard let index = boards.firstIndex(where: { $0.id == board.id }) else {
            status = "Board not found."
            return
        }
        guard let slotIndex = boards[index].slots.firstIndex(where: { $0.name == "BLANK PRESET" }) else {
            status = "\(boards[index].title) has no blank slots."
            return
        }

        let slotID = boards[index].slots[slotIndex].id
        boards[index].slots[slotIndex] = WorkspaceSlot(
            id: slotID,
            name: presetName,
            payloadName: payloadName,
            source: source,
            dirty: true,
            payloadMessages: payloadMessages
        )
        boards[index].report = "\(boards[index].slots.filter { $0.name != "BLANK PRESET" }.count)/500"
        boards[index].updatedAt = Self.nowStamp()
        selectedBoardID = boards[index].id
        boardNameDraft = boards[index].title

        if loadedBoardID == boards[index].id {
            workspace = boards[index].slots
            workspaceSource = boards[index].title
            workspaceReport = boards[index].report
            selectedSlotID = firstBlankSlotID(in: workspace)
            loadedBoardBaseline = boards[index]
            activeArea = .workspace
        }

        persistBoards()
        status = "Added \(presetName) to \(boards[index].title) slot \(slotID)."
    }

    func syncLoadedBoardFromWorkspace() {
        guard let id = loadedBoardID,
              let index = boards.firstIndex(where: { $0.id == id }) else {
            return
        }
        boards[index].slots = workspace
        boards[index].report = workspaceReport
        boards[index].updatedAt = Self.nowStamp()
        persistBoards()
    }

    func blankSlot(id: Int, source: String) -> WorkspaceSlot {
        WorkspaceSlot(id: id, name: "BLANK PRESET", source: source, dirty: false)
    }

    static func blankWorkspace(source: String) -> [WorkspaceSlot] {
        (1...500).map { id in
            WorkspaceSlot(id: id, name: "BLANK PRESET", source: source, dirty: false)
        }
    }

    func copySlot(_ id: Int) {
        guard let slot = workspace.first(where: { $0.id == id }) else {
            status = "Slot \(id) not found."
            return
        }
        selectedSlotID = id
        copiedSlot = slot
        status = "Copied slot \(id): \(slot.name)"
    }

    func pasteSlot(_ id: Int) {
        guard let copiedSlot else {
            status = "Copy a slot first."
            return
        }
        selectedSlotID = id
        workspace[id - 1] = WorkspaceSlot(
            id: id,
            name: copiedSlot.name,
            payloadName: copiedSlot.payloadName,
            source: copiedSlot.source,
            dirty: true,
            payloadMessages: copiedSlot.payloadMessages
        )
        workspaceReport = "\(occupiedSlots)/500"
        if let board = loadedBoard {
            workspaceSource = board.title
        } else {
            workspaceSource = "Local edited draft"
        }
        status = "Pasted \(copiedSlot.name) into slot \(id)."
    }

    func renameSlot(_ id: Int) {
        guard workspace.indices.contains(id - 1) else {
            status = "Slot \(id) is not available."
            return
        }
        let slot = workspace[id - 1]
        guard slot.name != "BLANK PRESET" else {
            status = "Blank slots cannot be renamed."
            return
        }

        let alert = NSAlert()
        alert.messageText = "Rename slot \(id)"
        alert.informativeText = "This changes the board label only. The original preset configuration stays attached for device push."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = slot.name
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else {
            status = "Rename cancelled."
            return
        }

        let cleaned = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            status = "Slot name cannot be blank."
            return
        }

        selectedSlotID = id
        workspace[id - 1].name = cleaned
        workspace[id - 1].dirty = true
        if let board = loadedBoard {
            workspaceSource = board.title
            syncLoadedBoardFromWorkspace()
        } else {
            workspaceSource = "Local edited draft"
        }
        status = "Renamed slot \(id) to \(cleaned)."
    }

    func clearSlot(_ id: Int) {
        selectedSlotID = id
        let source = loadedBoard?.title ?? workspaceSource
        workspace[id - 1] = blankSlot(id: id, source: source)
        workspaceReport = "\(occupiedSlots)/500"
        if let board = loadedBoard {
            workspaceSource = board.title
        } else {
            workspaceSource = "Local edited draft"
        }
        status = "Cleared slot \(id)."
    }

    func applyBackup(_ backup: BackupArchive) {
        selectedBackupID = backup.id
        selectedBoardID = nil
        loadedBoardID = nil
        loadedBoardBaseline = nil
        boardNameDraft = ""
        renamingBoardID = nil
        selectedPreset = nil
        selectedPresetSourceTitle = nil
        if let slots = backup.slots {
            workspace = slots
            workspaceReport = "\(slots.filter { $0.name != "BLANK PRESET" }.count)/500"
        } else {
            let names = backup.presetNames
            workspace = (1...500).map { id in
                let name = id <= names.count ? names[id - 1] : "BLANK PRESET"
                return WorkspaceSlot(id: id, name: name, payloadName: name == "BLANK PRESET" ? nil : name, source: backup.title, dirty: false)
            }
            workspaceReport = "\(names.count)/500"
        }
        selectedSlotID = firstBlankSlotID(in: workspace)
        activeArea = .workspace
        workspaceSource = backup.title
        status = "Loaded backup: \(backup.title)"
    }

    func packArtworkURL(_ pack: PresetPack) -> URL? {
        if let embedded = embeddedArtworkURL(for: pack) {
            return embedded
        }
        guard let linkImage = pack.linkImage, !linkImage.hasPrefix("*") else {
            return nil
        }
        if let xmlFile = pack.xmlFile {
            let url = URL(fileURLWithPath: xmlFile)
                .deletingLastPathComponent()
                .appendingPathComponent(linkImage)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        let fallback = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/TC-Helicon/VoiceSupport 2/VoiceLive Play/packs")
            .appendingPathComponent(linkImage)
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    static func firstValue(in xml: String, tag: String) -> String? {
        values(in: xml, tag: tag).first
    }

    static func values(in xml: String, tag: String) -> [String] {
        var values: [String] = []
        let open = "<\(tag)>"
        let close = "</\(tag)>"
        var remainder = xml[...]
        while let start = remainder.range(of: open),
              let end = remainder[start.upperBound...].range(of: close) {
            values.append(String(remainder[start.upperBound..<end.lowerBound]))
            remainder = remainder[end.upperBound...]
        }
        return values
    }

    static func extractPresetNames(from path: String) -> [String] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return [] }
        var names: [String] = []
        var buffer: [UInt8] = []

        func flush() {
            guard buffer.count >= 3 else {
                buffer.removeAll()
                return
            }
            let raw = String(decoding: buffer, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeAll()
            let cleaned = raw
                .filter { $0.isASCII }
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count >= 3,
                  cleaned.count <= 24,
                  cleaned.rangeOfCharacter(from: CharacterSet.letters) != nil,
                  !cleaned.localizedCaseInsensitiveContains("VoiceLive"),
                  !cleaned.localizedCaseInsensitiveContains("TC-Helicon"),
                  !cleaned.contains(".") || cleaned.contains(" ") else {
                return
            }
            names.append(cleaned)
        }

        for byte in data {
            if byte >= 32 && byte <= 126 {
                buffer.append(byte)
            } else {
                flush()
            }
        }
        flush()
        return Array(names.prefix(500))
    }

    static func nowStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy HH:mm"
        return formatter.string(from: Date())
    }

    func embeddedArtworkURL(for pack: PresetPack) -> URL? {
        let map: [String: String] = [
            "Serj T": "embedded-002.png",
            "Yuna": "embedded-001.png",
            "HardTune": "embedded-038.png",
            "Dan B": "embedded-003.png",
            "Worship Pack": "embedded-078.png",
            "Kimbra": "embedded-006.png",
            "Hannah's Pack": "embedded-004.png",
            "Clara": "embedded-005.png",
            "Pop": "embedded-060.png",
            "Reverb": "embedded-045.png",
            "Emma H": "embedded-009.png",
            "Echo": "embedded-039.png",
            "Rock": "embedded-028.png",
            "J-Pop": "embedded-013.png",
            "Mastodon": "embedded-007.png",
            "Showcase": "embedded-029.png",
            "Extreme": "embedded-044.png",
            "Megaphone": "embedded-025.png",
            "Hip Hop / Rap": "embedded-035.png",
            "Alternative": "embedded-014.png",
            "Summer Hits 2013": "embedded-065.png",
            "Harmony": "embedded-041.png",
            "70's Pack": "embedded-032.png",
            "Dance": "embedded-017.png",
            "Character": "embedded-050.png",
            "60's Hits": "embedded-031.png",
            "80's": "embedded-033.png",
            "500 Mega Pack": "embedded-034.png"
        ]
        if pack.title == "Modern Rock Pack" {
            return URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support/TC-Helicon/VoiceSupport 2/VoiceLive Play/packs/ModernRockPack.png")
        }
        guard let filename = map[pack.title] else { return nil }
        let url = root.appendingPathComponent("NativeApp/Assets/VoiceSupportEmbedded").appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func loadWorkspace() {
        let path = root.appendingPathComponent("workspace-state.json")
        if let data = try? Data(contentsOf: path),
           let saved = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data),
           saved.slots.count == 500 {
            workspace = saved.slots
            workspaceSource = saved.source
            workspaceReport = saved.report
            selectedSlotID = firstBlankSlotID(in: workspace)
            loadedBoardID = nil
            loadedBoardBaseline = nil
            status = "Loaded saved workspace snapshot."
            return
        }
        if let data = try? Data(contentsOf: path),
           let legacy = try? JSONDecoder().decode([WorkspaceSlot].self, from: data),
           legacy.count == 500 {
            let legacyNamed = legacy.filter { $0.name != "BLANK PRESET" }.count
            if legacyNamed > 12 {
                workspace = legacy
                workspaceSource = "Imported legacy workspace"
                workspaceReport = "\(legacyNamed)/500"
                selectedSlotID = firstBlankSlotID(in: workspace)
                loadedBoardID = nil
                loadedBoardBaseline = nil
                status = "Loaded legacy workspace-state.json."
            } else {
                workspace = Self.voiceSupportSnapshot()
                workspaceSource = "Loaded presets"
                workspaceReport = "249/500"
                selectedSlotID = firstBlankSlotID(in: workspace)
                loadedBoardID = nil
                loadedBoardBaseline = nil
                status = "Loaded device snapshot."
            }
        }
    }

    func saveWorkspace() {
        let path = root.appendingPathComponent("workspace-state.json")
        do {
            let snapshot = WorkspaceSnapshot(slots: workspace, source: workspaceSource, report: workspaceReport)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: path)
            status = "Saved workspace-state.json"
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    func importWorkspace() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                if let snapshot = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data) {
                    workspace = snapshot.slots
                    workspaceSource = snapshot.source
                    workspaceReport = snapshot.report
                } else {
                    let imported = try JSONDecoder().decode([WorkspaceSlot].self, from: data)
                workspace = imported
                workspaceSource = "Imported workspace"
                workspaceReport = "\(imported.filter { $0.name != "BLANK PRESET" }.count)/500"
                }
                selectedSlotID = firstBlankSlotID(in: workspace)
                loadedBoardID = nil
                loadedBoardBaseline = nil
                status = "Imported \(url.lastPathComponent)"
            } catch {
                status = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    func importBoards() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let imported = try JSONDecoder().decode([BoardArchive].self, from: data)
                boards = imported
                selectedBoardID = boards.first?.id
                boardNameDraft = boards.first?.title ?? ""
                loadedBoardID = nil
                loadedBoardBaseline = nil
                persistBoards()
                status = "Imported \(imported.count) boards from \(url.lastPathComponent)."
            } catch {
                status = "Board import failed: \(error.localizedDescription)"
            }
        }
    }

    func exportBoards() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "voicelive-boards.json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try JSONEncoder().encode(boards)
                try data.write(to: url)
                status = "Exported \(boards.count) boards to \(url.lastPathComponent)."
            } catch {
                status = "Board export failed: \(error.localizedDescription)"
            }
        }
    }

    func pushCurrentBoardToDevice() {
        guard device.midiConfirmed else {
            status = "VoiceLive Play MIDI destination is not available."
            return
        }

        let occupied = workspace.filter { $0.name != "BLANK PRESET" }
        guard !occupied.isEmpty else {
            status = "There are no presets to push."
            return
        }

        let payloads = resolvePayloads(for: occupied)
        let missing = occupied.count - payloads.count
        guard !payloads.isEmpty else {
            status = "No binary preset payloads were found for this board."
            return
        }

        let alert = NSAlert()
        alert.messageText = "Push presets to VoiceLive Play?"
        alert.informativeText = """
        This will send \(payloads.count) preset(s) to the connected VoiceLive Play and overwrite those slot(s) on the device.

        \(missing) board slot(s) will be skipped because their binary preset payload could not be found in the local VoiceSupport packs/backups.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Push")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            status = "Push cancelled."
            return
        }

        pushProgress = PushProgress(
            isActive: true,
            total: payloads.count,
            completed: 0,
            currentSlot: payloads.first?.slotID ?? 0,
            currentPreset: payloads.first?.name ?? "",
            log: ["Preparing \(payloads.count) preset(s). Skipping \(missing) unresolved slot(s)."]
        )
        showingPushProgress = true
        status = "Pushing \(payloads.count) preset(s) to VoiceLive Play..."
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.sendPresetPayloads(payloads) { event in
                DispatchQueue.main.async {
                    switch event {
                    case .started(let index, let total, let slotID, let name):
                        pushProgress.total = total
                        pushProgress.currentSlot = slotID
                        pushProgress.currentPreset = name
                        pushProgress.log.append("Sending \(index)/\(total): slot \(slotID) \(name)")
                    case .completed(let index, let total, let slotID, let name):
                        pushProgress.completed = index
                        pushProgress.total = total
                        pushProgress.currentSlot = slotID
                        pushProgress.currentPreset = name
                        pushProgress.log.append("Done \(index)/\(total): slot \(slotID) \(name)")
                    }
                }
            }
            DispatchQueue.main.async {
                pushProgress.isActive = false
                switch result {
                case .success:
                    for item in payloads {
                        if let index = workspace.firstIndex(where: { $0.id == item.slotID }) {
                            workspace[index].dirty = false
                        }
                    }
                    if loadedBoardID != nil {
                        syncLoadedBoardFromWorkspace()
                    }
                    status = "Pushed \(payloads.count) preset(s) to VoiceLive Play. Skipped \(missing)."
                    pushProgress.log.append("Finished. Pushed \(payloads.count), skipped \(missing).")
                case .failure(let message):
                    status = message
                    pushProgress.log.append("Failed: \(message)")
                }
            }
        }
    }

    func resolvePayloads(for slots: [WorkspaceSlot]) -> [PresetSysexPayload] {
        var cache: [String: [String: [Data]]] = [:]
        var resolved: [PresetSysexPayload] = []

        for slot in slots {
            if let messages = slot.payloadMessages, messages.count >= 2 {
                resolved.append(PresetSysexPayload(slotID: slot.id, name: slot.name, source: slot.source, messages: messages))
                continue
            }
            guard let path = tchPath(for: slot) else { continue }
            if cache[path] == nil {
                let names = presetNames(for: slot.source, path: path)
                cache[path] = Self.readPresetPayloads(from: path, names: names)
            }
            let payloadName = slot.payloadName ?? slot.name
            let key = Self.normalizedPresetName(payloadName)
            guard let messages = cache[path]?[key], messages.count >= 2 else { continue }
            resolved.append(PresetSysexPayload(slotID: slot.id, name: slot.name, source: slot.source, messages: messages))
        }

        return resolved
    }

    func resolvePayloadMessages(source: String, payloadName: String) -> [Data]? {
        let slot = WorkspaceSlot(id: selectedSlotID, name: payloadName, payloadName: payloadName, source: source, dirty: false)
        return resolvePayloads(for: [slot]).first?.messages
    }

    func tchPath(for slot: WorkspaceSlot) -> String? {
        let payloadName = slot.payloadName ?? slot.name
        if slot.source == "Device",
           let devicePullDataPath,
           FileManager.default.fileExists(atPath: devicePullDataPath) {
            return devicePullDataPath
        }
        if let pack = catalog.packs.first(where: { $0.title == slot.source || $0.presetNames.contains(payloadName) }),
           let path = pack.tchFile,
           FileManager.default.fileExists(atPath: path) {
            return path
        }
        if let backup = backups.first(where: { $0.title == slot.source || $0.presetNames.contains(payloadName) }),
           FileManager.default.fileExists(atPath: backup.dataPath) {
            return backup.dataPath
        }
        return nil
    }

    func presetNames(for source: String, path: String) -> [String] {
        if source == "Device" {
            return Self.extractPresetNames(from: path)
        }
        if let pack = catalog.packs.first(where: { $0.title == source && $0.tchFile == path }) {
            return pack.presetNames
        }
        if let backup = backups.first(where: { $0.title == source && $0.dataPath == path }) {
            return backup.presetNames
        }
        if let pack = catalog.packs.first(where: { $0.tchFile == path }) {
            return pack.presetNames
        }
        if let backup = backups.first(where: { $0.dataPath == path }) {
            return backup.presetNames
        }
        return []
    }

    static func readPresetPayloads(from path: String, names: [String]) -> [String: [Data]] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return [:]
        }

        let prefix = Data([0xF0, 0x00, 0x01, 0x38, 0x00, 0x69, 0x21])
        var ranges: [Range<Data.Index>] = []
        var searchStart = data.startIndex

        while let start = data[searchStart...].range(of: prefix)?.lowerBound,
              let end = data[start...].firstIndex(of: 0xF7) {
            ranges.append(start..<(end + 1))
            searchStart = end + 1
        }

        var payloads: [String: [Data]] = [:]
        var recordIndex = 0
        var messageIndex = 0
        while messageIndex + 1 < ranges.count {
            let recordName = recordIndex < names.count ? names[recordIndex] : inferredPresetName(in: data, before: ranges[messageIndex].lowerBound)
            let messages = [
                Data(data[ranges[messageIndex]]),
                Data(data[ranges[messageIndex + 1]])
            ]
            payloads[normalizedPresetName(recordName)] = messages
            recordIndex += 1
            messageIndex += 2
        }

        return payloads
    }

    static func inferredPresetName(in data: Data, before offset: Data.Index) -> String {
        let start = max(data.startIndex, offset - 96)
        var runs: [String] = []
        var buffer: [UInt8] = []
        for byte in data[start..<offset] {
            if byte >= 32 && byte <= 126 {
                buffer.append(byte)
            } else {
                if buffer.count >= 3 {
                    runs.append(String(decoding: buffer, as: UTF8.self))
                }
                buffer.removeAll()
            }
        }
        if buffer.count >= 3 {
            runs.append(String(decoding: buffer, as: UTF8.self))
        }
        return runs.last ?? ""
    }

    static func normalizedPresetName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    static func buildPresetHeader(slotID: Int, name: String) -> Data {
        var bytes: [UInt8] = [0xF0, 0x00, 0x01, 0x38, 0x00, 0x69, 0x20]
        bytes.append(contentsOf: pack14MSBFirst(slotID))
        bytes.append(contentsOf: pack14MSBFirst(170))

        let allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 +-=/\\!?&%"
        let cleaned = name
            .uppercased()
            .map { allowed.contains($0) ? $0 : " " }
        let nameBytes = Array(String(cleaned).prefix(15).utf8)
        bytes.append(contentsOf: nameBytes)
        if nameBytes.count < 15 {
            bytes.append(contentsOf: Array(repeating: 0x00, count: 15 - nameBytes.count))
        }

        bytes.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        bytes.append(0x01)
        bytes.append(0xF7)
        return Data(bytes)
    }

    static func pack14MSBFirst(_ value: Int) -> [UInt8] {
        let clamped = max(0, min(16_383, value))
        return [UInt8((clamped >> 7) & 0x7F), UInt8(clamped & 0x7F)]
    }

    static func sendPresetPayloads(_ payloads: [PresetSysexPayload], progress: @escaping (PushEvent) -> Void) -> PushResult {
        let destinations = midiDestinations()
        guard let destination = destinations.first(where: {
            $0.name.localizedCaseInsensitiveContains("VoiceLive")
                || $0.name.localizedCaseInsensitiveContains("TC-Helicon")
                || $0.name.localizedCaseInsensitiveContains("TC Helicon")
        }) else {
            return .failure("No VoiceLive Play MIDI destination found.")
        }

        var client = MIDIClientRef()
        var port = MIDIPortRef()
        guard MIDIClientCreate("VoiceLive Play Workbench" as CFString, nil, nil, &client) == noErr else {
            return .failure("Could not create MIDI client.")
        }
        defer { MIDIClientDispose(client) }

        guard MIDIOutputPortCreate(client, "Preset Push" as CFString, &port) == noErr else {
            return .failure("Could not create MIDI output port.")
        }
        defer { MIDIPortDispose(port) }

        for (index, payload) in payloads.enumerated() {
            progress(.started(index: index + 1, total: payloads.count, slotID: payload.slotID, name: payload.name))
            let messages = [buildPresetHeader(slotID: payload.slotID, name: payload.name)] + payload.messages
            for message in messages {
                let status = sendSysEx(message, to: destination.endpoint, via: port)
                guard status == noErr else {
                    return .failure("MIDI send failed for slot \(payload.slotID): \(status).")
                }
                Thread.sleep(forTimeInterval: 0.08)
            }
            progress(.completed(index: index + 1, total: payloads.count, slotID: payload.slotID, name: payload.name))
            Thread.sleep(forTimeInterval: 0.35)
        }

        return .success
    }

    static func sendSysEx(_ data: Data, to destination: MIDIEndpointRef, via port: MIDIPortRef) -> OSStatus {
        let packetListSize = MemoryLayout<MIDIPacketList>.size + data.count + 256
        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: packetListSize, alignment: MemoryLayout<MIDIPacketList>.alignment)
        defer { rawPointer.deallocate() }

        let packetList = rawPointer.bindMemory(to: MIDIPacketList.self, capacity: 1)
        var packet = MIDIPacketListInit(packetList)
        let result = data.withUnsafeBytes { buffer -> OSStatus in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else {
                return OSStatus(paramErr)
            }
            packet = MIDIPacketListAdd(packetList, packetListSize, packet, 0, data.count, base)
            return MIDISend(port, destination, packetList)
        }
        return result
    }

    static func midiDestinations() -> [(endpoint: MIDIEndpointRef, name: String)] {
        var destinations: [(MIDIEndpointRef, String)] = []
        for index in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(index)
            destinations.append((endpoint, midiObjectName(endpoint) ?? ""))
        }
        return destinations
    }

    func exportWorkspace() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "voicelive-workspace.json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let snapshot = WorkspaceSnapshot(slots: workspace, source: workspaceSource, report: workspaceReport)
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url)
                status = "Exported \(url.lastPathComponent)"
            } catch {
                status = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    func resetWorkspace() {
        workspace = Self.voiceSupportSnapshot()
        workspaceSource = "Loaded presets"
        workspaceReport = "249/500"
        selectedSlotID = firstBlankSlotID(in: workspace)
        loadedBoardID = nil
        loadedBoardBaseline = nil
        status = "Loaded current presets."
    }

    func placeSelectedPresetInSelectedSlot() {
        guard let preset = selectedPreset else {
            status = "Select a pack preset first, then choose a workspace slot."
            return
        }
        let sourceTitle = selectedPresetSourceTitle ?? selectedPack?.title ?? "Cloud"
        placePreset(preset, payloadName: preset, source: sourceTitle, intoSlot: selectedSlotID)
    }

    func placePreset(_ preset: String, payloadName: String, source: String, intoSlot slotID: Int, payloadMessages: [Data]? = nil) {
        guard workspace.indices.contains(slotID - 1) else {
            status = "Slot \(slotID) is not available."
            return
        }
        selectedSlotID = slotID
        activeArea = .workspace
        workspace[slotID - 1] = WorkspaceSlot(id: slotID, name: preset, payloadName: payloadName, source: source, dirty: true, payloadMessages: payloadMessages)
        workspaceReport = "\(occupiedSlots)/500"
        if let board = loadedBoard {
            workspaceSource = board.title
            syncLoadedBoardFromWorkspace()
            status = "Placed \(preset) into slot \(slotID) on \(board.title)."
        } else {
            workspaceSource = "Local edited draft"
            status = "Placed \(preset) into slot \(slotID) locally. Add a board to keep working as a board."
        }
    }

    func refreshDevice() {
        status = "Checking VoiceLive Play connection..."
        DispatchQueue.global(qos: .userInitiated).async {
            let newStatus = Self.detectDevice()
            DispatchQueue.main.async {
                device = newStatus
                status = newStatus.detail
            }
        }
    }

    func checkEndpoint() {
        DispatchQueue.global(qos: .utility).async {
            var request = URLRequest(url: URL(string: "https://www.tc-helicon.com/VoiceSupport2/masterDescriptor.xml")!)
            request.timeoutInterval = 4
            let sem = DispatchSemaphore(value: 0)
            var result = "Missing"
            URLSession.shared.dataTask(with: request) { data, _, _ in
                if let data, String(data: data, encoding: .utf8)?.contains("CONTROL_DESCRIPTOR") == true {
                    result = "Ready"
                }
                sem.signal()
            }.resume()
            _ = sem.wait(timeout: .now() + 5)
            DispatchQueue.main.async { endpointStatus = result }
        }
    }

    func loadFirmware() {
        let path = firmwareCatalogURL()
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            latestFirmware = "Unknown"
            firmwareUpdates = []
            return
        }
        firmwareUpdates = Self.parseFirmwareUpdates(from: text, firmwareFolder: firmwareFolderURL())
        latestFirmware = firmwareUpdates.last?.version ?? "Unknown"
    }

    func firmwareCatalogURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/TC-Helicon/VoiceSupport 2/VoiceLive Play/firmware.xml")
    }

    func firmwareFolderURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/TC-Helicon/VoiceSupport 2/VoiceLive Play/firmware")
    }

    static func parseFirmwareUpdates(from text: String, firmwareFolder: URL) -> [FirmwareUpdateInfo] {
        let blocks = blocks(in: text, tag: "firmwareUpdate")
        return blocks.map { block in
            let version = firstValue(in: block, tag: "version") ?? "Unknown"
            let pubDate = firstValue(in: block, tag: "pubDate") ?? ""
            let link = firstValue(in: block, tag: "link") ?? ""
            let notes = values(in: block, tag: "line")
            let filename = link.removingPercentEncoding.flatMap { URL(string: $0)?.lastPathComponent }
                ?? "\(version).syx"
            let local = firmwareFolder.appendingPathComponent(filename).path
            return FirmwareUpdateInfo(
                version: version,
                pubDate: pubDate,
                notes: notes,
                link: link,
                localPath: FileManager.default.fileExists(atPath: local) ? local : nil
            )
        }
    }

    static func blocks(in xml: String, tag: String) -> [String] {
        var blocks: [String] = []
        let open = "<\(tag)>"
        let close = "</\(tag)>"
        var remainder = xml[...]
        while let start = remainder.range(of: open),
              let end = remainder[start.upperBound...].range(of: close) {
            blocks.append(String(remainder[start.lowerBound..<end.upperBound]))
            remainder = remainder[end.upperBound...]
        }
        return blocks
    }

    func fetchLatestFirmware() {
        guard let latest = firmwareUpdates.last,
              latest.localPath == nil,
              let url = URL(string: latest.link) else {
            status = "Latest firmware is already downloaded."
            return
        }
        status = "Fetching firmware \(latest.version)..."
        URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            DispatchQueue.main.async {
                if let error {
                    status = "Firmware fetch failed: \(error.localizedDescription)"
                    return
                }
                guard let tempURL else {
                    status = "Firmware fetch failed: no file was returned."
                    return
                }
                do {
                    let folder = firmwareFolderURL()
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let destination = folder.appendingPathComponent(url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                    loadFirmware()
                    status = "Downloaded firmware \(latest.version)."
                } catch {
                    status = "Firmware save failed: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func openVoiceSupport() {
        let appURL = URL(fileURLWithPath: "/Applications/VoiceSupport2.app")
        if FileManager.default.fileExists(atPath: appURL.path) {
            NSWorkspace.shared.open(appURL)
            status = "Opened VoiceSupport 2 for firmware update."
        } else {
            status = "VoiceSupport 2 is not installed in /Applications."
        }
    }

    static func detectDevice() -> DeviceStatus {
        let midiNames = midiEndpointNames()
        let midiMatches = midiNames.filter {
            $0.localizedCaseInsensitiveContains("VoiceLive")
                || $0.localizedCaseInsensitiveContains("TC-Helicon")
                || $0.localizedCaseInsensitiveContains("TC Helicon")
        }
        let uniqueMidiMatches = Array(NSOrderedSet(array: midiMatches)) as? [String] ?? midiMatches

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPUSBDataType", "SPAudioDataType", "SPMIDIDataType"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let hasDevice = output.contains("VoiceLive Play") && (output.contains("TC-Helicon") || output.contains("TC Helicon"))
            if !uniqueMidiMatches.isEmpty {
                return DeviceStatus(connected: true, midiConfirmed: true, title: "VoiceLive Play", detail: "Connected")
            }
            if hasDevice {
                return DeviceStatus(connected: true, midiConfirmed: false, title: "VoiceLive Play", detail: "Connected")
            }
        } catch {
            return DeviceStatus(connected: false, midiConfirmed: false, title: "Not detected", detail: "Device scan failed")
        }
        return DeviceStatus(connected: false, midiConfirmed: false, title: "Not detected", detail: "Connect VoiceLive Play over USB, then Refresh")
    }

    static func midiEndpointNames() -> [String] {
        var names: [String] = []
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            if let name = midiObjectName(endpoint) {
                names.append(name)
            }
        }
        for index in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(index)
            if let name = midiObjectName(endpoint) {
                names.append(name)
            }
        }
        return names
    }

    static func midiObjectName(_ object: MIDIObjectRef) -> String? {
        var unmanagedName: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(object, kMIDIPropertyName, &unmanagedName)
        guard status == noErr, let unmanagedName else { return nil }
        return unmanagedName.takeRetainedValue() as String
    }

    static func voiceSupportSnapshot() -> [WorkspaceSlot] {
        let observed: [Int: String] = [
            1: "GORGEOUS HALL", 2: "PAUL PRESENT", 3: "ELVIS RADIO", 4: "MEGAPHONE",
            5: "PONG PAUL", 6: "KIMBRA LOFI DLY", 8: "KIMBRA TRT OC -", 11: "HANNAH LIVE",
            25: "CYBORG", 26: "EDGE OF GAGA", 27: "AMERICAN GRNDAY", 28: "IN AIR 2NIGHT",
            29: "GEDDIT STARTED", 30: "TAYLOR SPARKS", 31: "I AM EGGMAN", 32: "TEEN DREAM KP",
            33: "BAREFOOT BLUEJN", 34: "BOYS O' FALL", 35: "ON THEFLOOR JLO", 36: "PINK MONEY",
            37: "AS GOOD AS I WS", 38: "LOVE WAY U LIE", 39: "HOW TA LOVE LIL", 40: "YMCA PEOPLE",
            41: "PAPARAZZI", 42: "GTTA B SOMEBODY", 43: "THX 4 THE MMRS", 44: "NO ONE ALICIA K",
            45: "KRYPTONITE 3DD", 46: "HEY JUDE-Y", 47: "HOLD ON CORN", 48: "SUMMER 1969",
            49: "WANT U2 WANT ME", 50: "IN MY COLDPLACE", 51: "CALL HOTEL", 52: "BRING ME 2 LIFE",
            53: "EVER LONG FOO'S", 54: "GREEN HOLIDAY", 55: "I'LL COME4U NBK", 56: "SUPERMAN PEACE",
            57: "BRICKWALL FLOYD", 58: "TALK 2 YA L8R", 59: "YOU BELONG W/ME", 60: "CLUB CANT HNDL",
            61: "LOVESONG MANSON", 62: "ROLLIN DEEP", 63: "U MAKE ME COBRA", 64: "TGIF?",
            65: "TAKE A BROAD", 66: "LEICA LOVESNG", 67: "SMILE AVRIL", 68: "STRANGE GLOVE",
            69: "FEELGD GORILLAS", 70: "PAIN JETWRLD", 71: "HEAR 2 STAY", 72: "CLOSER NIN",
            73: "LOSNG RELIGION", 74: "THEN MORNIN CMS", 75: "JST SAY YES", 76: "MEMORIES WZR",
            77: "SOLDIER DIXIES", 78: "FOLSOM CASH", 79: "BLUE RHIMES", 80: "EASY FLATTS",
            81: "LIKE U WERE DNG", 82: "50 CENT CANDY", 83: "WHERE THEM GRLS", 84: "DON'T TREAD 311",
            85: "TRU FAITH", 86: "HOT IN HRRE", 87: "HOLD IT AGAINST", 88: "HANDS UP",
            89: "BABY BIEBER", 90: "TICKTOCK", 91: "WE R WHO WE R", 92: "FIX U",
            93: "LOLLIPOP", 94: "POKERFACE", 95: "RITE B4 YR EYES", 96: "DJ GOT US FALLN",
            97: "LIVING ON PRAYR", 98: "SURRENDER", 99: "JUST WHAT INEED", 100: "DOG DAYS ROVER",
            101: "HURTS GOOD", 102: "BACK BLACK +OCT", 103: "PARTY ANTHEM", 104: "JAGGER MOVES",
            105: "GOODLIFE", 106: "GEORGE M FAITH", 107: "DYNAMITE CRUISE", 108: "APOLOGIZE TLAND",
            109: "VIOL HILL", 110: "FASTLANE EAGLE", 111: "BENNIE & JETZ", 112: "GO YR OWN WAY",
            113: "2PRINCES S DOCS", 114: "WILDE HORSES", 115: "STEVE MCQUEEN", 116: "RUNNING ON MT",
            117: "BELIEVE SHARE", 118: "MOMENT SHANIA", 119: "THIS LOVE M5", 120: "VOGUE MDONNA",
            121: "U GIVE LOVE B-N", 122: "HOOCHIE MAN", 123: "LIKE TN SPIRIT", 124: "B4 HE CHEATS",
            125: "GRENADE FM MARS", 126: "I STILL HAVEN'T", 127: "DIRE STR8Z WALK", 128: "CRAZY CLINE",
            129: "GALAXIES OWL CT", 130: "TAKE IT OFF K$A", 131: "EVENFLOW JAM", 132: "OFF SPRING JOB",
            133: "ROCKET MANN", 134: "CALIFORNIA KATY", 135: "INTER GALACTIC", 136: "WATCHA DERULO",
            137: "SHOW GOES LUPE", 138: "STORY OF TAYLOR", 139: "BILLIE J MJ", 140: "COME 2GETHER",
            141: "TAKE IT EZ", 142: "ENTER METALLICA", 143: "BUILDING MYSTRY", 144: "TREWLY TIRED",
            145: "TRAGIC COURAGE", 146: "ALL I'VE USED", 147: "WANNA SPICE?", 148: "MORE EXEPTIONS",
            149: "PARADISE ROSE", 150: "NOVEMBER GUNS", 151: "RED GRETCHEN", 152: "DON'T STAND SO",
            153: "GET ON YR BOOTS", 154: "M&M NOT AFR8D", 155: "HAPPY MUD VEIN", 156: "BEST EVER HAD",
            157: "HILLS OF BEVRLY", 158: "WKIN ON THE SUN", 159: "STEREO GOLD DBL", 160: "GROUP SHOUT",
            161: "DOUBLE DOWN", 162: "DOUBLE UP", 163: "BEASTIE SHOUT", 164: "OCTAVE SHOUT",
            165: "ARENA CHANT", 166: "EMJAY 2011", 167: "TINKER BELL", 168: "THICKER YOU",
            169: "POPEYE", 170: "MALE TO FEMALE", 171: "DEEP TALKER", 172: "TOTALLY ALIEN!",
            173: "OCT UP UNISON", 174: "SPRING REVERB", 175: "PLATE VERB+DBL", 176: "PRACTICE ROOM",
            177: "JUST AMBIENCE", 178: "OLD SPRING VERB", 179: "BRIGHT VERB", 180: "CAVERNOUS VERB",
            181: "BOUNCY ROOM", 182: "MOD TAIL VERB", 183: "ECHO VERB", 184: "SLAP ROOM VERB",
            185: "SINGLE SLAP", 186: "ROCKABILLY SLAP", 187: "TAPE ECHO", 188: "PING PONG ECHO",
            189: "LR RHYTHM ECHO", 190: "TRIPLET ECHO", 191: "LO FI ECHO", 192: "LR M'PHONE ECHO",
            193: "1/4 DELAY", 194: "LONG TRIP DELAY", 195: "TOTAL IMMERSION", 196: "MARBLE WALLS",
            197: "CLOCK RADIO", 198: "DISTORTED RADIO", 199: "DISTORT DOWN", 200: "DARK RM DBL",
            201: "CHORUS DLY DBL", 202: "DISTORTED VOX", 203: "SING GUITARSOLO", 204: "FLANGER",
            205: "ROTOR CABINET", 206: "FALLING 4EVER", 207: "AUTO WAWAWA", 208: "NICE CHORUS",
            209: "STRANGE ECHO", 210: "MEGAPHONE ECHO", 211: "LONG TAPE ECHO", 212: "INHUMAN",
            213: "OCTAVE GANG", 214: "1984", 215: "BUNCH O BASS", 216: "TUNED UP + DOWN",
            217: "TWO HIGH", 218: "CHORALE THREE", 219: "RADIOHARMNYDLY", 220: "POP DUO",
            221: "HI LO BACKUP", 222: "DEEP DOWN", 223: "CLOSE 1UP+1DOWN", 224: "CLOSE BELOW",
            225: "WET OCTAVE DN", 226: "ONE UP ROOM", 227: "COUNTRY GIRLS", 228: "POP TRIO",
            229: "LOWER DUO", 230: "LOWER + DOUBLE", 231: "DARK SWIRL", 232: "TWO LOW",
            233: "FIFTH UP", 234: "UP TWO ROOM", 235: "SLAP ABOVE", 236: "UPDN FLANGE DLY",
            237: "BEACHBOY RADIO", 238: "TUNED 2 UP", 239: "TUNED 1 BELOW", 240: "GREGORIAN",
            241: "AUTOTUNE RADIO", 242: "ELVIS RADIO", 243: "DISTORTO", 244: "SOFT FLANGE",
            245: "ROBO DELAY", 246: "ROBO + DBL", 247: "AUTO PANNER", 248: "OCTAVE FLANGE",
            249: "4TH SHIFT+OCTDN"
        ]
        return (1...500).map { id in
            let name = observed[id] ?? "BLANK PRESET"
            return WorkspaceSlot(id: id, name: name, payloadName: name == "BLANK PRESET" ? nil : name, source: "Loaded presets", dirty: false)
        }
    }
}

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = appDelegate
app.run()
