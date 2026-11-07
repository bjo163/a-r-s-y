import { readdir, readFile, stat } from 'node:fs/promises';
import { dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const ignoredDirs = new Set(['.git', 'node_modules']);
const markdownFiles = [];
async function walk(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!ignoredDirs.has(entry.name)) await walk(join(directory, entry.name));
    } else if (entry.isFile() && extname(entry.name).toLowerCase() === '.md') {
      markdownFiles.push(join(directory, entry.name));
    }
  }
}
const issues = [];
await walk(root);
for (const file of markdownFiles) {
  const source = await readFile(file, 'utf8');
  const links = /!?\\[[^\\]]*\\]\\(([^)]+)\\)/g;
  let match;
  while ((match = links.exec(source))) {
    let destination = match[1].trim().replace(/^<|>$/g, '');
    destination = destination.split(/\\s+["']/)[0];
    if (/^(?:[a-z][a-z0-9+.-]*:|\\/\\/|#)/i.test(destination)) continue;
    const pathname = decodeURIComponent(destination.split('#')[0].split('?')[0]);
    if (!pathname) continue;
    const target = resolve(dirname(file), pathname);
    try {
      const metadata = await stat(target);
      if (!metadata.isFile() && !metadata.isDirectory()) throw new Error('not a file or directory');
    } catch {
      issues.push(file.slice(root.length + 1) + ': broken local link "' + destination + '"');
    }
  }
}
if (issues.length) {
  process.stderr.write(issues.join('\n') + '\n');
  process.exitCode = 1;
} else {
  process.stdout.write('Validated local Markdown links in ' + markdownFiles.length + ' files.\n');
}
