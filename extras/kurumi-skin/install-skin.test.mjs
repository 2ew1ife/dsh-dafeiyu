import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const installer = join(dirname(fileURLToPath(import.meta.url)), 'install-skin.mjs')

test('dry-run does not create the selected DSH directory', () => {
  const temporary = mkdtempSync(join(tmpdir(), 'kurumi-skin-dryrun-'))
  try {
    const dshHome = join(temporary, 'dsh')
    const result = JSON.parse(execFileSync(process.execPath, [installer, '--dry-run'], {
      env: { ...process.env, DSH_HOME: dshHome }, encoding: 'utf8',
    }))
    assert.equal(result.dryRun, true)
    assert.equal(existsSync(dshHome), false)
    assert.equal(result.selection.imagePath, join(dshHome, 'dsh-dafeiyu', 'skins', 'kurumi', 'idle.png'))
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})

test('installation preserves the prior selection and only writes the skin subtree', () => {
  const temporary = mkdtempSync(join(tmpdir(), 'kurumi-skin-install-'))
  try {
    const directory = join(temporary, 'dsh-dafeiyu')
    mkdirSync(directory)
    const original = '{"name":"previous custom skin"}\n'
    writeFileSync(join(directory, 'skin.json'), original)
    writeFileSync(join(temporary, 'unrelated-marker'), 'untouched')
    execFileSync(process.execPath, [installer], { env: { ...process.env, DSH_HOME: temporary } })
    const selection = JSON.parse(readFileSync(join(directory, 'skin.json'), 'utf8'))
    assert.equal(selection.name, '时崎狂三')
    for (const path of [...Object.values(selection.states), selection.interactionImagePath, selection.draggingImagePath, selection.blinkImagePath]) {
      assert.ok(path.startsWith(join(directory, 'skins', 'kurumi') + '/'))
      assert.ok(existsSync(path))
    }
    const backups = readdirSync(directory).filter((name) => name.startsWith('skin.json.backup-'))
    assert.equal(backups.length, 1)
    assert.equal(readFileSync(join(directory, backups[0]), 'utf8'), original)
    assert.equal(readFileSync(join(temporary, 'unrelated-marker'), 'utf8'), 'untouched')
    assert.deepEqual(readdirSync(temporary).sort(), ['dsh-dafeiyu', 'unrelated-marker'])
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})
