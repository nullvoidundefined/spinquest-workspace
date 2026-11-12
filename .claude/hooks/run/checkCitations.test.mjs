// Tests for findCitationProblems: header detection, missing files, out-of-range lines, and skipped citation shapes.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'
import { findCitationProblems } from './checkCitations.mjs'

const here = dirname(fileURLToPath(import.meta.url))
const workspaceRoot = resolve(here, '../../..')
const fixture = (name) => readFileSync(resolve(here, '../fixtures/citation-check/personal-docs', name), 'utf8')
const header = 'Read from source on 2026-11-11 against `master`.\n\n'

test('good doc with header yields no problems', () => {
  assert.deepEqual(findCitationProblems(fixture('good.md'), workspaceRoot), [])
})

test('bad doc reports the missing file', () => {
  assert.deepEqual(findCitationProblems(fixture('bad.md'), workspaceRoot), ['MISSING Backend/nope.ts'])
})

test('line beyond end of file is out of range', () => {
  const problems = findCitationProblems(`${header}See \`Backend/package.json:999999\`.\n`, workspaceRoot)
  assert.equal(problems.length, 1)
  assert.match(problems[0], /^OUT_OF_RANGE Backend\/package\.json:999999 \(file has \d+ lines\)$/)
})

test('doc without header reports NO_HEADER', () => {
  assert.deepEqual(findCitationProblems('See `Backend/package.json:1`.\n', workspaceRoot), ['NO_HEADER'])
})

test('line range inside the file is valid', () => {
  assert.deepEqual(findCitationProblems(`${header}\`Backend/package.json:1-2\`\n`, workspaceRoot), [])
})

test('range ending past the file is out of range', () => {
  const problems = findCitationProblems(`${header}\`Backend/package.json:1-999999\`\n`, workspaceRoot)
  assert.equal(problems.length, 1)
  assert.match(problems[0], /^OUT_OF_RANGE /)
})

test('bare filename citation is skipped', () => {
  assert.deepEqual(findCitationProblems(`${header}\`package.json:999\`\n`, workspaceRoot), [])
})

test(':line shorthand is skipped', () => {
  assert.deepEqual(findCitationProblems(`${header}see \`:42\` and \`src/x.ts:9\`\n`, workspaceRoot), [])
})

test('sha-form source statement on line 9 satisfies the header', () => {
  const text = `${'\n'.repeat(8)}Mobile references are to \`master\` at \`fce425f0\` (2026-11-10).\n\`Backend/package.json:1\`\n`
  assert.deepEqual(findCitationProblems(text, workspaceRoot), [])
})

test('header beyond line 25 does not count', () => {
  const text = `${'\n'.repeat(30)}at \`fce425f0\`\n`
  assert.deepEqual(findCitationProblems(text, workspaceRoot), ['NO_HEADER'])
})

test('personal-docs citations resolve against the workspace root', () => {
  assert.deepEqual(findCitationProblems(`${header}\`personal-docs/nope.md:1\`\n`, workspaceRoot), ['MISSING personal-docs/nope.md'])
})

const cliPath = resolve(here, 'checkCitations.mjs')
const badDocPath = resolve(here, '../fixtures/citation-check/personal-docs/bad.md')

test('CLI without --root resolves against the script workspace regardless of cwd', () => {
  const result = spawnSync('node', [cliPath, badDocPath], { cwd: '/', encoding: 'utf8' })
  assert.equal(result.status, 0)
  assert.equal(result.stdout.trim(), 'MISSING Backend/nope.ts')
})

test('CLI with --root resolves against the given root', () => {
  const result = spawnSync('node', [cliPath, badDocPath, '--root', workspaceRoot], { cwd: '/', encoding: 'utf8' })
  assert.equal(result.status, 0)
  assert.equal(result.stdout.trim(), 'MISSING Backend/nope.ts')
})

test('CLI with --root before the doc path still finds the doc', () => {
  const result = spawnSync('node', [cliPath, '--root', workspaceRoot, badDocPath], { encoding: 'utf8' })
  assert.equal(result.stdout.trim(), 'MISSING Backend/nope.ts')
})

test('CLI with an unreadable doc prints one stderr line and exits 0', () => {
  const result = spawnSync('node', [cliPath, '/nonexistent/doc.md'], { encoding: 'utf8' })
  assert.equal(result.status, 0)
  assert.equal(result.stdout, '')
  assert.equal(result.stderr.trim().split('\n').length, 1)
})
