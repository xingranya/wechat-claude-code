#!/usr/bin/env node
// Cross-platform daemon runner
import { spawn } from 'node:child_process';
import { platform } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const p = platform();

const args = process.argv.slice(2);
const action = args[0] || 'start';

if (p === 'win32') {
    const ps = spawn('powershell', ['-ExecutionPolicy', 'Bypass', '-File', join(__dirname, 'daemon.ps1'), action], {
        stdio: 'inherit',
        shell: true
    });
    ps.on('exit', (code) => process.exit(code ?? 0));
} else {
    const sh = spawn('bash', [join(__dirname, 'daemon.sh'), action], {
        stdio: 'inherit'
    });
    sh.on('exit', (code) => process.exit(code ?? 0));
}
