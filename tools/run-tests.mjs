// Обёртка: прогон юнит-тестов стенда.
// Требуется @luau-rs/luau:  npm i --no-save @luau-rs/luau
// Запуск: node tools/run-tests.mjs
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const here = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(here, "..");
const testsDir = projectRoot;

let Lua;
try {
  ({ Lua } = await import('@luau-rs/luau'));
} catch {
  try {
    const require = createRequire(import.meta.url);
    const local = require.resolve('@luau-rs/luau', { paths: [here, process.cwd()] });
    ({ Lua } = await import(local));
  } catch (e) {
    console.error('Не найден @luau-rs/luau. Установите: npm i --no-save @luau-rs/luau');
    process.exit(2);
  }
}

const fs = await import('fs');

const lua = await Lua.create();
lua.loadLibraries(['string', 'table', 'math', 'os', 'coroutine', 'utf8', 'bit32', 'buffer']);

const cache = new Map();
const readFile = (p) => {
  const resolved = path.resolve(testsDir, p);
  if (!cache.has(resolved)) {
    cache.set(resolved, fs.existsSync(resolved) ? fs.readFileSync(resolved, 'utf8') : null);
  }
  return cache.get(resolved);
};

lua.globals.set('__readFile', lua.createFunction(readFile, { args: [String] }));
lua.globals.set('__compileSource', lua.createFunction((source, chunkname) => lua.load(source, { chunkName: chunkname, environment: lua.globals }), { args: [String, String] }));
lua.globals.set('print', lua.createFunction((msg) => console.log(String(msg)), { args: [String] }));

// Мини-эмуляция loadstring/io, которую тесты ожидают от окружения.
lua.execute(`
	local ok, err = pcall(function()
		loadstring = function(source, chunkname)
			local compiled, compileError = pcall(__compileSource, source, chunkname or "=(loadstring)")
			if not compiled then
				return nil, compileError
			end
			return compileError
		end
		io = {
			open = function(p)
				local content = __readFile(p)
				if content == nil then return nil end
				local handle = { content = content }
				function handle:read(_)
					local c = self.content
					self.content = nil
					return c
				end
				function handle:close() end
				return handle
			end,
		}
	end)
	if not ok then error(err) end
`);

const source = fs.readFileSync(path.join(testsDir, 'tests', 'run.luau'), 'utf8');
try {
  lua.load(source, { chunkName: '@tests/run.luau', environment: lua.globals }).call();
} catch (e) {
  console.error('\nТЕСТЫ УПАЛИ:', e.message || e);
  process.exit(1);
}
