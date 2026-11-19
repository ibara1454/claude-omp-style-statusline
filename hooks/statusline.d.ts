export function formatPath(cwd: string, home: string): string
export function parseStatus(porcelain: string): string[]
/** Returns consecutive text, foreground, background triples (empty background is transparent). */
export function renderRow(columns: number, model: string, path: string, git: string[], percent: number, window: number, costUsd: number): string[]
