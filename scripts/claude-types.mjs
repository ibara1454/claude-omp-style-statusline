import { hash } from 'node:crypto'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'

const version = '2.1.332'
const sha256 = 'b89f24fde1dd1ddfd08a5355a0cf1d1b8bbc25e9f7474c697fbe4d89dbb93c31'
const cache = new URL('../node_modules/.cache/claude-code/index.d.ts', import.meta.url)
const matches = (bytes) => hash('sha256', bytes, 'hex') === sha256

if (!existsSync(cache) || !matches(readFileSync(cache))) {
  const response = await fetch(`https://raw.githubusercontent.com/anthropics/claude-code/v${version}/mods/types/claude-code.d.ts`)
  if (!response.ok) throw new Error(`Claude Code ${version} type download failed: HTTP ${response.status}`)

  const bytes = Buffer.from(await response.arrayBuffer())
  if (!matches(bytes)) throw new Error(`Claude Code ${version} type download failed: SHA-256 mismatch`)
  mkdirSync(new URL('.', cache), { recursive: true })
  writeFileSync(cache, bytes)
}
