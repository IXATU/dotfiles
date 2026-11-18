// Read metadata only: never require code from a candidate installation.
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');
const [mode, root, expected, npm] = process.argv.slice(2);
const name = '@wonderwhy-er/desktop-commander';
const key = `node_modules/${name}`;
const stable = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const check = (condition) => { if (!condition) throw new Error('validation'); };
try {
  if (mode === 'url') {
    const url = new URL(root);
    check(url.protocol === 'http:' && ['127.0.0.1', '[::1]'].includes(url.hostname));
    check(!url.username && !url.password && !url.search && !url.hash);
  } else if (mode === 'paths') {
    // All ancestors down from HOME must be owned, real directories, not writable by others.
    const home = path.resolve(process.env.HOME);
    check(home === process.env.HOME && fs.realpathSync(home) === home);
    for (const target of [home, root, expected]) {
      check(target === home || target.startsWith(home + '/'));
      let current = target;
      while (current.startsWith(home)) {
        const st = fs.lstatSync(current);
        check(st.isDirectory() && st.uid === process.getuid() && !(st.mode & 0o022));
        if (current === home) break;
        current = path.dirname(current);
      }
    }
  } else {
    const metadata = path.join(root, key, 'package.json');
    check(fs.realpathSync(metadata).startsWith(root + '/'));
    const pkg = read(metadata);
    check(stable.test(pkg.version));
    if (mode === 'version') {
      console.log(pkg.version);
    } else {
      check(mode === 'stage' && stable.test(expected) && pkg.name === name && pkg.version === expected);
      const semver = createRequire(fs.realpathSync(npm))('semver');
      const manifest = read(path.join(root, 'package.json'));
      check(manifest.dependencies[name] === expected);
      const main = path.resolve(root, key, pkg.main);
      check(main.startsWith(path.join(root, key) + '/') && fs.statSync(main).isFile());
      const lock = read(path.join(root, 'package-lock.json'));
      const hidden = read(path.join(root, 'node_modules/.package-lock.json'));
      const entry = lock.packages[key];
      check(lock.lockfileVersion >= 2 && entry.version === expected);
      check(lock.packages[''].dependencies[name] === expected);
      check(typeof entry.integrity === 'string' && /^sha512-[A-Za-z0-9+/]{86}==$/.test(entry.integrity));
      check(Buffer.from(entry.integrity.slice(7), 'base64').length === 64);
      check(Buffer.from(entry.integrity.slice(7), 'base64').toString('base64') === entry.integrity.slice(7));
      check(hidden.packages[key].version === expected && hidden.packages[key].integrity === entry.integrity);
      if (pkg._integrity) check(pkg._integrity === entry.integrity);
      check(typeof pkg.engines?.node === 'string' && semver.satisfies(process.version, pkg.engines.node));
      for (const dependency of Object.values(lock.packages)) {
        if (dependency.engines?.node) check(semver.satisfies(process.version, dependency.engines.node));
      }
      const walk = dir => {
        for (const item of fs.readdirSync(dir)) {
          const file = path.join(dir, item);
          const st = fs.lstatSync(file);
          check(st.uid === process.getuid());
          if (st.isSymbolicLink()) {
            const dest = fs.realpathSync(file);
            check(dest.startsWith(root + '/'));
          } else {
            check(!(st.mode & 0o022));
            check(st.isDirectory() || (st.isFile() && st.nlink === 1));
            if (st.isDirectory()) walk(file);
          }
        }
      };
      walk(root);
      check(fs.statSync(root).dev === fs.statSync(path.dirname(path.dirname(root))).dev);
    }
  }
} catch {
  console.error('ERROR: metadata, paths, integrity, URL or Node compatibility validation failed');
  process.exitCode = 1;
}
