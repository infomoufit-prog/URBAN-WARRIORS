import { cp, mkdir, rm } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const web = resolve(root, 'web');
const dist = resolve(root, 'dist');
const androidAssets = resolve(root, 'android/app/src/main/assets/www');

for (const target of [dist, androidAssets]) {
  await rm(target, { recursive: true, force: true });
  await mkdir(target, { recursive: true });
  await cp(web, target, { recursive: true });
}
console.log(`Build web: ${dist}`);
console.log(`Assets Android: ${androidAssets}`);
