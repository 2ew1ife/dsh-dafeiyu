#!/usr/bin/env node
// Local selector for QCYTSN/dsh-dafeiyu's optional custom macOS skin support.
// Does not build the helper, stop DSH, or access any credentials.
import { copyFileSync, existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const args = process.argv.slice(2)
if (args.some((arg) => arg !== '--dry-run')) {
  throw new Error('Usage: node install-skin.mjs [--dry-run]')
}
const source = join(dirname(fileURLToPath(import.meta.url)), 'images')
const dshHome = resolve(process.env.DSH_HOME || join(homedir(), '.dsh'))
const directory = join(dshHome, 'dsh-dafeiyu')
const target = join(directory, 'skins', 'kurumi')
const selectionPath = join(directory, 'skin.json')
const names = ['idle', 'idle-blink', 'thought', 'working', 'happy', 'dragging']
const images = Object.fromEntries(names.map((name) => [name, join(target, `${name}.png`)]))

// Validate all inputs before creating any user-directory files.
for (const name of names) {
  const bytes = readFileSync(join(source, `${name}.png`))
  if (bytes.length < 8 || !bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
    throw new Error(`Invalid PNG: ${name}.png`)
  }
}
const selection = {
  imagePath: images.idle,
  name: '时崎狂三',
  states: {
    IDLE: images.idle,
    THINKING: images.thought,
    WORKING: images.working,
    SUCCESS: images.happy,
    WAITING: images.thought,
    ERROR: images.thought,
  },
  interactionImagePath: images.happy,
  draggingImagePath: images.dragging,
  blinkImagePath: images['idle-blink'],
}
if (args.includes('--dry-run')) {
  console.log(JSON.stringify({ dryRun: true, selectionPath, imageDirectory: target, selection }, null, 2))
} else {
  mkdirSync(target, { recursive: true, mode: 0o700 })
  for (const name of names) {
    const temporary = `${images[name]}.tmp-${process.pid}`
    copyFileSync(join(source, `${name}.png`), temporary)
    renameSync(temporary, images[name])
  }
  if (existsSync(selectionPath)) {
    const stamp = new Date().toISOString().replace(/[:.]/g, '-')
    copyFileSync(selectionPath, `${selectionPath}.backup-${stamp}`)
  }
  const temporary = `${selectionPath}.tmp-${process.pid}`
  writeFileSync(temporary, JSON.stringify(selection, null, 2) + '\n', { mode: 0o600 })
  renameSync(temporary, selectionPath)
  console.log(`Kurumi skin selected: ${selectionPath}`)
  console.log('Restart the DSH Host with this branch’s custom-skin macOS Helper to apply it.')
}
