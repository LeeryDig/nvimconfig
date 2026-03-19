local M = {}

local MAX_RESULTS = 200

local file_cache = {
  cwd = nil,
  files = nil,
}

local function get_project_files()
  local cwd = vim.fn.getcwd()

  if file_cache.cwd == cwd and file_cache.files then
    return file_cache.files
  end

  if vim.fn.executable("rg") ~= 1 then
    vim.notify("ripgrep (rg) nao esta instalado.", vim.log.levels.ERROR)
    return {}
  end

  local files = vim.fn.systemlist({ "rg", "--files" })

  if vim.v.shell_error ~= 0 then
    vim.notify("Falha ao listar arquivos do projeto.", vim.log.levels.ERROR)
    return {}
  end

  file_cache.cwd = cwd
  file_cache.files = files

  return files
end

local function fuzzy_score(text, query)
  if query == "" then
    return 0
  end

  local text_lower = text:lower()
  local query_lower = query:lower()
  local query_index = 1
  local first_match = nil
  local last_match = nil
  local score = 0

  for i = 1, #text_lower do
    if text_lower:sub(i, i) == query_lower:sub(query_index, query_index) then
      first_match = first_match or i
      score = score + 1

      if last_match and i == last_match + 1 then
        score = score + 6
      end

      if i == 1 or text_lower:sub(i - 1, i - 1) == "/" then
        score = score + 8
      end

      last_match = i
      query_index = query_index + 1

      if query_index > #query_lower then
        break
      end
    end
  end

  if query_index <= #query_lower then
    return nil
  end

  if text_lower:find(query_lower, 1, true) then
    score = score + 12
  end

  local basename = vim.fn.fnamemodify(text, ":t"):lower()

  if basename:find(query_lower, 1, true) then
    score = score + 18
  end

  return score - (first_match or 0)
end

