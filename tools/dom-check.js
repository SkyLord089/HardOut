// Проверка .rbxlx настоящим парсером rbx-dom (тот же, что в Rojo).
// Требуется: npm i --no-save rbx-dom
// (тот же парсер, что использует Rojo: если он читает файл — файл валиден)
let readXml;
try {
  ({ readXml } = require('rbx-dom'));
} catch {
  console.log('Пропущено: не установлен rbx-dom (npm i --no-save rbx-dom)');
  process.exit(0);
};
const fs = require('fs');
const path = process.argv[2] || '/home/user/HardOut/HardOut.rbxlx';

let dom;
try { dom = readXml(fs.readFileSync(path)); } catch (e) {
  console.log('PARSE FAIL: ' + e.message); process.exit(1);
}
console.log('PARSE OK');
console.log('instances:', dom.instanceCount);

let lines = [];
function walk(ref, depth) {
  const inst = dom.instance(ref);
  if (!inst) return;
  const cls = inst.className;
  const nm = inst.name;
  if (depth <= 3) lines.push('  '.repeat(depth) + `${cls}: ${nm}`);
  const kids = inst.children || [];
  for (const child of kids) walk(child, depth + 1);
}
for (const ref of dom.root().children) walk(ref, 0);
console.log(lines.join('\n'));

console.log('\n--- скрипты ---');
const problems = [];
function collect(ref) {
  const inst = dom.instance(ref);
  if (!inst) return;
  if (['Script', 'LocalScript', 'ModuleScript'].includes(inst.className)) {
    const src = dom.getProperty(ref, 'Source');
    const nm = inst.name;
    if (!src || String(src).length === 0) problems.push(`${inst.className} "${nm}" — ПУСТОЙ Source`);
  }
  for (const child of inst.children || []) collect(child);
}
for (const ref of dom.root().children) collect(ref);
console.log(problems.length ? problems.join('\n') : 'все скрипты с исходниками');
