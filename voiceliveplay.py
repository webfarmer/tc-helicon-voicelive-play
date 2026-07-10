#!/usr/bin/env python3
"""Native desktop workbench for TC-Helicon VoiceLive Play preset libraries."""

from __future__ import annotations

import json
import subprocess
import threading
import traceback
import tkinter as tk
from dataclasses import dataclass
from pathlib import Path
from tkinter import filedialog, messagebox


ROOT = Path(__file__).resolve().parent
CATALOG_PATH = ROOT / "src" / "data" / "generated" / "voiceSupportCatalog.json"
STATE_PATH = ROOT / "workspace-state.json"
FIRMWARE_PATH = (
    Path.home()
    / "Library"
    / "Application Support"
    / "TC-Helicon"
    / "VoiceSupport 2"
    / "VoiceLive Play"
    / "firmware.xml"
)
SLOT_COUNT = 500

BG = "#eef2f5"
PANEL = "#f7f9fb"
SURFACE = "#fbfcfd"
WHITE = "#ffffff"
LINE = "#cfd8e3"
TEXT = "#17202a"
MUTED = "#647486"
BLUE = "#1677c9"
BLUE_DARK = "#0f5f9f"
OK = "#20a269"
WARN = "#8a5a00"
BAD = "#b44b42"
LOCK_BG = "#fff7e8"


@dataclass
class WorkspaceSlot:
    slot_id: int
    name: str
    source: str = ""
    dirty: bool = False


@dataclass
class DeviceStatus:
    connected: bool
    midi_confirmed: bool
    name: str
    detail: str


def initial_workspace() -> list[WorkspaceSlot]:
    names = {1: "PAUL PRESENT", 2: "MEGAPHONE", 3: "GORGEOUS HALL", 4: "PONG PAUL"}
    return [WorkspaceSlot(i, names.get(i, "BLANK PRESET")) for i in range(1, SLOT_COUNT + 1)]


