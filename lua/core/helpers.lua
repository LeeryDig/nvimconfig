local M = {}

function M.toggle_netrw()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)

    if vim.bo[buf].filetype == "netrw" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end

  vim.cmd("botright vsplit")
  vim.cmd("vertical resize 30")
  vim.cmd("Ex")
end

function M.open_terminal_split(split_cmd, terminal_cmd)
  vim.cmd(split_cmd)

  if terminal_cmd and terminal_cmd ~= "" then
    vim.cmd("terminal " .. terminal_cmd)
    return
  end

  vim.cmd("terminal")
end

function M.update_title()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  local file = vim.fn.expand("%:t")

  if file ~= "" then
    vim.opt.titlestring = "📄 " .. file
    return
  end

  vim.opt.titlestring = "📦 " .. cwd
end

function M.project_search()
  if vim.fn.executable("rg") ~= 1 then
    vim.notify("ripgrep (rg) nao esta instalado.", vim.log.levels.ERROR)
    return
  end

  local default_query = vim.fn.expand("<cword>")

  vim.ui.input({
    prompt = "Buscar no projeto: ",
    default = default_query,
  }, function(query)
    if query == nil or query == "" then
      return
    end

    local lines = vim.fn.systemlist({
      "rg",
      "--vimgrep",
      "--smart-case",
      query,
      ".",
    })

    if vim.v.shell_error > 1 then
      vim.notify("Falha ao executar rg.", vim.log.levels.ERROR)
      return
    end

    if vim.v.shell_error == 1 or vim.tbl_isempty(lines) then
      vim.fn.setqflist({}, "r")
      vim.notify("Nenhum resultado para: " .. query, vim.log.levels.INFO)
      return
    end

    vim.fn.setqflist({}, " ", {
      title = "Busca no projeto: " .. query,
      lines = lines,
      efm = "%f:%l:%c:%m",
    })

    vim.cmd("copen")
  end)
end

return M
