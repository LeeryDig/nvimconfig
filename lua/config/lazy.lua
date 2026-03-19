local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop

if not uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    repo,
    lazypath,
  })

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to clone lazy.nvim: " .. output, vim.log.levels.WARN)
    return
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
})
