import { XMLParser } from 'fast-xml-parser'
import { promises as fs } from 'node:fs'
import path from 'node:path'

export type PackMetadata = {
  title: string
  description: string
  productSysexId: number
  buildNo: number
  archiveVersion: number
  uuid: string
  md5: string
  linkImage?: string
  linkData: string
  xmlFile: string
}

export type SysexBlock = {
  offset: number
  length: number
  command?: number
}

export type TchArchive = {
  file: string
  size: number
  archiveVersion: string
  productName: string
  payloadVersion: string
  presetNames: string[]
  sysexBlocks: SysexBlock[]
}

export type VoiceSupportPack = PackMetadata & {
  tchFile: string
  presetCount: number
  sysexBlockCount: number
  presetNames: string[]
  firstPresetNames: string[]
}

type ArchiveXml = {
  ARCHIVE?: {
    uuid?: string
    md5?: string
    arVersion?: number | string
    product?: {
      sysexId?: number | string
    }
    buildNo?: number | string
    title?: string
    description?: string
    linkImage?: string
    linkData?: string
  }
}

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
  parseAttributeValue: true,
  parseTagValue: true,
  trimValues: true,
})

export async function parsePackMetadataXml(xmlFile: string): Promise<PackMetadata> {
  const xml = await fs.readFile(xmlFile, 'utf8')
  const parsed = xmlParser.parse(xml) as ArchiveXml
  const archive = parsed.ARCHIVE

  if (!archive) {
    throw new Error(`Missing ARCHIVE root in ${xmlFile}`)
  }

  const title = requiredString(archive.title, 'title', xmlFile)
  const linkData = requiredString(archive.linkData, 'linkData', xmlFile)

  return {
    title,
    description: String(archive.description ?? ''),
    productSysexId: Number(archive.product?.sysexId ?? 0),
    buildNo: Number(archive.buildNo ?? 0),
    archiveVersion: Number(archive.arVersion ?? 0),
    uuid: String(archive.uuid ?? ''),
    md5: String(archive.md5 ?? ''),
    linkImage: archive.linkImage ? String(archive.linkImage) : undefined,
    linkData,
    xmlFile,
  }
}

export async function parseTchArchive(tchFile: string): Promise<TchArchive> {
  const buffer = await fs.readFile(tchFile)
  const header = readNullTerminatedStrings(buffer, 0, 3)

  return {
    file: tchFile,
    size: buffer.length,
    archiveVersion: header[0] ?? '',
    productName: header[1] ?? '',
    payloadVersion: header[2] ?? '',
    presetNames: extractPresetNames(buffer),
    sysexBlocks: extractSysexBlocks(buffer),
  }
}

export async function scanVoiceSupportPacks(
  packsDir: string,
): Promise<VoiceSupportPack[]> {
  const entries = await fs.readdir(packsDir, { withFileTypes: true })
  const xmlFiles = entries
    .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith('.xml'))
    .map((entry) => path.join(packsDir, entry.name))
    .sort((a, b) => a.localeCompare(b))

  const packs: VoiceSupportPack[] = []

  for (const xmlFile of xmlFiles) {
    const metadata = await parsePackMetadataXml(xmlFile)
    const tchFile = await resolveTchFile(packsDir, metadata.linkData)

    try {
      const archive = await parseTchArchive(tchFile)
      packs.push({
        ...metadata,
        tchFile,
        presetCount: archive.presetNames.length,
        sysexBlockCount: archive.sysexBlocks.length,
        presetNames: archive.presetNames,
        firstPresetNames: archive.presetNames.slice(0, 8),
      })
    } catch {
      packs.push({
        ...metadata,
        tchFile,
        presetCount: 0,
        sysexBlockCount: 0,
        presetNames: [],
        firstPresetNames: [],
      })
    }
  }

  return packs
}

function readNullTerminatedStrings(
  buffer: Buffer,
  start: number,
  count: number,
): string[] {
  const values: string[] = []
  let cursor = start

  while (cursor < buffer.length && values.length < count) {
    const terminator = buffer.indexOf(0, cursor)
    if (terminator === -1) break

    values.push(buffer.subarray(cursor, terminator).toString('ascii'))
    cursor = terminator + 1
  }

  return values
}

function extractPresetNames(buffer: Buffer): string[] {
  const marker = Buffer.from([0xaa, 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00])
  const names: string[] = []
  let cursor = 0

  while (cursor < buffer.length) {
    const markerOffset = buffer.indexOf(marker, cursor)
    if (markerOffset === -1) break

    const nameStart = markerOffset + marker.length
    const name = cleanPresetName(buffer.subarray(nameStart, nameStart + 15))

    if (name && !names.includes(name)) {
      names.push(name)
    }

    cursor = nameStart + 15
  }

  return names
}

function extractSysexBlocks(buffer: Buffer): SysexBlock[] {
  const blocks: SysexBlock[] = []
  let cursor = 0

  while (cursor < buffer.length) {
    const start = buffer.indexOf(0xf0, cursor)
    if (start === -1) break

    const end = buffer.indexOf(0xf7, start + 1)
    if (end === -1) break

    const command = buffer[start + 6]
    blocks.push({
      offset: start,
      length: end - start + 1,
      command,
    })

    cursor = end + 1
  }

  return blocks
}

function cleanPresetName(bytes: Buffer): string {
  const rawName = bytes.toString('ascii')
  const nullOffset = rawName.indexOf(String.fromCharCode(0))

  return (nullOffset === -1 ? rawName : rawName.slice(0, nullOffset)).trim()
}

async function resolveTchFile(packsDir: string, linkData: string): Promise<string> {
  const candidates = [
    linkData,
    linkData.replaceAll("'", '_'),
    linkData.replaceAll('’', '_'),
  ]

  for (const candidate of candidates) {
    const candidatePath = path.join(packsDir, candidate)

    try {
      await fs.access(candidatePath)
      return candidatePath
    } catch {
      // Keep looking for recovered offline filenames.
    }
  }

  return path.join(packsDir, linkData)
}

function requiredString(
  value: unknown,
  field: string,
  source: string,
): string {
  if (typeof value === 'string' && value.length > 0) {
    return value
  }

  throw new Error(`Missing ${field} in ${source}`)
}
