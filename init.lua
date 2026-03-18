-- Leader key
vim.g.mapleader = " "

vim.opt.title = true

-- NETRW BASE
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
vim.g.netrw_browse_split = 4
vim.g.netrw_winsize = 25

-- Toggle lateral direita
local function toggle_netrw()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_buf_get_option(buf, "filetype")
    if ft == "netrw" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end

  vim.cmd("botright vsplit")
  vim.cmd("vertical resize 30")
  vim.cmd("Ex")
end

vim.keymap.set("n", "<leader>e", toggle_netrw, { silent = true })

-- AUTO LAYOUT QUANDO ABRIR COM nvim .
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
      vim.cmd("enew")              -- cria buffer vazio principal
      vim.cmd("botright vsplit")
      vim.cmd("vertical resize 30")
      vim.cmd("Ex")
    end
  end,
})

local function set_title()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  local file = vim.fn.expand("%:t")

  if file ~= "" then
    vim.opt.titlestring = "📄 " .. file .. " — " .. cwd .. " — NVIM"
  else
    vim.opt.titlestring = "📦 " .. cwd .. " — NVIM"
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
  callback = set_title,
})

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
vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", { silent = true })

-- Redimensionar splits com Alt + setas
vim.keymap.set("n", "<A-Up>", ":resize +2<CR>")
vim.keymap.set("n", "<A-Down>", ":resize -2<CR>")
vim.keymap.set("n", "<A-Right>", ":vertical resize +2<CR>")
vim.keymap.set("n", "<A-Left>", ":vertical resize -2<CR>")

-- Mostrar número de linhas
 vim.opt.number = true          -- número absoluto
-- vim.opt.relativenumber = true  -- número relativo (ótimo pra pular linhas)

-- Manter margem ao rolar
vim.opt.scrolloff = 16

-- linhas acima/abaixo do cursor
vim.opt.sidescrolloff = 16

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.cursorline = false
    vim.opt_local.signcolumn = "no"
  end,
})

vim.keymap.set("n", "<leader>vc", function()
  vim.cmd("vsplit")
  vim.cmd("terminal codex")
end, { desc = "Abrir Codex em split vertical" })

vim.keymap.set("n", "<leader>va", function()
  vim.cmd("vsplit")
  vim.cmd("terminal agent")
end, { desc = "Abrir Codex em split vertical" })
