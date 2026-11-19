import { deepEqual } from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'
import { parseStatus } from '../hooks/statusline.js'

test('generated parser counts real Git paths independently, even with spaces and newlines', t => {
  const cwd = mkdtempSync(join(tmpdir(), 'omp-statusline-git-'))
  t.after(() => rmSync(cwd, { force: true, recursive: true }))
  // Inherited Git settings could redirect the test's writes out of this directory.
  const env = { PATH: process.env.PATH, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' }
  const git = (...args) => execFileSync('git', ['--no-optional-locks', ...args], { cwd, env, encoding: 'utf8' })
  const status = () => parseStatus(git('status', '--porcelain=v2', '--branch', '-z', '--untracked-files=all'))
  const write = (name, content) => writeFileSync(join(cwd, name), content)

  git('init', '--quiet', '--template=', '--initial-branch=fixture')
  deepEqual(status(), ['fixture', '', '', ''])

  const questionSource = '? old file\n? not an untracked entry.txt'
  const newlineSource = '\nold file.txt'
  write(questionSource, 'first rename source\n')
  write(newlineSource, 'second rename source\n')
  write('both changed.txt', 'baseline\n')
  write('unstaged only.txt', 'baseline\n')
  git('add', '.')
  git('-c', 'user.name=Statusline Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'baseline')
  git('switch', '--quiet', '--detach')
  deepEqual(status(), ['detached', '', '', ''])
  git('switch', '--quiet', 'fixture')

  git('mv', '--', questionSource, 'renamed file.txt')
  git('mv', '--', newlineSource, 'new file\nname.txt')
  write('both changed.txt', 'staged version\n')
  write('staged only.txt', 'staged addition\n')
  git('add', '--', 'both changed.txt', 'staged only.txt')
  deepEqual(status(), ['fixture', '', '+4', ''])

  write('both changed.txt', 'unstaged version\n')
  write('unstaged only.txt', 'unstaged edit\n')
  write('renamed file.txt', 'unstaged edit to staged rename\n')
  deepEqual(status(), ['fixture', '*3', '+4', ''])

  mkdirSync(join(cwd, 'new directory'))
  write('new directory/untracked one.txt', 'untracked\n')
  write('new directory/untracked two\n? not another record.txt', 'untracked\n')
  deepEqual(status(), ['fixture', '*3', '+4', '?2'])
})
