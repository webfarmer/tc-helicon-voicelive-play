import {
  Archive,
  Download,
  FileSearch,
  FolderOpen,
  HardDrive,
  Lock,
  RefreshCcw,
  Search,
  ShieldAlert,
  Upload,
} from 'lucide-react'
import { type DragEvent, useEffect, useMemo, useState } from 'react'
import catalogJson from './data/generated/voiceSupportCatalog.json'
import './App.css'

type VoiceSupportPack = (typeof catalogJson.packs)[number]

type WorkspaceSlot = {
  id: number
  name: string
  source?: string
  dirty?: boolean
}

const workspaceStorageKey = 'voiceliveplay2.workspace.v1'

const initialSlots: WorkspaceSlot[] = Array.from({ length: 500 }, (_, index) => ({
  id: index + 1,
  name:
    index === 0
      ? 'PAUL PRESENT'
      : index === 1
        ? 'MEGAPHONE'
        : index === 2
          ? 'GORGEOUS HALL'
          : index === 3
            ? 'PONG PAUL'
            : 'BLANK PRESET',
}))

const tagLabels = [
  'Favorite',
  'Showcase',
  'Songs',
  'Pop',
  'Rock',
  'Alternative',
  'Country',
  'Echo',
  'Doubling',
  'Reverb',
  'Harmony',
  'HardTune',
  'Megaphone',
]

