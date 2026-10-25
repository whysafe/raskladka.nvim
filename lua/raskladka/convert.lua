-- Перевод текста между раскладками ЙЦУКЕН и QWERTY. Без vim API: модуль работает в любом Lua 5.1+.
local M = {}

-- Клавиши в одном порядке: i-й символ одной строки стоит на той же клавише, что i-й другой.
local EN = [[`qwertyuiop[]asdfghjkl;'zxcvbnm,./~QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>?@#$^&]]
local RU = [[ёйцукенгшщзхъфывапролджэячсмитьбю.ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,"№;:?]]

-- Итератор по символам UTF-8 (в Lua 5.1 и LuaJIT нет модуля utf8)
local CHAR = "[%z\1-\127\194-\244][\128-\191]*"

local function chars(s)
  local out = {}
  for ch in s:gmatch(CHAR) do
    out[#out + 1] = ch
  end
  return out
end

local en, ru = chars(EN), chars(RU)
assert(#en == #ru, "таблицы раскладок разной длины")

local to_ru, to_en = {}, {}
for i = 1, #en do
  to_ru[en[i]] = ru[i]
  to_en[ru[i]] = en[i]
end

M.to_ru, M.to_en = to_ru, to_en

local function is_cyr(ch)
  -- Кириллица в UTF-8: два байта, первый 0xD0 или 0xD1
  local b = ch:byte(1)
  return #ch == 2 and (b == 0xD0 or b == 0xD1)
end

local function is_latin(ch)
  return #ch == 1 and ch:match("%a") ~= nil
end

M.is_cyr, M.is_latin = is_cyr, is_latin

--- В какую раскладку переводить слово: по большинству букв. nil — переводить нечего.
function M.direction(word)
  local cyr, lat = 0, 0
  for _, ch in ipairs(chars(word)) do
    if is_cyr(ch) then
      cyr = cyr + 1
    elseif is_latin(ch) then
      lat = lat + 1
    end
  end
  if cyr == 0 and lat == 0 then
    return nil
  end
  return lat >= cyr and "ru" or "en"
end

--- Переводит строку целиком в указанную раскладку. Символы без пары остаются как есть.
function M.convert(s, dir)
  local map = dir == "ru" and to_ru or to_en
  local out = {}
  for _, ch in ipairs(chars(s)) do
    out[#out + 1] = map[ch] or ch
  end
  return table.concat(out)
end

-- Ссылки, почта и пути при наборе обычно правильные: их не трогаем
local function looks_technical(word)
  return word:match("^%a+://") or word:match("^www%.") or word:match("^[%w._%-]+@[%w%-]+%.%a+$")
    or word:match("^[~.]?/") or word:match("^%a:\\")
end

--- Символы, которые внутри слова в латинице на самом деле буквы русской раскладки.
local LATIN_WORD = "[%w%[%];',%./`~{}:\"<>%?&@#%$%^]"

--- Делит строку на «слова» и промежутки так, чтобы «k.,k.» было одним словом (это «люблю»).
function M.tokens(s)
  local out = {}
  local cur, kind = {}, nil
  local function flush()
    if #cur > 0 then
      out[#out + 1] = { text = table.concat(cur), word = kind == "word" }
    end
    cur, kind = {}, nil
  end
  for _, ch in ipairs(chars(s)) do
    local k = (is_cyr(ch) or ch:match(LATIN_WORD) or ch == "№") and "word" or "space"
    if k ~= kind then
      flush()
      kind = k
    end
    cur[#cur + 1] = ch
  end
  flush()
  return out
end

-- «y» не считаем гласной: это клавиша «н», и иначе «;bpym» (жизнь) выглядело бы английским словом
local VOWELS = {}
for _, ch in ipairs(chars("aeiouAEIOUаеёиоуыэюяАЕЁИОУЫЭЮЯ")) do
  VOWELS[ch] = true
end

--- Доля гласных среди букв. В настоящих словах она около 0.3–0.5, а в набранных не в той
--- раскладке почти нулевая: «ghbdtn», «rfr», «руддщ».
function M.vowel_ratio(word)
  local letters, vowels = 0, 0
  for _, ch in ipairs(chars(word)) do
    if is_cyr(ch) or is_latin(ch) then
      letters = letters + 1
      if VOWELS[ch] then
        vowels = vowels + 1
      end
    end
  end
  return letters > 0 and vowels / letters or 0
end

local function convert_word(text, dir)
  -- Знаки в конце русского слова — пунктуация, а не буквы «ю»/«б» с другой раскладки
  local body, tail = text, ""
  if dir == "en" then
    body, tail = text:match("^(.-)([%.,!%?;:]*)$")
  end
  return M.convert(body, dir) .. tail
end

--- Похоже ли слово на набранное не в той раскладке: гласных почти нет, а после перевода их больше.
--- Порог 0.25 защищает короткие правильные слова: «the» после перевода стало бы «еру» с двумя гласными.
local function looks_wrong(text, converted)
  local before, after = M.vowel_ratio(text), M.vowel_ratio(converted)
  -- Равенство тоже засчитываем, если гласные есть: «afqk» и «файл» — по одной на четыре буквы
  return before <= 0.25 and (after > before or (after == before and after > 0))
end

--- Исправляет текст по словам. Переводятся только слова, которые выглядят набранными не в той
--- раскладке: в «пишу ntrcn в Vim» исправится одно слово. Если таких нет, а исправить просили,
--- переводится всё выделенное: значит, это осознанный выбор пользователя.
---@param s string
---@param opts? {force?: "ru"|"en", skip_technical?: boolean}
function M.fix(s, opts)
  opts = opts or {}
  local toks = M.tokens(s)
  local any_wrong = false
  for _, t in ipairs(toks) do
    t.skip = not t.word or (opts.skip_technical ~= false and looks_technical(t.text))
    t.dir = opts.force or (not t.skip and M.direction(t.text)) or nil
    if t.dir and not t.skip then
      t.converted = convert_word(t.text, t.dir)
      t.wrong = opts.force ~= nil or looks_wrong(t.text, t.converted)
      any_wrong = any_wrong or t.wrong
    end
  end

  local out = {}
  for _, t in ipairs(toks) do
    local flip = t.converted and (t.wrong or not any_wrong)
    out[#out + 1] = flip and t.converted or t.text
  end
  return table.concat(out)
end

--- Байтовые границы слова вокруг столбца col (1-based) с учётом символов раскладки.
function M.word_bounds(line, col)
  local pos = 1
  for _, t in ipairs(M.tokens(line)) do
    local last = pos + #t.text - 1
    if t.word and col >= pos and col <= last then
      return pos, last
    end
    pos = last + 1
  end
  return nil
end

--- Последнее слово перед курсором (для режима вставки): границы в байтах, 1-based.
function M.last_word_bounds(line, col)
  local before = line:sub(1, col)
  local pos, found = 1, nil
  for _, t in ipairs(M.tokens(before)) do
    if t.word then
      found = { pos, pos + #t.text - 1 }
    end
    pos = pos + #t.text
  end
  if found then
    return found[1], found[2]
  end
  return nil
end

return M
