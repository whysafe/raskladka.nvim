-- Проверки внутри настоящего Neovim: буфер, курсор, команды и привязки.
vim.opt.runtimepath:append(".")
vim.cmd("runtime plugin/raskladka.lua")
local r = require("raskladka")
r.setup({ keymaps = { normal = "<leader>ru", visual = "<leader>ru", insert = "<M-r>" } })

local function buffer(lines, cursor)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  if cursor then
    vim.api.nvim_win_set_cursor(0, cursor)
  end
end

local function text()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

-- Нажатия выполняются сразу и с учётом привязок, как если бы их набрал человек
local function keys(s)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(s, true, false, true), "mx", false)
end

test("nvim: слово под курсором", function()
  buffer({ "ну ghbdtn всем" }, { 1, #"ну " + 2 })
  r.fix_word()
  eq(text(), "ну привет всем")
  eq(vim.api.nvim_win_get_cursor(0)[2], #"ну ")
end)

test("nvim: привязка в обычном режиме", function()
  buffer({ "ghbdtn" }, { 1, 0 })
  keys("<leader>ru")
  eq(text(), "привет")
end)

test("nvim: последнее слово прямо в режиме вставки", function()
  buffer({ "пишу" }, { 1, 0 })
  keys("A ntrcn<M-r> lfkmit<M-r><Esc>")
  eq(text(), "пишу текст дальше")
end)

test("nvim: :Raskladka на диапазоне строк", function()
  buffer({ "ghbdtn", "руддщ", "без изменений" })
  vim.cmd("1,2Raskladka")
  eq(text(), "привет\nhello\nбез изменений")
end)

test("nvim: посимвольное выделение посреди строки", function()
  buffer({ "это ghbdtn а это нет" }, { 1, #"это " })
  keys("v5l<Esc>")
  r.fix_visual()
  eq(text(), "это привет а это нет")
end)

test("nvim: выделение, заканчивающееся на русской букве", function()
  buffer({ "руддщ мир" }, { 1, 0 })
  keys("v4l<Esc>") -- «руддщ»: 5 символов по 2 байта
  r.fix_visual()
  eq(text(), "hello мир")
end)

test("nvim: привязка в визуальном режиме", function()
  buffer({ "это ghbdtn" }, { 1, #"это " })
  keys("ve<leader>ru")
  eq(text(), "это привет")
end)

test("nvim: принудительное направление в команде", function()
  buffer({ "ghbdtn" }, { 1, 0 })
  vim.cmd("Raskladka en")
  eq(text(), "ghbdtn")
  vim.cmd("Raskladka ru")
  eq(text(), "привет")
end)

test("nvim: отмена одним u", function()
  buffer({ "ghbdtn" }, { 1, 0 })
  vim.cmd("let &undolevels = &undolevels") -- закрываем блок отмены, как после обычного набора
  r.fix_word()
  keys("u")
  eq(text(), "ghbdtn")
end)
