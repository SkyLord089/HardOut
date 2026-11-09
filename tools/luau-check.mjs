// Компилирует каждый .luau файл настоящим компилятором Luau (ловец синтаксических ошибок).
// Требуется: npm i --no-save @luau-rs/luau
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

let Lua;
try {
  ({ Lua } = await import('@luau-rs/luau'));
} catch {
  console.error('Не найден @luau-rs/luau. Установите: npm i --no-save @luau-rs/luau');
  process.exit(2);
}

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (full.endsWith('.luau') || full.endsWith('.lua')) out.push(full);
  }
  return out;
}

const lua = await Lua.create();
const files = walk(path.join(root, 'src'));
let failed = 0;

for (const file of files) {
  const source = fs.readFileSync(file, 'utf8');
  try {
    lua.load(source, { chunkName: '@' + path.relative(root, file) });
  } catch (error) {
    failed += 1;
    console.error(`FAIL ${path.relative(root, file)}: ${error.message}`);
  }
}

console.log(failed === 0 ? `OK: ${files.length} файлов скомпилировались` : `Ошибок: ${failed}`);
process.exit(failed === 0 ? 0 : 1);
