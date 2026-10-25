-- Мини-раннер без зависимостей: работает и в `lua tests/run.lua`, и в `nvim --headless -l tests/run.lua`.
package.path = "./lua/?.lua;./lua/?/init.lua;./tests/?.lua;" .. package.path

local passed, failed = 0, 0
_G.test = function(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("ok   " .. name)
  else
    failed = failed + 1
    print("FAIL " .. name .. "\n     " .. tostring(err))
  end
end

_G.eq = function(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s\n     ожидалось: %q\n     получено:  %q", msg or "", tostring(expected), tostring(actual)), 2)
  end
end

dofile("tests/convert_spec.lua")
if vim then
  dofile("tests/nvim_spec.lua")
else
  print("(тесты редактора пропущены: запустите через nvim --headless -l tests/run.lua)")
end

print(string.format("\n%d прошло, %d упало", passed, failed))
if failed > 0 then
  os.exit(1)
end
