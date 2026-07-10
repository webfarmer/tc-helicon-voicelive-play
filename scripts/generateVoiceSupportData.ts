import { mkdir, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { scanVoiceSupportPacks } from '../src/lib/voiceSupportParser'

const defaultPacksDir = path.join(
  process.env.HOME ?? '',
  'Library/Application Support/TC-Helicon/VoiceSupport 2/VoiceLive Play/packs',
)

const packsDir = process.env.VOICESUPPORT_PACKS_DIR ?? defaultPacksDir
const outputFile = path.join(
  process.cwd(),
  'src/data/generated/voiceSupportCatalog.json',
)

const catalog = await scanVoiceSupportPacks(packsDir)

await mkdir(path.dirname(outputFile), { recursive: true })
await writeFile(
  outputFile,
  `${JSON.stringify(
    {
      generatedAt: new Date().toISOString(),
      source: packsDir,
      packs: catalog,
    },
    null,
    2,
  )}\n`,
)

console.log(`Wrote ${catalog.length} packs to ${outputFile}`)