function M.filter_files(files, query)
  if query == "" then
    return vim.list_slice(files, 1, math.min(#files, MAX_RESULTS))
  end

  local matches = {}

  for _, file in ipairs(files) do
    local score = fuzzy_score(file, query)

    if score then
      matches[#matches + 1] = {
        file = file,
        score = score,
      }
    end
  end

  table.sort(matches, function(a, b)
    if a.score == b.score then
      if #a.file == #b.file then
        return a.file < b.file
      end

      return #a.file < #b.file
    end

    return a.score > b.score
  end)

  local filtered = {}
  local limit = math.min(#matches, MAX_RESULTS)

  for index = 1, limit do
    filtered[index] = matches[index].file
  end

  return filtered
end

function M.project_files()
  local files = get_project_files()

  if vim.tbl_isempty(files) then
    vim.notify("Nenhum arquivo encontrado no projeto.", vim.log.levels.INFO)
    return
  end

  local state = {
    closed = false,
    filtered = {},
    index = 1,
    ns = vim.api.nvim_create_namespace("project_file_picker"),
    previous_win = vim.api.nvim_get_current_win(),
  }

  local width = math.min(math.max(math.floor(vim.o.columns * 0.65), 60), 100)
  local height = math.min(math.max(math.floor(vim.o.lines * 0.35), 8), 18)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.max(1, math.floor((vim.o.lines - height - 4) / 4))

  state.prompt_buf = vim.api.nvim_create_buf(false, true)
  state.results_buf = vim.api.nvim_create_buf(false, true)

  vim.bo[state.prompt_buf].buftype = "nofile"
  vim.bo[state.prompt_buf].bufhidden = "wipe"
  vim.bo[state.prompt_buf].swapfile = false
  vim.bo[state.prompt_buf].filetype = "project-picker"
  vim.bo[state.prompt_buf].buflisted = false

  vim.bo[state.results_buf].bufhidden = "wipe"
  vim.bo[state.results_buf].swapfile = false
  vim.bo[state.results_buf].modifiable = false
  vim.bo[state.results_buf].filetype = "project-picker-results"
  vim.bo[state.results_buf].buflisted = false

  vim.api.nvim_buf_set_lines(state.prompt_buf, 0, -1, false, { "" })

  state.prompt_win = vim.api.nvim_open_win(state.prompt_buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
  })

  state.results_win = vim.api.nvim_open_win(state.results_buf, false, {
    relative = "editor",
    row = row + 3,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })

  vim.wo[state.prompt_win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
  vim.wo[state.prompt_win].number = false
  vim.wo[state.prompt_win].relativenumber = false
  vim.wo[state.prompt_win].signcolumn = "no"
  vim.wo[state.prompt_win].wrap = false
  vim.wo[state.results_win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
  vim.wo[state.results_win].number = false
  vim.wo[state.results_win].relativenumber = false
  vim.wo[state.results_win].cursorline = false
  vim.wo[state.results_win].signcolumn = "no"
  vim.wo[state.results_win].wrap = false

  local augroup = vim.api.nvim_create_augroup("ProjectFilePicker" .. state.prompt_buf, {
    clear = true,
  })

  local function close_picker()
    if state.closed then
      return
    end

    state.closed = true

    pcall(vim.cmd, "stopinsert")
    pcall(vim.api.nvim_del_augroup_by_id, augroup)

    if state.previous_win and vim.api.nvim_win_is_valid(state.previous_win) then
      pcall(vim.api.nvim_set_current_win, state.previous_win)
    end

    if state.prompt_win and vim.api.nvim_win_is_valid(state.prompt_win) then
      pcall(vim.api.nvim_win_close, state.prompt_win, true)
    end

    if state.results_win and vim.api.nvim_win_is_valid(state.results_win) then
      pcall(vim.api.nvim_win_close, state.results_win, true)
    end
  end

  local function current_query()
    if not vim.api.nvim_buf_is_valid(state.prompt_buf) then
      return ""
    end

    return vim.api.nvim_buf_get_lines(state.prompt_buf, 0, 1, false)[1] or ""
  end

  local function render_results()
    if state.closed or not vim.api.nvim_buf_is_valid(state.results_buf) then
      return
    end

    state.filtered = M.filter_files(files, current_query())

    if #state.filtered == 0 then
      state.index = 1
    else
      state.index = math.min(math.max(state.index, 1), #state.filtered)
    end

    local lines = state.filtered

    if vim.tbl_isempty(lines) then
      lines = { "Nenhum arquivo encontrado" }
    end

    vim.bo[state.results_buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.results_buf, 0, -1, false, lines)
    vim.bo[state.results_buf].modifiable = false

    vim.api.nvim_buf_clear_namespace(state.results_buf, state.ns, 0, -1)

    if #state.filtered > 0 then
      vim.api.nvim_buf_add_highlight(state.results_buf, state.ns, "Visual", state.index - 1, 0, -1)

      if state.results_win and vim.api.nvim_win_is_valid(state.results_win) then
        pcall(vim.api.nvim_win_set_cursor, state.results_win, { state.index, 0 })
      end
    end
  end

  local function move_selection(delta)
    if vim.tbl_isempty(state.filtered) then
      return
    end

    state.index = state.index + delta

    if state.index < 1 then
      state.index = #state.filtered
    elseif state.index > #state.filtered then
      state.index = 1
    end

    render_results()
  end

  local function open_selection()
    local target = state.filtered[state.index]

    if not target or target == "" then
      return
    end

    close_picker()
    vim.cmd("edit " .. vim.fn.fnameescape(target))
  end

  local function map_prompt(lhs, rhs)
    vim.keymap.set({ "i", "n" }, lhs, rhs, {
      buffer = state.prompt_buf,
      silent = true,
      nowait = true,
    })
  end

  map_prompt("<Esc>", close_picker)
  map_prompt("<C-c>", close_picker)
  map_prompt("<CR>", open_selection)
  map_prompt("<Down>", function()
    move_selection(1)
  end)
  map_prompt("<Up>", function()
    move_selection(-1)
  end)
  map_prompt("<C-j>", function()
    move_selection(1)
  end)
  map_prompt("<C-k>", function()
    move_selection(-1)
  end)

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    group = augroup,
    buffer = state.prompt_buf,
    callback = render_results,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = { tostring(state.prompt_win), tostring(state.results_win) },
    callback = close_picker,
  })

  render_results()
  vim.cmd("startinsert")
end

return M