function App() {
  const packs = catalogJson.packs
  const [query, setQuery] = useState('')
  const [selectedPackTitle, setSelectedPackTitle] = useState('Modern Rock Pack')
  const [selectedSlotId, setSelectedSlotId] = useState(1)
  const [workspace, setWorkspace] = useState(readStoredWorkspace)

  useEffect(() => {
    window.localStorage.setItem(workspaceStorageKey, JSON.stringify(workspace))
  }, [workspace])

  const filteredPacks = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase()

    if (!normalizedQuery) return packs

    return packs.filter((pack) =>
      [pack.title, pack.description, ...pack.firstPresetNames]
        .join(' ')
        .toLowerCase()
        .includes(normalizedQuery),
    )
  }, [packs, query])

  const selectedPack =
    packs.find((pack) => pack.title === selectedPackTitle) ?? packs[0]
  const selectedSlot =
    workspace.find((slot) => slot.id === selectedSlotId) ?? workspace[0]
  const filledSlots = workspace.filter((slot) => slot.name !== 'BLANK PRESET')

  function selectPack(pack: VoiceSupportPack) {
    setSelectedPackTitle(pack.title)
  }

  const selectedPackPresets = selectedPack.presetNames

  function resetWorkspace() {
    setWorkspace(initialSlots)
    setSelectedSlotId(1)
  }

  function stagePreset(name: string, targetSlotId = selectedSlotId) {
    setWorkspace((slots) =>
      slots.map((slot) =>
        slot.id === targetSlotId
          ? {
              ...slot,
              name,
              source: selectedPack.title,
              dirty: true,
            }
          : slot,
      ),
    )
    setSelectedSlotId(targetSlotId)
  }

  function startPresetDrag(event: DragEvent<HTMLButtonElement>, name: string) {
    event.dataTransfer.setData('application/x-voicelive-preset', name)
    event.dataTransfer.effectAllowed = 'copy'
  }

  function dropPresetOnSlot(event: DragEvent<HTMLButtonElement>, slotId: number) {
    event.preventDefault()
    const name =
      event.dataTransfer.getData('application/x-voicelive-preset') ||
      event.dataTransfer.getData('text/plain')

    if (name) {
      stagePreset(name, slotId)
    }
  }

  return (
    <main className="app-shell">
      <aside className="sidebar" aria-label="Workbench sections">
        <div className="brand">
          <div className="brand-mark">VL</div>
          <div>
            <h1>VoiceLive Play Workbench</h1>
            <p>Local preset librarian</p>
          </div>
        </div>

        <nav className="section-nav">
          <button className="section-item active" type="button">
            <HardDrive size={17} />
            Device
          </button>
          <button className="section-item" type="button">
            <FolderOpen size={17} />
            Local Packs
          </button>
          <button className="section-item" type="button">
            <FileSearch size={17} />
            Captures
          </button>
          <button className="section-item caution" type="button">
            <Lock size={17} />
            Safety
          </button>
        </nav>

        <div className="device-card">
          <span className="device-dot" />
          <strong>VoiceLive Play</strong>
          <span>Firmware 1.5.00 build 74</span>
        </div>
      </aside>

      <section className="workbench">
        <header className="toolbar">
          <div className="toolbar-left">
            <button
              className="icon-button"
              type="button"
              aria-label="Reset workspace"
              onClick={resetWorkspace}
            >
              <RefreshCcw size={17} />
            </button>
            <button className="icon-button" type="button" aria-label="Import archive">
              <Download size={17} />
            </button>
            <button className="icon-button" type="button" aria-label="Export selection">
              <Upload size={17} />
            </button>
            <div className="locked-status">
              <Lock size={15} />
              Device writes locked
            </div>
          </div>

          <label className="search-field">
            <Search size={16} />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search packs or presets"
            />
          </label>
        </header>

        <div className="summary-strip">
          <Metric label="Local packs" value={packs.length.toString()} />
          <Metric label="Parsed presets" value={sum(packs, 'presetCount').toString()} />
          <Metric label="SysEx blocks" value={sum(packs, 'sysexBlockCount').toString()} />
          <Metric label="Workspace" value="500 slots" />
        </div>

        <div className="main-grid">
          <section className="pack-pane" aria-label="Local pack browser">
            <div className="pane-title">
              <Archive size={17} />
              <span>Local pack browser</span>
            </div>

            <div className="pack-table" role="list">
              {filteredPacks.map((pack) => (
                <button
                  className={`pack-row ${
                    pack.title === selectedPack.title ? 'selected' : ''
                  }`}
                  key={pack.uuid}
                  onClick={() => selectPack(pack)}
                  type="button"
                  role="listitem"
                >
                  <span className="pack-name">{pack.title}</span>
                  <span>{pack.presetCount} presets</span>
                  <span>PID {pack.productSysexId}</span>
                </button>
              ))}
            </div>
          </section>

          <section className="workspace-pane" aria-label="500-slot workspace">
            <div className="pane-title">
              <HardDrive size={17} />
              <span>500-slot workspace</span>
              <small>{filledSlots.length} occupied</small>
            </div>

            <div className="slot-grid">
              {workspace.map((slot) => (
                <button
                  className={`slot-cell ${
                    slot.id === selectedSlot.id ? 'selected' : ''
                  } ${slot.dirty ? 'dirty' : ''}`}
                  key={slot.id}
                  onClick={() => setSelectedSlotId(slot.id)}
                  onDragOver={(event) => event.preventDefault()}
                  onDrop={(event) => dropPresetOnSlot(event, slot.id)}
                  type="button"
                >
                  <span>{slot.id}</span>
                  <strong>{slot.name}</strong>
                </button>
              ))}
            </div>
          </section>
        </div>

        <section className="inspector" aria-label="Preset and archive inspector">
          <div className="inspector-section">
            <h2>{selectedPack.title}</h2>
            <p>{selectedPack.description}</p>
            <div className="preset-list">
              {selectedPackPresets.map((name) => (
                <button
                  draggable
                  key={name}
                  type="button"
                  onClick={() => stagePreset(name)}
                  onDragStart={(event) => startPresetDrag(event, name)}
                >
                  {name}
                </button>
              ))}
            </div>
          </div>

          <div className="inspector-section">
            <h2>Selected slot {selectedSlot.id}</h2>
            <dl className="details">
              <div>
                <dt>Preset name</dt>
                <dd aria-label="Selected preset name">{selectedSlot.name}</dd>
              </div>
              <div>
                <dt>Source</dt>
                <dd aria-label="Selected preset source">
                  {selectedSlot.source ?? 'Device workspace'}
                </dd>
              </div>
              <div>
                <dt>Raw evidence</dt>
                <dd>{selectedPack.sysexBlockCount} SysEx blocks parsed</dd>
              </div>
            </dl>
            <div className="tags">
              {tagLabels.map((tag) => (
                <span key={tag}>{tag}</span>
              ))}
            </div>
          </div>

          <div className="safety-panel">
            <ShieldAlert size={19} />
            <div>
              <strong>Read-only compatibility mode</strong>
              <span>
                This draft can inspect and stage data locally. It cannot write to the
                VoiceLive Play until device-transfer behavior is verified.
              </span>
            </div>
          </div>
        </section>
      </section>
    </main>
  )
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  )
}

function sum(packs: VoiceSupportPack[], key: 'presetCount' | 'sysexBlockCount') {
  return packs.reduce((total, pack) => total + pack[key], 0)
}

function readStoredWorkspace() {
  try {
    const storedWorkspace = window.localStorage.getItem(workspaceStorageKey)
    if (!storedWorkspace) return initialSlots

    const parsed = JSON.parse(storedWorkspace) as WorkspaceSlot[]

    if (!Array.isArray(parsed) || parsed.length !== initialSlots.length) {
      return initialSlots
    }

    return parsed.map((slot, index) => ({
      id: Number(slot.id) || index + 1,
      name: typeof slot.name === 'string' ? slot.name : initialSlots[index].name,
      source: typeof slot.source === 'string' ? slot.source : undefined,
      dirty: Boolean(slot.dirty),
    }))
  } catch {
    return initialSlots
  }
}

export default App
