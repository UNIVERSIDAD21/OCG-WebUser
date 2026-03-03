import { spawn } from 'node:child_process';

const run = (name, command, args) => {
  const child = spawn(command, args, {
    shell: true,
    stdio: 'inherit',
    env: process.env,
  });

  child.on('exit', (code) => {
    if (code && code !== 0) {
      console.error(`[${name}] terminó con código ${code}`);
      process.exit(code);
    }
  });

  return child;
};

const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';

const api = run('dev:api', npmCmd, ['run', 'dev:api']);
const web = run('dev:web', npmCmd, ['run', 'dev:web']);

const shutdown = () => {
  api.kill();
  web.kill();
  process.exit(0);
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
