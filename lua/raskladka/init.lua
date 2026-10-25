-- Исправление текста, набранного не в той раскладке: ghbdtn → привет, руддщ → hello.
local convert = require("raskladka.convert")

local M = {}

M.config = {
  -- false отключает отдельную привязку
  keymaps = {
    normal = "<leader>ru", -- слово под курсором
    visual = "<leader>ru", -- выделение
    insert = "<M-r>", -- последнее набранное слово, не выходя из режима вставки
  },
  skip_technical = true, -- не трогать ссылки, почту и пути
}

local function fix(text, force)
  return convert.fix(text, { force = force, skip_technical = M.config.skip_technical })
end

--- Слово под курсором в обычном режиме.
function M.fix_word(force)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local s, e = convert.word_bounds(line, col + 1)
  if not s then
    return false
  end
  local fixed = fix(line:sub(s, e), force)
  vim.api.nvim_buf_set_text(0, row - 1, s - 1, row - 1, e, { fixed })
  -- Курсор остаётся в начале слова: длина в байтах после замены могла измениться
  vim.api.nvim_win_set_cursor(0, { row, s - 1 })
  return true
end

--- Последнее слово перед курсором в режиме вставки.
function M.fix_last_word(force)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local s, e = convert.last_word_bounds(line, col)
  if not s then
    return false
  end
  local fixed = fix(line:sub(s, e), force)
  vim.api.nvim_buf_set_text(0, row - 1, s - 1, row - 1, e, { fixed })
  vim.api.nvim_win_set_cursor(0, { row, col + #fixed - (e - s + 1) })
  return true
end

--- Диапазон строк или посимвольное выделение. Координаты как у nvim_buf_get_text (0-based, end исключён).
function M.fix_range(srow, scol, erow, ecol, force)
  local lines = vim.api.nvim_buf_get_text(0, srow, scol, erow, ecol, {})
  local fixed = vim.split(fix(table.concat(lines, "\n"), force), "\n", { plain = true })
  vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, fixed)
end

--- Последнее визуальное выделение (после выхода из визуального режима метки '< и '> уже стоят).
function M.fix_visual(force)
  local mode = vim.fn.visualmode()
  local s = vim.api.nvim_buf_get_mark(0, "<")
  local e = vim.api.nvim_buf_get_mark(0, ">")
  if mode == "V" then
    local last = vim.api.nvim_buf_get_lines(0, e[1] - 1, e[1], false)[1] or ""
    M.fix_range(s[1] - 1, 0, e[1] - 1, #last, force)
  else
    local last = vim.api.nvim_buf_get_lines(0, e[1] - 1, e[1], false)[1] or ""
    -- '> указывает на первый байт последнего символа: дотягиваем до его конца
    local ecol = math.min(e[2] + 1, #last)
    while ecol < #last and last:byte(ecol + 1) >= 0x80 and last:byte(ecol + 1) < 0xC0 do
      ecol = ecol + 1
    end
    M.fix_range(s[1] - 1, s[2], e[1] - 1, ecol, force)
  end
end

--- Обработчик команды :Raskladka [ru|en] с диапазоном или без.
function M.command(opts)
  local force = opts.args ~= "" and opts.args or nil
  if force and force ~= "ru" and force ~= "en" then
    vim.notify("raskladka: укажите ru или en", vim.log.levels.ERROR)
    return
  end
  if opts.range == 2 then
    -- Команда, вызванная из визуального режима, получает '<,'>: берём точное выделение
    local s = vim.api.nvim_buf_get_mark(0, "<")
    local e = vim.api.nvim_buf_get_mark(0, ">")
    if s[1] == opts.line1 and e[1] == opts.line2 and vim.fn.visualmode() == "v" then
      return M.fix_visual(force)
    end
    local last = vim.api.nvim_buf_get_lines(0, opts.line2 - 1, opts.line2, false)[1] or ""
    return M.fix_range(opts.line1 - 1, 0, opts.line2 - 1, #last, force)
  end
  if not M.fix_word(force) then
    vim.notify("raskladka: под курсором нет слова", vim.log.levels.WARN)
  end
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  local km = M.config.keymaps
  if km.normal then
    vim.keymap.set("n", km.normal, function() M.fix_word() end, { desc = "Исправить раскладку слова" })
  end
  if km.visual then
    vim.keymap.set("x", km.visual, ":<C-u>lua require('raskladka').fix_visual()<CR>",
      { desc = "Исправить раскладку выделения", silent = true })
  end
  if km.insert then
    vim.keymap.set("i", km.insert, function() M.fix_last_word() end, { desc = "Исправить раскладку последнего слова" })
  end
end

return M
