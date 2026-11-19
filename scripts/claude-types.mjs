const version = '2.1.328'
const sha256 = '2844f0e5e0886272ad3736e5282d3c4a9f7a9296d0d7ccb823451aa9dbe7365b'
const cache = Bun.file(new URL('../node_modules/.cache/claude-code/index.d.ts', import.meta.url))
const matches = (bytes) => Bun.CryptoHasher.hash('sha256', bytes, 'hex') === sha256

if (!(await cache.exists()) || !matches(await cache.arrayBuffer())) {
  const response = await fetch(`https://raw.githubusercontent.com/anthropics/claude-code/v${version}/mods/types/claude-code.d.ts`)
  if (!response.ok) throw new Error(`Claude Code ${version} type download failed: HTTP ${response.status}`)

  const bytes = await response.arrayBuffer()
  if (!matches(bytes)) throw new Error(`Claude Code ${version} type download failed: SHA-256 mismatch`)
  await Bun.write(cache, bytes)
}