def read_catalog() -> dict:
    if not CATALOG_PATH.exists():
        return {"packs": []}
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def detect_device() -> DeviceStatus:
    try:
        result = subprocess.run(
            ["/usr/sbin/system_profiler", "SPUSBDataType", "SPAudioDataType", "SPMIDIDataType"],
            capture_output=True,
            text=True,
            timeout=12,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return DeviceStatus(False, False, "Not detected", f"Device scan failed: {exc}")

    output = result.stdout
    has_device = "VoiceLive Play" in output and ("TC-Helicon" in output or "TC Helicon" in output)
    has_midi = has_device and "MIDI" in output
    if has_midi:
        return DeviceStatus(True, True, "VoiceLive Play", "USB/MIDI detected by macOS")
    if has_device:
        return DeviceStatus(True, False, "VoiceLive Play", "USB audio detected; MIDI handshake not confirmed")
    return DeviceStatus(False, False, "Not detected", "Connect VoiceLive Play over USB, then Refresh")


def latest_firmware() -> str:
    if not FIRMWARE_PATH.exists():
        return "Unknown"
    versions: list[str] = []
    for line in FIRMWARE_PATH.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line.startswith("<version>") and line.endswith("</version>"):
            versions.append(line.replace("<version>", "").replace("</version>", ""))
    return versions[-1] if versions else "Unknown"


class Workbench(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("VoiceLive Play Workbench")
        self.geometry("1360x840")
        self.minsize(1120, 720)
        self.configure(bg=BG)
        self.option_add("*Background", BG)
        self.option_add("*Foreground", TEXT)
        self.option_add("*Listbox.background", WHITE)
        self.option_add("*Listbox.foreground", TEXT)
        self.option_add("*Entry.background", WHITE)
        self.option_add("*Entry.foreground", TEXT)

        self.catalog = read_catalog()
        self.packs = self.catalog.get("packs", [])
        self.workspace = self.load_workspace()
        self.selected_pack_index = 0
        self.device = DeviceStatus(False, False, "Checking...", "Device scan will start after the UI loads")

        self.search_var = tk.StringVar()
        self.slot_var = tk.StringVar(value="1")
        self.status_var = tk.StringVar(value="Loading workbench...")

        self.build_menu()
        self.build_ui()
        self.populate_packs()
        self.populate_workspace()
        self.select_pack(0)
        self.update_device_ui()
        self.after(150, self.refresh_device)

    def load_workspace(self) -> list[WorkspaceSlot]:
        if not STATE_PATH.exists():
            return initial_workspace()
        try:
            raw = json.loads(STATE_PATH.read_text(encoding="utf-8"))
            slots = [WorkspaceSlot(**item) for item in raw]
            if len(slots) == SLOT_COUNT:
                return slots
        except (TypeError, ValueError, json.JSONDecodeError):
            pass
        return initial_workspace()

    def build_menu(self) -> None:
        menu = tk.Menu(self)
        file_menu = tk.Menu(menu, tearoff=False)
        file_menu.add_command(label="Save Workspace", command=self.save_workspace)
        file_menu.add_command(label="Load Workspace...", command=self.import_workspace)
        file_menu.add_command(label="Export Workspace...", command=self.export_workspace)
        file_menu.add_separator()
        file_menu.add_command(label="Quit", command=self.destroy)
        menu.add_cascade(label="File", menu=file_menu)

        workbench_menu = tk.Menu(menu, tearoff=False)
        workbench_menu.add_command(label="Refresh Device", command=self.refresh_device)
        workbench_menu.add_command(label="Refresh Catalog", command=self.refresh_catalog)
        workbench_menu.add_command(label="Reset Workspace", command=self.reset_workspace)
        menu.add_cascade(label="Workbench", menu=workbench_menu)
        self.config(menu=menu)

    def build_ui(self) -> None:
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        sidebar = tk.Frame(self, bg=PANEL, width=270, highlightbackground=LINE, highlightthickness=1)
        sidebar.grid(row=0, column=0, sticky="nsew")
        sidebar.grid_propagate(False)
        sidebar.grid_rowconfigure(3, weight=1)

        brand = tk.Frame(sidebar, bg=PANEL)
        brand.grid(row=0, column=0, sticky="ew", padx=18, pady=(18, 22))
        tk.Label(brand, text="VL", bg=BLUE, fg=WHITE, font=("Helvetica", 14, "bold"), width=4, height=2).pack(side="left", padx=(0, 12))
        brand_text = tk.Frame(brand, bg=PANEL)
        brand_text.pack(side="left", fill="x", expand=True)
        tk.Label(brand_text, text="VoiceLive Play", bg=PANEL, fg=TEXT, font=("Helvetica", 17, "bold")).pack(anchor="w")
        tk.Label(brand_text, text="Local preset librarian", bg=PANEL, fg=MUTED, font=("Helvetica", 11)).pack(anchor="w")

        nav = tk.Frame(sidebar, bg=PANEL)
        nav.grid(row=1, column=0, sticky="ew", padx=18)
        for label, active in (("Device", True), ("Local Packs", False), ("Captures", False), ("Safety", False)):
            tk.Label(
                nav,
                text=label,
                bg="#e8eef5" if active else PANEL,
                fg=BLUE_DARK if active else "#384657",
                anchor="w",
                padx=12,
                pady=9,
                font=("Helvetica", 12, "bold" if active else "normal"),
            ).pack(fill="x", pady=2)

        device_card = tk.Frame(sidebar, bg=WHITE, highlightbackground=LINE, highlightthickness=1)
        device_card.grid(row=4, column=0, sticky="ew", padx=18, pady=18)
        self.device_dot = tk.Canvas(device_card, width=18, height=18, bg=WHITE, highlightthickness=0)
        self.device_dot.grid(row=0, column=0, rowspan=2, padx=(12, 8), pady=12, sticky="n")
        self.device_name = tk.Label(device_card, text="", bg=WHITE, fg=TEXT, font=("Helvetica", 12, "bold"), anchor="w")
        self.device_name.grid(row=0, column=1, sticky="ew", padx=(0, 12), pady=(10, 0))
        self.device_detail = tk.Label(device_card, text="", bg=WHITE, fg=MUTED, font=("Helvetica", 11), wraplength=190, justify="left", anchor="w")
        self.device_detail.grid(row=1, column=1, sticky="ew", padx=(0, 12), pady=(2, 10))
        tk.Button(device_card, text="Refresh Device", command=self.refresh_device, bg="#edf3f8", fg="#435367", relief="flat").grid(row=2, column=0, columnspan=2, sticky="ew", padx=12, pady=(0, 12))

        main = tk.Frame(self, bg=BG)
        main.grid(row=0, column=1, sticky="nsew")
        main.grid_columnconfigure(0, weight=1)
        main.grid_rowconfigure(2, weight=1)

        toolbar = tk.Frame(main, bg=SURFACE, highlightbackground=LINE, highlightthickness=1)
        toolbar.grid(row=0, column=0, sticky="ew")
        toolbar.grid_columnconfigure(5, weight=1)
        self.tool_button(toolbar, "Save", self.save_workspace).grid(row=0, column=0, padx=(18, 6), pady=12)
        self.tool_button(toolbar, "Refresh Device", self.refresh_device).grid(row=0, column=1, padx=6, pady=12)
        self.tool_button(toolbar, "Reset", self.reset_workspace).grid(row=0, column=2, padx=(6, 12), pady=12)
        self.lock_label = tk.Label(toolbar, text="Device writes locked", bg=LOCK_BG, fg=WARN, font=("Helvetica", 12, "bold"), padx=11, pady=8)
        self.lock_label.grid(row=0, column=3, padx=(0, 12), pady=12)

        search_frame = tk.Frame(toolbar, bg=WHITE, highlightbackground=LINE, highlightthickness=1)
        search_frame.grid(row=0, column=6, sticky="e", padx=18, pady=12)
        tk.Label(search_frame, text="Search", bg=WHITE, fg=MUTED, padx=10).pack(side="left")
        search = tk.Entry(search_frame, textvariable=self.search_var, width=34, bd=0, bg=WHITE, fg=TEXT, font=("Helvetica", 12))
        search.pack(side="left", ipady=8, padx=(0, 10))
        self.search_var.trace_add("write", lambda *_: self.populate_presets())

        metrics = tk.Frame(main, bg=WHITE, highlightbackground=LINE, highlightthickness=1)
        metrics.grid(row=1, column=0, sticky="ew")
        metrics.grid_columnconfigure((0, 1, 2, 3), weight=1)
        self.metric_values: list[tk.Label] = []
        for index, label in enumerate(("Device", "Latest firmware", "Preset blocks", "Workspace")):
            metric = tk.Frame(metrics, bg=WHITE, highlightbackground="#e1e7ee", highlightthickness=1)
            metric.grid(row=0, column=index, sticky="ew")
            value = tk.Label(metric, text="0", bg=WHITE, fg=TEXT, font=("Helvetica", 18, "bold"), anchor="w")
            value.pack(anchor="w", padx=18, pady=(10, 0))
            tk.Label(metric, text=label.upper(), bg=WHITE, fg=MUTED, font=("Helvetica", 10, "bold"), anchor="w").pack(anchor="w", padx=18, pady=(2, 10))
            self.metric_values.append(value)

        content = tk.Frame(main, bg=LINE)
        content.grid(row=2, column=0, sticky="nsew")
        content.grid_columnconfigure(1, weight=1)
        content.grid_rowconfigure(0, weight=1)

        left = tk.Frame(content, bg=SURFACE)
        left.grid(row=0, column=0, sticky="nsew", padx=(0, 1))
        left.grid_rowconfigure(5, weight=1)
        tk.Label(left, text="Local pack browser", bg=SURFACE, fg=TEXT, font=("Helvetica", 13, "bold"), anchor="w").grid(row=0, column=0, sticky="ew", padx=14, pady=(12, 8))
        self.pack_list = tk.Listbox(left, width=42, height=13, bg=WHITE, fg=TEXT, font=("Helvetica", 12), exportselection=False)
        self.pack_list.grid(row=1, column=0, sticky="ew", padx=14)
        self.pack_list.bind("<<ListboxSelect>>", self.on_pack_select)
        self.pack_detail = tk.Label(left, text="", bg=SURFACE, fg=MUTED, justify="left", wraplength=360, anchor="w", font=("Helvetica", 11))
        self.pack_detail.grid(row=2, column=0, sticky="ew", padx=14, pady=10)
        tk.Label(left, text="Pack presets", bg=SURFACE, fg=TEXT, font=("Helvetica", 13, "bold"), anchor="w").grid(row=3, column=0, sticky="ew", padx=14, pady=(0, 8))
        self.preset_list = tk.Listbox(left, width=42, bg=WHITE, fg=TEXT, font=("Helvetica", 12), exportselection=False)
        self.preset_list.grid(row=5, column=0, sticky="nsew", padx=14, pady=(0, 14))
        self.preset_list.bind("<Double-Button-1>", lambda _event: self.assign_selected_preset())

        right = tk.Frame(content, bg=SURFACE)
        right.grid(row=0, column=1, sticky="nsew")
        right.grid_columnconfigure(0, weight=1)
        right.grid_rowconfigure(2, weight=1)
        title_row = tk.Frame(right, bg=SURFACE)
        title_row.grid(row=0, column=0, sticky="ew", padx=14, pady=(12, 8))
        tk.Label(title_row, text="500-slot workspace", bg=SURFACE, fg=TEXT, font=("Helvetica", 13, "bold")).pack(side="left")
        tk.Label(title_row, text="read-only device writes until MIDI is confirmed", bg=SURFACE, fg=MUTED, font=("Helvetica", 11)).pack(side="right")
        assign = tk.Frame(right, bg=SURFACE)
        assign.grid(row=1, column=0, sticky="ew", padx=14, pady=(0, 10))
        tk.Label(assign, text="Target slot", bg=SURFACE, fg=TEXT, font=("Helvetica", 12)).pack(side="left")
        tk.Entry(assign, textvariable=self.slot_var, width=7, font=("Helvetica", 12)).pack(side="left", padx=8)
        self.tool_button(assign, "Stage Selected Preset", self.assign_selected_preset).pack(side="left")
        tk.Label(assign, text="Local workspace only.", bg=SURFACE, fg=MUTED, font=("Helvetica", 11)).pack(side="left", padx=12)

        workspace_wrap = tk.Frame(right, bg=SURFACE)
        workspace_wrap.grid(row=2, column=0, sticky="nsew", padx=14, pady=(0, 14))
        workspace_wrap.grid_columnconfigure(0, weight=1)
        workspace_wrap.grid_rowconfigure(0, weight=1)
        self.workspace_list = tk.Listbox(workspace_wrap, bg=WHITE, fg=TEXT, font=("Menlo", 12), exportselection=False)
        self.workspace_list.grid(row=0, column=0, sticky="nsew")
        workspace_scroll = tk.Scrollbar(workspace_wrap, orient="vertical", command=self.workspace_list.yview)
        workspace_scroll.grid(row=0, column=1, sticky="ns")
        self.workspace_list.configure(yscrollcommand=workspace_scroll.set)
        self.workspace_list.bind("<<ListboxSelect>>", self.on_slot_select)

        status = tk.Label(self, textvariable=self.status_var, bg="#d9e4eb", fg="#31556a", anchor="w", padx=12, pady=7, font=("Helvetica", 12))
        status.grid(row=1, column=0, columnspan=2, sticky="ew")

    def tool_button(self, parent: tk.Widget, text: str, command) -> tk.Button:
        return tk.Button(parent, text=text, command=command, bg="#edf3f8", fg="#435367", relief="flat", padx=10, pady=7, font=("Helvetica", 12))

    def populate_packs(self) -> None:
        self.pack_list.delete(0, tk.END)
        for pack in self.packs:
            self.pack_list.insert(tk.END, f"{pack.get('title', 'Untitled')}  ({pack.get('presetCount', 0)})")
        self.update_metrics()

    def select_pack(self, index: int) -> None:
        if not self.packs:
            return
        self.selected_pack_index = max(0, min(index, len(self.packs) - 1))
        self.pack_list.selection_clear(0, tk.END)
        self.pack_list.selection_set(self.selected_pack_index)
        self.pack_list.see(self.selected_pack_index)
        self.populate_presets()

    def on_pack_select(self, _event: tk.Event) -> None:
        selected = self.pack_list.curselection()
        if selected:
            self.selected_pack_index = selected[0]
            self.populate_presets()

    def populate_presets(self) -> None:
        self.preset_list.delete(0, tk.END)
        if not self.packs:
            self.pack_detail.configure(text="No preset packs loaded.")
            return
        pack = self.packs[self.selected_pack_index]
        self.pack_detail.configure(
            text=(
                f"{pack.get('title', 'Untitled')}\n"
                f"{pack.get('presetCount', 0)} presets | "
                f"{pack.get('sysexBlockCount', 0)} SysEx blocks | "
                f"build {pack.get('buildNo', 'unknown')}"
            )
        )
        query = self.search_var.get().strip().lower()
        for name in pack.get("presetNames", []):
            if not query or query in name.lower():
                self.preset_list.insert(tk.END, name)

    def populate_workspace(self) -> None:
        self.workspace_list.delete(0, tk.END)
        for slot in self.workspace:
            mark = "*" if slot.dirty else " "
            source = slot.source[:22].ljust(22)
            self.workspace_list.insert(tk.END, f"{slot.slot_id:03d} {mark} {slot.name[:28].ljust(28)} {source}")
        self.update_metrics()

    def on_slot_select(self, _event: tk.Event) -> None:
        selected = self.workspace_list.curselection()
        if selected:
            self.slot_var.set(str(selected[0] + 1))

    def assign_selected_preset(self) -> None:
        selected = self.preset_list.curselection()
        if not selected:
            self.status_var.set("Select a preset first.")
            return
        try:
            slot_id = int(self.slot_var.get())
        except ValueError:
            self.status_var.set("Target slot must be a number.")
            return
        if slot_id < 1 or slot_id > SLOT_COUNT:
            self.status_var.set(f"Target slot must be 1-{SLOT_COUNT}.")
            return
        preset_name = self.preset_list.get(selected[0])
        pack_title = self.packs[self.selected_pack_index].get("title", "")
        self.workspace[slot_id - 1] = WorkspaceSlot(slot_id, preset_name, pack_title, True)
        self.populate_workspace()
        self.workspace_list.selection_clear(0, tk.END)
        self.workspace_list.selection_set(slot_id - 1)
        self.workspace_list.see(slot_id - 1)
        self.status_var.set(f"Staged {preset_name} into slot {slot_id}. Device writes remain locked.")

    def update_device_ui(self) -> None:
        color = BAD
        if self.device.connected:
            color = OK if self.device.midi_confirmed else WARN
        self.device_dot.delete("all")
        self.device_dot.create_oval(3, 3, 15, 15, fill=color, outline=color)
        self.device_name.configure(text=self.device.name)
        self.device_detail.configure(text=self.device.detail)
        if self.device.midi_confirmed:
            self.lock_label.configure(text="MIDI detected; writes locked", bg=LOCK_BG, fg=WARN)
        elif self.device.connected:
            self.lock_label.configure(text="USB detected; MIDI not confirmed", bg=LOCK_BG, fg=WARN)
        else:
            self.lock_label.configure(text="Connect VoiceLive Play", bg=LOCK_BG, fg=BAD)
        self.update_metrics()

    def update_metrics(self) -> None:
        if not hasattr(self, "metric_values"):
            return
        total_blocks = sum(int(pack.get("sysexBlockCount", 0)) for pack in self.packs)
        modified = sum(1 for slot in self.workspace if slot.dirty)
        self.metric_values[0].configure(text="Connected" if self.device.connected else "Missing")
        self.metric_values[1].configure(text=latest_firmware())
        self.metric_values[2].configure(text=str(total_blocks))
        self.metric_values[3].configure(text=f"{modified}/{SLOT_COUNT}")

    def refresh_device(self) -> None:
        self.device = DeviceStatus(False, False, "Checking...", "Scanning USB, audio, and MIDI devices")
        self.update_device_ui()
        self.status_var.set("Checking VoiceLive Play connection...")

        def worker() -> None:
            status = detect_device()
            self.after(0, lambda: self.apply_device_status(status))

        threading.Thread(target=worker, daemon=True).start()

    def apply_device_status(self, status: DeviceStatus) -> None:
        self.device = status
        self.update_device_ui()
        if status.connected:
            self.status_var.set(f"{status.detail}. Local catalog loaded; device writes are locked.")
        else:
            self.status_var.set(status.detail)

    def save_workspace(self) -> None:
        STATE_PATH.write_text(json.dumps([slot.__dict__ for slot in self.workspace], indent=2), encoding="utf-8")
        self.status_var.set(f"Saved workspace to {STATE_PATH.name}")

    def import_workspace(self) -> None:
        path = filedialog.askopenfilename(title="Load workspace", filetypes=(("JSON files", "*.json"), ("All files", "*.*")))
        if not path:
            return
        raw = json.loads(Path(path).read_text(encoding="utf-8"))
        self.workspace = [WorkspaceSlot(**item) for item in raw]
        self.populate_workspace()
        self.status_var.set(f"Loaded {Path(path).name}")

    def export_workspace(self) -> None:
        path = filedialog.asksaveasfilename(title="Export workspace", defaultextension=".json", filetypes=(("JSON files", "*.json"), ("All files", "*.*")))
        if not path:
            return
        Path(path).write_text(json.dumps([slot.__dict__ for slot in self.workspace], indent=2), encoding="utf-8")
        self.status_var.set(f"Exported {Path(path).name}")

    def refresh_catalog(self) -> None:
        self.catalog = read_catalog()
        self.packs = self.catalog.get("packs", [])
        self.populate_packs()
        self.select_pack(0)
        self.status_var.set("Catalog refreshed.")

    def reset_workspace(self) -> None:
        if not messagebox.askyesno("Reset Workspace", "Reset all staged workspace slots?"):
            return
        self.workspace = initial_workspace()
        self.populate_workspace()
        self.status_var.set("Workspace reset.")


if __name__ == "__main__":
    try:
        app = Workbench()
        app.mainloop()
    except Exception as exc:
        log_path = Path("/tmp/voiceliveplay-workbench.log")
        log_path.write_text(traceback.format_exc(), encoding="utf-8")
        root = tk.Tk()
        root.withdraw()
        messagebox.showerror("VoiceLive Play Workbench failed", f"{exc}\n\nLog written to:\n{log_path}")
        raise
