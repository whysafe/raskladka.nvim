local c = require("raskladka.convert")

test("латиница в русскую раскладку", function()
  eq(c.fix("ghbdtn"), "привет")
  eq(c.fix("Ghbdtn? rfr ltkf/"), "Привет, как дела.")
  eq(c.fix("k.,k. ;bpym"), "люблю жизнь")
  eq(c.fix("`krf"), "ёлка")
end)

test("кириллица в английскую", function()
  eq(c.fix("руддщ цщкдв"), "hello world")
  eq(c.fix("Ш дщму Мшь"), "I love Vim")
end)

test("пунктуация в конце русского слова остаётся пунктуацией", function()
  eq(c.fix("руддщ, цщкдв!"), "hello, world!")
  eq(c.fix("руддщ."), "hello.")
end)

test("в смешанном тексте исправляются только неправильные слова", function()
  eq(c.fix("привет ghbdtn"), "привет привет")
  eq(c.fix("hello руддщ"), "hello hello")
end)

test("принудительное направление", function()
  eq(c.fix("ghbdtn", { force = "ru" }), "привет")
  eq(c.fix("ghbdtn", { force = "en" }), "ghbdtn")
end)

test("ссылки, почта и пути не трогаются", function()
  eq(c.fix("https://example.com/page ghbdtn"), "https://example.com/page привет")
  eq(c.fix("hello@whysafe.ru"), "hello@whysafe.ru")
  eq(c.fix("~/.config/nvim"), "~/.config/nvim")
  eq(c.fix("https://x.ru", { skip_technical = false }), "реезыЖ..чюкг")
end)

test("цифры и символы без пары остаются", function()
  eq(c.fix("ltkj 2024 - (ujlf)"), "дело 2024 - (года)")
  eq(c.fix("..."), "...")
  eq(c.fix(""), "")
end)

test("перевод туда и обратно возвращает исходник", function()
  local s = "qwertyuiop[]asdfghjkl;'zxcvbnm,./`QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>~"
  eq(c.convert(c.convert(s, "ru"), "en"), s)
end)

test("направление по большинству букв", function()
  eq(c.direction("ghbdtn"), "ru")
  eq(c.direction("привет"), "en")
  eq(c.direction("123"), nil)
end)

test("границы слова учитывают знаки русской раскладки", function()
  local line = "ну k.,k. тебя"
  local s, e = c.word_bounds(line, 6)
  eq(line:sub(s, e), "k.,k.")
  local s2, e2 = c.last_word_bounds("пишу ntrcn", #"пишу ntrcn")
  eq(("пишу ntrcn"):sub(s2, e2), "ntrcn")
  eq(c.word_bounds("  ", 1), nil)
end)

test("в смешанном тексте правильные слова не трогаются", function()
  eq(c.fix("пишу ntrcn в Vim"), "пишу текст в Vim")
  eq(c.fix("open the afqk"), "open the файл")
  eq(c.vowel_ratio("ghbdtn"), 0)
end)
