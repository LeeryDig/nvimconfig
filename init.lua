-- Leader key
vim.g.mapleader = " "

-- Terminal horizontal (embaixo)
vim.keymap.set("n", "<leader>th", function()
  vim.cmd("split")
  vim.cmd("terminal")
end)

-- Terminal vertical (lado)
vim.keymap.set("n", "<leader>tv", function()
  vim.cmd("vsplit")
  vim.cmd("terminal")
end)

-- Sair do modo terminal com ESC
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])

-- Redimensionar splits com Ctrl + setas
vim.keymap.set("n", "<C-Up>", ":resize +2<CR>")
vim.keymap.set("n", "<C-Down>", ":resize -2<CR>")
vim.keymap.set("n", "<C-Right>", ":vertical resize +2<CR>")
vim.keymap.set("n", "<C-Left>", ":vertical resize -2<CR>")

-- Mostrar número de linhas
 vim.opt.number = true          -- número absoluto
-- vim.opt.relativenumber = true  -- número relativo (ótimo pra pular linhas)

-- Manter margem ao rolar
vim.opt.scrolloff = 10

-- linhas acima/abaixo do cursor
vim.opt.sidescrolloff = 10

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.cursorline = false
    vim.opt_local.signcolumn = "no"
  end,
})

vim.keymap.set("n", "<leader>c", function()
  vim.cmd("vsplit")
  vim.cmd("terminal codex")
end, { desc = "Abrir Codex em split vertical" })
