local helpers = require("core.helpers")
local pickers = require("core.pickers")

vim.keymap.set("n", "<leader>b", helpers.toggle_netrw, {
  silent = true,
  desc = "Alternar netrw",
})

vim.keymap.set("n", "<leader>f", helpers.project_search, {
  silent = true,
  desc = "Buscar no projeto",
})

vim.keymap.set("n", "<leader>p", pickers.project_files, {
  silent = true,
  desc = "Abrir arquivo no projeto",
})

vim.keymap.set("n", "<leader>th", function()
  helpers.open_terminal_split("split")
end, { desc = "Terminal horizontal" })

vim.keymap.set("n", "<leader>tv", function()
  helpers.open_terminal_split("vsplit")
end, { desc = "Terminal vertical" })

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
  silent = true,
  desc = "Sair do terminal",
})

vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", {
  silent = true,
  desc = "Limpar busca",
})

vim.keymap.set("n", "<A-Up>", ":resize +2<CR>", {
  silent = true,
  desc = "Aumentar altura",
})

vim.keymap.set("n", "<A-Down>", ":resize -2<CR>", {
  silent = true,
  desc = "Diminuir altura",
})

vim.keymap.set("n", "<A-Right>", ":vertical resize +2<CR>", {
  silent = true,
  desc = "Aumentar largura",
})

vim.keymap.set("n", "<A-Left>", ":vertical resize -2<CR>", {
  silent = true,
  desc = "Diminuir largura",
})

vim.keymap.set("n", "<leader>vc", function()
  helpers.open_terminal_split("vsplit", "codex")
end, { desc = "Abrir Codex em split vertical" })

vim.keymap.set("n", "<leader>va", function()
  helpers.open_terminal_split("vsplit", "agent")
end, { desc = "Abrir agent em split vertical" })
