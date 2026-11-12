// Checks every .claude/rules markdown file (features/ included) for paths frontmatter, matching globs, size, provenance, em dashes and required headings; prints one problem per line and exits 1 if any.
import { globSync, readdirSync, readFileSync, statSync } from 'node:fs'
import { basename, join, relative, sep } from 'node:path'

const MAX_RULES_BYTES = 4096
const EM_DASH = String.fromCodePoint(0x2014)
const SKIPPED_DIRS = /(^|\/)(node_modules|\.git)$/
const REPO_RULES_FILES = ['backend.md', 'spinquest-frontend.md', 'mobile-app.md', 'rips-frontend.md', 'central-tech.md']
const REPO_HEADINGS = ['## Verify ladder', '## Conventions (observed)', '## Hard rules']
const REVIEW_PROVENANCE = /^Derived from PR reviews \d{4}-\d{2}-\d{2} to \d{4}-\d{2}-\d{2}/m
const DOSSIER_PROVENANCE = /^Derived from the personal-docs dossiers on \d{4}-\d{2}-\d{2}\.$/m
const FEATURE_PROVENANCE = /^Distilled on \d{4}-\d{2}-\d{2} from personal-docs\//m

function listMarkdownFiles(directory) {
  return readdirSync(directory).flatMap((entryName) => {
    const entryPath = join(directory, entryName)
    if (statSync(entryPath).isDirectory()) return listMarkdownFiles(entryPath)
    return entryName.endsWith('.md') ? [entryPath] : []
  })
}

function readPathGlobs(markdownText) {
  const frontmatter = markdownText.match(/^---\n([\s\S]*?)\n---\n/)
  if (!frontmatter) return []
  const pathsBlock = frontmatter[1].match(/^paths:\n((?:[ \t]+-.*\n?)+)/m)
  if (!pathsBlock) return []
  return [...pathsBlock[1].matchAll(/^[ \t]+-[ \t]*["']?([^"'\n]+?)["']?[ \t]*$/gm)].map(([, glob]) => glob)
}

function isGlobMatched(glob, workspaceRoot) {
  const exclude = (candidate) => SKIPPED_DIRS.test(typeof candidate === 'string' ? candidate : candidate.name)
  return globSync(glob, { cwd: workspaceRoot, exclude }).length > 0
}

function selectProvenancePattern(filePath, rulesDir) {
  const relativePath = relative(rulesDir, filePath)
  if (relativePath.startsWith(`features${sep}`)) return FEATURE_PROVENANCE
  return basename(filePath) === 'personal-docs.md' ? DOSSIER_PROVENANCE : REVIEW_PROVENANCE
}

function findMissingHeadings(filePath, markdownText, rulesDir) {
  const isRepoFile = relative(rulesDir, filePath) === basename(filePath) && REPO_RULES_FILES.includes(basename(filePath))
  if (!isRepoFile) return []
  const headingLines = new Set(markdownText.split('\n').map((line) => line.trimEnd()))
  return REPO_HEADINGS.filter((heading) => !headingLines.has(heading))
}

export function findRulesProblems(rulesDir, workspaceRoot) {
  const problems = []
  for (const filePath of listMarkdownFiles(rulesDir)) {
    const markdownText = readFileSync(filePath, 'utf8')
    const globs = readPathGlobs(markdownText)
    if (globs.length === 0) problems.push(`NO_PATHS ${filePath}`)
    for (const glob of globs) if (!isGlobMatched(glob, workspaceRoot)) problems.push(`GLOB_NO_MATCH ${filePath} ${glob}`)
    const byteCount = Buffer.byteLength(markdownText, 'utf8')
    if (byteCount > MAX_RULES_BYTES) problems.push(`TOO_LARGE ${filePath} ${byteCount}`)
    if (!selectProvenancePattern(filePath, rulesDir).test(markdownText)) problems.push(`NO_PROVENANCE ${filePath}`)
    if (markdownText.includes(EM_DASH)) problems.push(`EM_DASH ${filePath}`)
    for (const heading of findMissingHeadings(filePath, markdownText, rulesDir)) problems.push(`MISSING_HEADING ${filePath} ${heading}`)
  }
  return problems
}

const [rulesDir, workspaceRoot] = process.argv.slice(2)
if (!rulesDir || !workspaceRoot) {
  console.error('usage: node checkRules.mjs <rulesDir> <workspaceRoot>')
  process.exit(2)
}
const problems = findRulesProblems(rulesDir, workspaceRoot)
for (const problem of problems) console.log(problem)
process.exit(problems.length > 0 ? 1 : 0)
