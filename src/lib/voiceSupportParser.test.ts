import { describe, expect, test } from 'vitest'
import path from 'node:path'
import {
  parsePackMetadataXml,
  parseTchArchive,
  scanVoiceSupportPacks,
} from './voiceSupportParser'

const packsDir = path.join(
  process.env.HOME ?? '/Users/paul',
  'Library/Application Support/TC-Helicon/VoiceSupport 2/VoiceLive Play/packs',
)

describe('VoiceSupport pack parsing', () => {
  test('reads pack metadata from the VoiceSupport XML descriptor', async () => {
    const metadata = await parsePackMetadataXml(
      path.join(packsDir, 'Modern Rock Pack.xml'),
    )

    expect(metadata.title).toBe('Modern Rock Pack')
    expect(metadata.productSysexId).toBe(69)
    expect(metadata.buildNo).toBe(65)
    expect(metadata.linkData).toBe('Modern Rock Pack.tch')
    expect(metadata.description).toContain('Modern Rock')
  })

  test('extracts a readable TCH archive header and SysEx block inventory', async () => {
    const archive = await parseTchArchive(
      path.join(packsDir, 'Modern Rock Pack.tch'),
    )

    expect(archive.archiveVersion).toBe('0.1.0.1.132.0')
    expect(archive.productName).toBe('VoiceLive Play')
    expect(archive.payloadVersion).toBe('0.1.3.0.65.28')
    expect(archive.sysexBlocks.length).toBeGreaterThan(10)
    expect(archive.presetNames.slice(0, 3)).toEqual([
      'ADV OF LIFETIME',
      'SOUND & COLOR',
      'FORGOT BRKN HRT',
    ])
  })

  test('scans the local pack folder into a UI catalog', async () => {
    const catalog = await scanVoiceSupportPacks(packsDir)

    expect(catalog.length).toBeGreaterThanOrEqual(30)
    expect(catalog.find((pack) => pack.title === 'Modern Rock Pack')).toEqual(
      expect.objectContaining({
        productSysexId: 69,
        tchFile: expect.stringContaining('Modern Rock Pack.tch'),
        presetCount: expect.any(Number),
        presetNames: expect.arrayContaining(['SOUND & COLOR']),
      }),
    )
    expect(catalog.find((pack) => pack.title === "60's Hits")).toEqual(
      expect.objectContaining({
        presetCount: expect.any(Number),
        sysexBlockCount: expect.any(Number),
        tchFile: expect.stringContaining('60_s Hits.tch'),
      }),
    )
  })
})
