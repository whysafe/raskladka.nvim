if vim.g.loaded_raskladka then
  return
end
vim.g.loaded_raskladka = true

vim.api.nvim_create_user_command("Raskladka", function(opts)
  require("raskladka").command(opts)
end, {
  range = true,
  nargs = "?",
  complete = function() return { "ru", "en" } end,
  desc = "Исправить текст, набранный не в той раскладке",
})
