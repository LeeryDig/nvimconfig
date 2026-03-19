local M = {}

local namespace = vim.api.nvim_create_namespace("netrw_git_status")
local highlight_groups = {
  added = "NetrwGitAdded",
  modified = "NetrwGitModified",
}
local icon_highlight_groups = {
  directory = "NetrwIconDirectory",
  file = "NetrwIconFile",
  code = "NetrwIconCode",
  document = "NetrwIconDocument",
  config = "NetrwIconConfig",
  git = "NetrwIconGit",
  shell = "NetrwIconShell",
}
local badges = {
  added = " [A]",
  modified = " [M]",
}
local uv = vim.uv or vim.loop
local monitor_timer

local function normalize_path(path)
  return path:gsub("\\", "/"):gsub("/+$", "")
end

local function absolute_path(path)
  return normalize_path(vim.fn.fnamemodify(path, ":p"))
end

local function parent_path(path)
  return absolute_path(vim.fn.fnamemodify(path, ":h"))
end

local function ascend_path(path, levels)
  local result = absolute_path(path)

  for _ = 1, levels do
    result = parent_path(result)
  end

  return result
end

local function path_relative_to(root, path)
  local clean_root = absolute_path(root)
  local clean_path = absolute_path(path)

  if clean_path == clean_root then
    return ""
  end

  local prefix = clean_root .. "/"

  if clean_path:sub(1, #prefix) ~= prefix then
    return nil
  end

  return clean_path:sub(#prefix + 1)
end

local function resolve_fg(candidates, fallback)
  for _, name in ipairs(candidates) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, {
      name = name,
      link = false,
    })

    if ok and hl and hl.fg then
      return hl.fg
    end
  end

  return fallback
end

local function set_highlights()
  vim.api.nvim_set_hl(0, highlight_groups.added, {
    fg = resolve_fg({ "GitSignsAdd", "Added", "DiagnosticOk", "DiffAdd" }, 0x98C379),
    ctermfg = 2,
    bold = true,
  })

  vim.api.nvim_set_hl(0, highlight_groups.modified, {
    fg = resolve_fg({ "GitSignsChange", "Changed", "DiagnosticWarn", "DiffChange" }, 0xE5C07B),
    ctermfg = 3,
    bold = true,
  })

  vim.api.nvim_set_hl(0, icon_highlight_groups.directory, {
    fg = resolve_fg({ "Directory" }, 0x61AFEF),
    ctermfg = 4,
    bold = true,
  })

  vim.api.nvim_set_hl(0, icon_highlight_groups.file, {
    fg = resolve_fg({ "Normal", "Identifier" }, 0xABB2BF),
    ctermfg = 7,
  })

  vim.api.nvim_set_hl(0, icon_highlight_groups.code, {
    fg = resolve_fg({ "Function", "Special" }, 0x61AFEF),
    ctermfg = 4,
  })

  vim.api.nvim_set_hl(0, icon_highlight_groups.document, {
    fg = resolve_fg({ "String", "Identifier" }, 0x98C379),
    ctermfg = 2,
  })

  vim.api.nvim_set_hl(0, icon_highlight_groups.config, {
    fg = resolve_fg({ "Constant", "Type" }, 0xE5C07B),
    ctermfg = 3,
  })

  vim.api.nvim_set_hl(0, icon_highlight_groups.git, {
    fg = resolve_fg({ "PreProc", "Special" }, 0xE06C75),
    ctermfg = 1,
  })

  vim.api.nvim_set_hl(0, icon_highlight_groups.shell, {
    fg = resolve_fg({ "Statement", "Special" }, 0x56B6C2),
    ctermfg = 6,
  })
end

local function system_lines(cmd)
  local output = vim.fn.systemlist(cmd)

  if vim.v.shell_error ~= 0 then
    return nil
  end

  return output
end

local function get_git_root(dir)
  local lines = system_lines({ "git", "-C", dir, "rev-parse", "--show-toplevel" })

  if not lines or not lines[1] or lines[1] == "" then
    return nil
  end

  return absolute_path(lines[1])
end

local function classify_status(index_status, worktree_status)
  local pair = index_status .. worktree_status

  if pair == "??" or index_status == "A" or worktree_status == "A" then
    return "added"
  end

  if pair == "!!" then
    return nil
  end

  if index_status ~= " " or worktree_status ~= " " then
    return "modified"
  end

  return nil
end

local function parse_status_path(line)
  local path = line:sub(4)
  local renamed = path:match("^.+ %-%> (.+)$")

  if renamed then
    return renamed
  end

  return path
end

local function get_git_statuses(git_root)
  local lines = system_lines({
    "git",
    "-C",
    git_root,
    "status",
    "--porcelain=v1",
    "--untracked-files=all",
  })

  if not lines then
    return {}
  end

  local statuses = {}

  for _, line in ipairs(lines) do
    if #line >= 3 then
      local state = classify_status(line:sub(1, 1), line:sub(2, 2))
      local path = parse_status_path(line)

      if state and path ~= "" then
        statuses[normalize_path(path)] = state
      end
    end
  end

  return statuses
end

local function parse_tree_line(line)
  local col = 0
  local depth = 0

  while true do
    local chunk = line:sub(col + 1, col + 2)

    if chunk == "| " or chunk == "  " then
      depth = depth + 1
      col = col + 2
    else
      break
    end
  end

  return {
    depth = depth,
    start_col = col,
    name = line:sub(col + 1),
  }
end

local function get_display_root(bufnr, current_dir)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_name = vim.fn.fnamemodify(current_dir, ":t")

  for _, line in ipairs(lines) do
    if line ~= "" and line ~= "../" then
      local entry = parse_tree_line(line)
      local is_directory = entry.name:sub(-1) == "/"
      local bare_name = is_directory and entry.name:sub(1, -2) or entry.name

      if is_directory and bare_name == current_name then
        return ascend_path(current_dir, entry.depth)
      end
    end
  end

  return current_dir
end

local function get_visible_entries(bufnr, display_root)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local root_name = vim.fn.fnamemodify(display_root, ":t") .. "/"
  local stack = {}
  local entries = {}

  for index, line in ipairs(lines) do
    if line ~= "" and line ~= "../" and line ~= root_name then
      local entry = parse_tree_line(line)
      local is_directory = entry.name:sub(-1) == "/"
      local bare_name = is_directory and entry.name:sub(1, -2) or entry.name

      for level = entry.depth, #stack do
        stack[level] = nil
      end

      local relative_parts = {}

      for level = 1, entry.depth - 1 do
        if stack[level] then
          table.insert(relative_parts, stack[level])
        end
      end

      table.insert(relative_parts, bare_name)

      local relative_path = normalize_path(table.concat(relative_parts, "/"))

      entries[#entries + 1] = {
        lnum = index - 1,
        start_col = entry.start_col,
        end_col = entry.start_col + #entry.name,
        depth = entry.depth,
        is_directory = is_directory,
        name = bare_name,
        relative_path = relative_path,
      }

      if is_directory then
        stack[entry.depth] = bare_name
      end
    end
  end

  return entries
end

local function entry_state(repo_relative_path, is_directory, statuses)
  local exact = statuses[repo_relative_path]

  if exact then
    return exact
  end

  if not is_directory then
    return nil
  end

  local prefix = repo_relative_path .. "/"
  local has_added = false

  for path, state in pairs(statuses) do
    if path:sub(1, #prefix) == prefix then
      if state == "modified" then
        return "modified"
      end

      if state == "added" then
        has_added = true
      end
    end
  end

  if has_added then
    return "added"
  end

  return nil
end

local function get_file_icon(name)
  local lower_name = name:lower()
  local extension = lower_name:match("%.([^.]+)$")

  local special_files = {
    [".gitignore"] = { "", icon_highlight_groups.git },
    [".gitattributes"] = { "", icon_highlight_groups.git },
    [".gitmodules"] = { "", icon_highlight_groups.git },
    [".env"] = { "", icon_highlight_groups.config },
    ["dockerfile"] = { "󰡨", icon_highlight_groups.config },
    ["makefile"] = { "", icon_highlight_groups.config },
    ["readme"] = { "", icon_highlight_groups.document },
    ["readme.md"] = { "", icon_highlight_groups.document },
  }

  if special_files[lower_name] then
    return special_files[lower_name][1], special_files[lower_name][2]
  end

  if lower_name:match("^readme%.") then
    return "", icon_highlight_groups.document
  end

  local extension_icons = {
    lua = { "", icon_highlight_groups.code },
    vim = { "", icon_highlight_groups.code },
    md = { "", icon_highlight_groups.document },
    txt = { "󰈙", icon_highlight_groups.document },
    json = { "", icon_highlight_groups.config },
    jsonc = { "", icon_highlight_groups.config },
    yaml = { "", icon_highlight_groups.config },
    yml = { "", icon_highlight_groups.config },
    toml = { "", icon_highlight_groups.config },
    conf = { "", icon_highlight_groups.config },
    ini = { "", icon_highlight_groups.config },
    sh = { "", icon_highlight_groups.shell },
    bash = { "", icon_highlight_groups.shell },
    zsh = { "", icon_highlight_groups.shell },
    fish = { "", icon_highlight_groups.shell },
    js = { "", icon_highlight_groups.code },
    jsx = { "", icon_highlight_groups.code },
    ts = { "", icon_highlight_groups.code },
    tsx = { "", icon_highlight_groups.code },
    html = { "", icon_highlight_groups.document },
    css = { "", icon_highlight_groups.document },
    scss = { "", icon_highlight_groups.document },
    lock = { "󰌾", icon_highlight_groups.config },
  }

  if extension and extension_icons[extension] then
    return extension_icons[extension][1], extension_icons[extension][2]
  end

  return "", icon_highlight_groups.file
end

local function get_entry_icon(entries, index)
  local entry = entries[index]

  if entry.is_directory then
    local next_entry = entries[index + 1]
    local is_open = next_entry and next_entry.depth > entry.depth

    if is_open then
      return "", icon_highlight_groups.directory
    end

    return "", icon_highlight_groups.directory
  end

  return get_file_icon(entry.name)
end

function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "netrw" then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  if vim.fn.executable("git") ~= 1 then
    return
  end

  local current_dir = vim.b[bufnr].netrw_curdir
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)

  if type(current_dir) ~= "string" or current_dir == "" then
    return
  end

  local git_root = get_git_root(current_dir)

  if not git_root then
    return
  end

  local display_root = get_display_root(bufnr, current_dir)
  local base_path = path_relative_to(git_root, display_root)
  local statuses = get_git_statuses(git_root)
  local entries = get_visible_entries(bufnr, display_root)

  for index, entry in ipairs(entries) do
    local repo_relative_path = entry.relative_path

    if base_path and base_path ~= "" then
      repo_relative_path = normalize_path(base_path .. "/" .. repo_relative_path)
    end

    local state = entry_state(repo_relative_path, entry.is_directory, statuses)
    local icon, icon_hl_group = get_entry_icon(entries, index)

    vim.api.nvim_buf_set_extmark(
      bufnr,
      namespace,
      entry.lnum,
      entry.start_col,
      {
        sign_text = icon,
        sign_hl_group = icon_hl_group,
        priority = 100,
        end_col = state and entry.end_col or nil,
        hl_group = state and highlight_groups[state] or nil,
      }
    )

    if state then
      vim.api.nvim_buf_set_extmark(
        bufnr,
        namespace,
        entry.lnum,
        entry.end_col,
        {
          virt_text = {
            { badges[state], highlight_groups[state] },
          },
          virt_text_win_col = entry.end_col,
        }
      )
    end
  end

  vim.b[bufnr].netrw_git_last_tick = changedtick
end

function M.refresh_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "netrw" then
      M.refresh(bufnr)
    end
  end
end

local function refresh_if_stale(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "netrw" then
    return
  end

  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)

  if vim.b[bufnr].netrw_git_last_tick == changedtick then
    return
  end

  M.refresh(bufnr)
end

local function refresh_stale_netrw_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    refresh_if_stale(bufnr)
  end
end

local function set_netrw_window_options(bufnr)
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.api.nvim_win_is_valid(winid) then
      vim.wo[winid].signcolumn = "yes:1"
    end
  end
end

local function wrap_netrw_navigation_keys(bufnr)
  if vim.b[bufnr].netrw_git_maps_wrapped then
    return
  end

  local keys_to_wrap = { "<CR>", "-", "u" }

  for _, lhs in ipairs(keys_to_wrap) do
    local map = vim.fn.maparg(lhs, "n", false, true)

    if type(map) == "table" and map.rhs and map.rhs ~= "" then
      vim.keymap.set("n", lhs, function()
        local feed_mode = map.noremap == 1 and "nx" or "mx"
        local rhs = vim.api.nvim_replace_termcodes(map.rhs, true, false, true)

        vim.api.nvim_feedkeys(rhs, feed_mode, false)

        vim.defer_fn(function()
          M.refresh_all()
        end, 60)
      end, {
        buffer = bufnr,
        nowait = map.nowait == 1,
        silent = map.silent == 1,
      })
    end
  end

  vim.b[bufnr].netrw_git_maps_wrapped = true
end

local function start_monitor()
  if monitor_timer or not uv or not uv.new_timer then
    return
  end

  monitor_timer = uv.new_timer()
  monitor_timer:start(0, 200, vim.schedule_wrap(refresh_stale_netrw_buffers))
end

local function stop_monitor()
  if not monitor_timer then
    return
  end

  monitor_timer:stop()
  monitor_timer:close()
  monitor_timer = nil
end

function M.setup()
  set_highlights()

  local group = vim.api.nvim_create_augroup("NetrwGitStatus", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      set_highlights()
      vim.schedule(M.refresh_all)
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "netrw",
    callback = function(args)
      start_monitor()

      vim.schedule(function()
        set_netrw_window_options(args.buf)
        wrap_netrw_navigation_keys(args.buf)
        M.refresh(args.buf)
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].filetype ~= "netrw" then
        return
      end

      vim.schedule(function()
        set_netrw_window_options(args.buf)
        wrap_netrw_navigation_keys(args.buf)
        M.refresh(args.buf)
      end)
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      stop_monitor()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained", "ShellCmdPost", "DirChanged" }, {
    group = group,
    callback = function()
      vim.schedule(M.refresh_all)
    end,
  })
end

return M
