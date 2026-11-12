// Checks a dossier's file:line citations against the workspace and prints one problem per line (always exits 0).
import { existsSync, readFileSync, statSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const CITED_ROOTS = ['Backend', 'central-tech', 'claude-skills', 'spinquest-frontend', 'spinquest-mobile-app', 'spinquest-rips-frontend', 'personal-docs']
const HEADER_SCAN_LINES = 25
const CITATION_PATTERN = new RegExp(
  `\`((?:${CITED_ROOTS.join('|')})/[^\`\\s:]+\\.[A-Za-z0-9]+):(\\d+(?:-\\d+)?(?:,\\d+(?:-\\d+)?)*)\``,
  'g',
)
const DATED_HEADER_PATTERN = /Read from source on \d{4}-\d{2}-\d{2} against/
const SHA_PATTERN = /`[0-9a-f]{7,40}`/

function hasSourceHeader(markdownText) {
  const headText = markdownText.split('\n').slice(0, HEADER_SCAN_LINES).join('\n')
  return DATED_HEADER_PATTERN.test(headText) || SHA_PATTERN.test(headText)
}

function countLines(filePath) {
  const text = readFileSync(filePath, 'utf8')
  if (text === '') return 0
  return text.endsWith('\n') ? text.split('\n').length - 1 : text.split('\n').length
}

function findHighestLine(lineSpec) {
  return Math.max(...lineSpec.split(/[,-]/).map(Number))
}

export function findCitationProblems(markdownText, workspaceRoot) {
  const problems = []
  if (!hasSourceHeader(markdownText)) problems.push('NO_HEADER')
  const lineCounts = new Map()
  for (const [, citedPath, lineSpec] of markdownText.matchAll(CITATION_PATTERN)) {
    const absolutePath = resolve(workspaceRoot, citedPath)
    if (!existsSync(absolutePath) || !statSync(absolutePath).isFile()) {
      problems.push(`MISSING ${citedPath}`)
      continue
    }
    if (!lineCounts.has(citedPath)) lineCounts.set(citedPath, countLines(absolutePath))
    const lineCount = lineCounts.get(citedPath)
    if (findHighestLine(lineSpec) > lineCount) {
      problems.push(`OUT_OF_RANGE ${citedPath}:${lineSpec} (file has ${lineCount} lines)`)
    }
  }
  return [...new Set(problems)]
}

function runCli(cliArguments) {
  const defaultRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../../..')
  const rootFlagIndex = cliArguments.indexOf('--root')
  const workspaceRoot = rootFlagIndex === -1 ? defaultRoot : resolve(cliArguments[rootFlagIndex + 1] ?? defaultRoot)
  const rootValueIndex = rootFlagIndex === -1 ? -1 : rootFlagIndex + 1
  const docPath = cliArguments.find((argument, index) => !argument.startsWith('--') && index !== rootValueIndex)
  if (!docPath || !existsSync(docPath)) {
    console.error(`checkCitations: cannot read doc ${docPath ?? '(no path given)'}`)
    return
  }
  for (const problem of findCitationProblems(readFileSync(docPath, 'utf8'), workspaceRoot)) console.log(problem)
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) runCli(process.argv.slice(2))
