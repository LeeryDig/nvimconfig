local helpers = require("core.helpers")

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
      -- Mantém o layout automático ao iniciar com um diretório, como na config atual.
      vim.cmd("enew")
      vim.cmd("botright vsplit")
      vim.cmd("vertical resize 30")
      vim.cmd("Ex")
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
  callback = helpers.update_title,
})

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.cursorline = false
    vim.opt_local.signcolumn = "no"
  end,
})
