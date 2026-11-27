const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const generated = path.join(__dirname, '.generated');
fs.mkdirSync(generated, { recursive: true });
for (const name of ['firestore.rules', 'storage.rules']) {
  fs.copyFileSync(path.join(root, name), path.join(generated, name));
}
fs.copyFileSync(path.join(__dirname, 'permissions.cjs'), path.join(generated, 'permissions.cjs'));
const config = {
  firestore: { rules: 'firestore.rules' },
  storage: { rules: 'storage.rules' },
  emulators: {
    firestore: { host: '127.0.0.1', port: 8085 },
    storage: { host: '127.0.0.1', port: 9198 },
    hub: { host: '127.0.0.1', port: 4466 },
    logging: { host: '127.0.0.1', port: 4468 },
    ui: { enabled: false }, singleProjectMode: true,
  },
};
const configPath = path.join(generated, 'firebase.json');
fs.writeFileSync(configPath, JSON.stringify(config));
const command = '"' + process.execPath + '" "' + path.join(generated, 'permissions.cjs') + '"';
const cli = require.resolve('firebase-tools/lib/bin/firebase.js');
const result = spawnSync(process.execPath, [cli, 'emulators:exec', '--project',
  'demo-rochy-security', '--config', configPath, '--only', 'firestore,storage',
  '--non-interactive', command], { cwd: root, stdio: 'inherit', windowsHide: true });
if (result.error) console.error(result.error.message);
process.exitCode = result.status ?? 1;
