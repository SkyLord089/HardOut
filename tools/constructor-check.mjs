#!/usr/bin/env node
// Проверяет, что каждый `function X.new(...)` возвращает объект.
// Реальный баг: PlayerController.new() не имел `return self`, из-за чего
// ClientBoot падал на следующей строке и весь клиент молча умирал.
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || 'src');

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else if (entry.name.endsWith('.luau')) out.push(full);
  }
  return out;
}

const problems = [];
for (const file of walk(root)) {
  const source = fs.readFileSync(file, 'utf8');
  const re = /^function\s+([\w.]+)\.new\s*\(/gm;
  let match;
  while ((match = re.exec(source))) {
    const start = match.index;
    const endRel = /\nend\s*$/m.exec(source.slice(start));
    if (!endRel) continue;
    const body = source.slice(start, start + endRel.index);
    const buildsSelf = /local self|setmetatable\(/.test(body);
    const returns = /return\s+self/.test(body) || /return\s+setmetatable\(/.test(body);
    if (buildsSelf && !returns) {
      problems.push(`${path.relative(process.cwd(), file)}: ${match[1]}.new — не возвращает объект (нужен return self)`);
    }
  }
}

if (problems.length > 0) {
  console.log('FAIL конструкторы:');
  for (const p of problems) console.log('  - ' + p);
  process.exit(1);
}
console.log('OK: все конструкторы .new возвращают объект');
