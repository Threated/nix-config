-- Edit private copies of jj's before/after trees. Split reloads this buffer;
-- quitting discards pending edits without undoing splits already completed.
vim.opt.loadplugins = false
vim.opt.modeline = false
vim.opt.exrc = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undofile = false
vim.opt.fixendofline = false
vim.opt.hidden = true
vim.opt.number = true
vim.opt.termguicolors = true
vim.opt.laststatus = 3
local normal_statusline = " Space Space: files | Ctrl j/k: hunks | v: select | Ctrl c: apply | q: discard "
vim.opt.statusline = normal_statusline

-- One Dark Pro supplies syntax colors and mini.diff overlay highlights.
require("onedarkpro").setup({
  plugins = {
    all = false,
    treesitter = true,
    mini_diff = true,
    telescope = true,
  },
  -- Subtle diff backgrounds preserve syntax colors on the edited text.
  highlights = {
    MiniDiffSignAdd = { fg = "#b3e08d" },
    MiniDiffSignDelete = { fg = "#e06c75" },
    MiniDiffOverAdd = { bg = "#313a33" },
    MiniDiffOverDelete = { fg = "#cf858c", bg = "#342e33" },
    MiniDiffOverChange = { fg = "#e06c75", bg = "#403138" },
    MiniDiffOverChangeBuf = { bg = "#384438", bold = true },
    MiniDiffOverContext = { fg = "#b98b92", bg = "#342e33" },
    MiniDiffOverContextBuf = { bg = "#313a33" },
    TelescopeNormal = { link = "Normal" },
    TelescopePromptNormal = { link = "Normal" },
    TelescopeResultsNormal = { link = "Normal" },
    TelescopeBorder = { fg = "#5c6370", bg = "#282c34" },
    TelescopePromptBorder = { link = "TelescopeBorder" },
    TelescopeResultsBorder = { link = "TelescopeBorder" },
    TelescopePromptTitle = { link = "TelescopeBorder" },
    TelescopeResultsTitle = { link = "TelescopeBorder" },
  },
})
vim.cmd("syntax enable")
vim.cmd("colorscheme onedark")

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "nix", "rust" },
  callback = function(event)
    vim.treesitter.start(event.buf)
    vim.bo[event.buf].syntax = ""
  end,
})

local args = vim.fn.argv()
assert(#args == 2, "Expected jj's left and right directories")
local left = vim.fn.resolve(vim.fs.abspath(args[1]))
local right = vim.fn.resolve(vim.fs.abspath(args[2]))
local accepted = assert(vim.env.JJUI_DIFF_ACCEPT, "Missing diff editor session")
local target_line = tonumber(vim.env.JJUI_DIFF_LINE)
local modified_buf
local relative_file
local refresh_diff
local open_file
local pick_file
local files = {}

local function within(path, directory)
  return path:sub(1, #directory + 1) == directory .. "/"
end

local function buffer_path(buf)
  return vim.fn.resolve(vim.api.nvim_buf_get_name(buf))
end

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(event)
    local path = buffer_path(event.buf)
    if not within(path, right) then
      error("Only files in jj's modified tree can be written")
    end
    -- Added files can live in directories which do not yet exist on this side.
    vim.fn.mkdir(vim.fs.dirname(path), "p")
  end,
})

local function save_edits(all)
  for _, file in pairs(files) do
    -- Undo can restore an added file's original text without marking the
    -- buffer modified, while its private on-disk copy is still absent.
    local restored = vim.fn.filereadable(buffer_path(file.buf)) == 0
      and (vim.api.nvim_buf_line_count(file.buf) > 1 or vim.api.nvim_buf_get_lines(file.buf, 0, 1, false)[1] ~= "")
    if (all or file.buf == modified_buf) and (vim.bo[file.buf].modified or restored) then
      vim.api.nvim_buf_call(file.buf, function() vim.cmd.write() end)
    end
  end
end

local function run_action(action)
  if not vim.env.JJUI_DIFF_ACTION then return end
  local result = vim.system({ vim.env.JJUI_DIFF_ACTION, "--action", action }, { text = true }):wait()
  assert(result.code == 0, result.stderr ~= "" and result.stderr or "Could not update the jj change")
  return result.stdout
end

vim.api.nvim_create_user_command("Apply", function()
  local ok, err = pcall(function()
    save_edits(true)
    local pending = {}
    for path, file in pairs(files) do pending[#pending + 1] = { path = path, base = file.base } end
    vim.env.JJUI_DIFF_APPLY = vim.json.encode(pending)
    run_action("apply")
    assert(vim.fn.writefile({ "accepted" }, accepted) == 0, "Could not accept the session")
  end)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.cmd("qa!")
end, { desc = "Save opened files and apply them to the selected jj change" })

-- Use the same diff options as the overlay, calculated immediately to include
-- edits made before mini.diff's update debounce.
local function read_diff()
  local original = vim.fs.joinpath(left, relative_file)
  local reference = vim.fn.filereadable(original) == 1 and vim.fn.readfile(original, "b") or {}
  local reference_text = table.concat(reference, "\n")
  local reference_eol = reference[#reference] == ""
  if reference_eol then table.remove(reference) end
  local edited = vim.api.nvim_buf_get_lines(modified_buf, 0, -1, false)
  local deleted = vim.fn.filereadable(buffer_path(modified_buf)) == 0 and not vim.bo[modified_buf].modified
    and #edited == 1 and edited[1] == ""
  if deleted then edited = {} end
  local edited_text = deleted and "" or table.concat(edited, "\n") .. (vim.bo[modified_buf].endofline and "\n" or "")
  local options = MiniDiff.get_buf_data(modified_buf).config.options
  return {
    reference = reference, reference_eol = reference_eol, edited = edited, deleted = deleted,
    reference_exists = vim.fn.filereadable(original) == 1,
    hunks = vim.text.diff(reference_text, edited_text, {
      result_type = "indices", algorithm = options.algorithm,
      indent_heuristic = options.indent_heuristic, linematch = options.linematch,
    }),
  }
end

local function hunk_bounds(hunk)
  local first = math.max(1, hunk[3])
  return first, first + math.max(1, hunk[4]) - 1
end

local selection
local selection_ns = vim.api.nvim_create_namespace("jj-diff-selection")
local visual = vim.api.nvim_get_hl(0, { name = "Visual", link = false })
vim.api.nvim_set_hl(0, "JjDiffSelectedReference", { fg = "#cf858c", bg = visual.bg or "#43516b" })

local function clear_selection()
  if not selection then return end
  selection = nil
  vim.api.nvim_buf_clear_namespace(modified_buf, selection_ns, 0, -1)
  if not MiniDiff.get_buf_data(modified_buf).overlay then MiniDiff.toggle_overlay(modified_buf) end
end

-- Native Visual highlighting does not cover virtual reference lines. While
-- selecting, draw a preview which highlights those lines as well.
local function preview_selection()
  local data = selection.data
  local low, high = math.min(selection.anchor, selection.active), math.max(selection.anchor, selection.active)
  vim.api.nvim_buf_clear_namespace(modified_buf, selection_ns, 0, -1)
  for index, hunk in ipairs(data.hunks) do
    local selected = index >= low and index <= high
    local first, last = hunk_bounds(hunk)
    if hunk[4] > 0 then
      vim.api.nvim_buf_set_extmark(modified_buf, selection_ns, first - 1, 0, {
        end_row = last, hl_group = selected and "Visual" or "MiniDiffOverAdd",
        hl_eol = true, priority = 250,
      })
    else
      -- A deletion has no real lines; highlight its cursor anchor too.
      if selected then
        vim.api.nvim_buf_set_extmark(modified_buf, selection_ns, first - 1, 0, {
          line_hl_group = "Visual", priority = 250,
        })
      end
    end
    if hunk[2] > 0 then
      local lines = {}
      for i = hunk[1], hunk[1] + hunk[2] - 1 do
        local text = data.reference[i]
        local group = selected and "JjDiffSelectedReference" or "MiniDiffOverDelete"
        lines[#lines + 1] = { { text .. string.rep(" ", math.max(0, vim.api.nvim_win_get_width(0) - vim.fn.strdisplaywidth(text))), group } }
      end
      vim.api.nvim_buf_set_extmark(modified_buf, selection_ns, first - 1, 0, {
        virt_lines = lines, virt_lines_above = hunk[4] > 0 or hunk[3] == 0,
        priority = 250,
      })
    end
  end
end

local function show_selection()
  local low, high = math.min(selection.anchor, selection.active), math.max(selection.anchor, selection.active)
  local first = hunk_bounds(selection.data.hunks[low])
  local _, last = hunk_bounds(selection.data.hunks[high])
  -- Rebuild the linewise selection so reversing direction shrinks it, and
  -- crossing the original hunk extends it in the other direction.
  if vim.fn.mode() == "V" then vim.cmd("normal! " .. string.char(27)) end
  local anchor_line = selection.active < selection.anchor and last or first
  local active_line = selection.active < selection.anchor and first or last
  vim.api.nvim_win_set_cursor(0, { anchor_line, 0 })
  vim.cmd("normal! V")
  vim.api.nvim_win_set_cursor(0, { active_line, 0 })
  vim.cmd("normal! zv")
  preview_selection()
end

local adjusting_selection = false
local function select_hunk()
  local data = read_diff()
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  for index, hunk in ipairs(data.hunks) do
    local first, last = hunk_bounds(hunk)
    if cursor >= first and cursor <= last then
      selection = { data = data, anchor = index, active = index }
      if MiniDiff.get_buf_data(modified_buf).overlay then MiniDiff.toggle_overlay(modified_buf) end
      adjusting_selection = true
      show_selection()
      adjusting_selection = false
      return
    end
  end
  vim.notify("No changed hunk under the cursor", vim.log.levels.INFO)
end

local function extend_selection(direction)
  if not selection then return end
  selection.active = math.max(1, math.min(#selection.data.hunks, selection.active + direction * vim.v.count1))
  adjusting_selection = true
  show_selection()
  adjusting_selection = false
end

vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = "*:*",
  callback = function()
    local selecting = vim.fn.mode() == "V"
    vim.opt.statusline = selecting and " j/k: select hunks | Ctrl j/k: extract below/above | d: revert | Esc: cancel " or normal_statusline
    if not adjusting_selection and not selecting then clear_selection() end
  end,
})

local function selected_hunks()
  assert(selection and vim.fn.mode() == "V", "Select hunks with v first")
  local low, high = math.min(selection.anchor, selection.active), math.max(selection.anchor, selection.active)
  local data = selection.data
  local first = hunk_bounds(data.hunks[low])
  local _, last = hunk_bounds(data.hunks[high])
  local visual_start, visual_end = vim.fn.line("v"), vim.fn.line(".")
  assert(math.min(visual_start, visual_end) == first and math.max(visual_start, visual_end) == last,
    "Use j/k to adjust the whole-hunk selection")
  return data, low, high
end

local function revert_selection()
  local ok, err = pcall(function()
    local data, low, high = selected_hunks()
    local restored, next_edited = {}, 1
    for index = low, high do
      local ref_start, ref_count, buf_start, buf_count = unpack(data.hunks[index])
      local prefix = buf_count == 0 and buf_start or buf_start - 1
      for i = next_edited, prefix do restored[#restored + 1] = data.edited[i] end
      for i = ref_start, ref_start + ref_count - 1 do restored[#restored + 1] = data.reference[i] end
      next_edited = prefix + buf_count + 1
    end
    for i = next_edited, #data.edited do restored[#restored + 1] = data.edited[i] end
    local eol = vim.bo[modified_buf].endofline
    if next_edited > #data.edited then eol = data.reference_eol end
    vim.cmd("normal! " .. string.char(27))
    clear_selection()
    -- One buffer edit keeps the whole revert undoable with u.
    vim.api.nvim_buf_set_lines(modified_buf, 0, -1, false, restored)
    if data.reference_exists or #restored > 0 then vim.bo[modified_buf].endofline = eol end
    if not data.reference_exists and #restored == 0 then
      -- Reverting every line of an added file removes the private file too.
      if vim.fn.filereadable(buffer_path(modified_buf)) == 1 then
        assert(vim.fn.delete(buffer_path(modified_buf)) == 0, "Could not revert the added file")
      end
      vim.bo[modified_buf].modified = false
    end
    refresh_diff(false)
  end)
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end

-- Build the parent snapshot with every selected hunk applied. Unselected
-- changes stay in the source, even when the selection spans unchanged context.
local function split_selection(direction)
  local request = vim.env.JJUI_HUNK_REQUEST
  local ok, err = pcall(function()
    assert(request and vim.env.JJUI_HUNK_SELECTION, "Hunk splitting requires opening the editor from jjui")
    local data, low, high = selected_hunks()
    local snapshot, next_reference = {}, 1
    for index = low, high do
      local ref_start, ref_count, buf_start, buf_count = unpack(data.hunks[index])
      local prefix = ref_count == 0 and ref_start or ref_start - 1
      for i = next_reference, prefix do snapshot[#snapshot + 1] = data.reference[i] end
      for i = buf_start, buf_start + buf_count - 1 do snapshot[#snapshot + 1] = data.edited[i] end
      next_reference = prefix + ref_count + 1
    end
    for i = next_reference, #data.reference do snapshot[#snapshot + 1] = data.reference[i] end
    local eol = data.reference_eol
    if next_reference > #data.reference then eol = vim.bo[modified_buf].endofline end
    if eol and #snapshot > 0 then snapshot[#snapshot + 1] = "" end
    assert(vim.fn.writefile(snapshot, vim.env.JJUI_HUNK_SELECTION, "b") == 0, "Could not save the selected hunks")
    assert(vim.fn.writefile({ vim.json.encode({
      direction = direction, file = relative_file, delete = data.deleted and #snapshot == 0,
    }) }, request) == 0, "Could not request the hunk split")
    save_edits()
    run_action(direction)
    vim.cmd("normal! " .. string.char(27))
    clear_selection()
    refresh_diff(true)
  end)
  if not ok then
    if request then vim.fn.delete(request) end
    vim.notify(tostring(err), vim.log.levels.ERROR)
  end
end

vim.api.nvim_create_user_command("Discard", function()
  if vim.env.JJUI_DIFF_DISCARDED then
    vim.fn.writefile({ "discarded" }, vim.env.JJUI_DIFF_DISCARDED)
  end
  vim.cmd("cq!")
end, { desc = "Discard this diff edit, including saved temporary files" })

local function editor_maps()
  local function map(mode, key, rhs)
    vim.keymap.set(mode, key, rhs, { buffer = modified_buf })
  end
  map("n", "<C-c>", "<Cmd>Apply<CR>")
  map("n", "q", "<Cmd>Discard<CR>")
  map("n", "v", select_hunk)
  map("n", "V", select_hunk)
  for _, key in ipairs({ "j", "<Down>" }) do
    map("x", key, function() extend_selection(1) end)
  end
  for _, key in ipairs({ "k", "<Up>" }) do
    map("x", key, function() extend_selection(-1) end)
  end
  for _, key in ipairs({ "o", "O" }) do
    map("x", key, function()
      if selection then
        selection.anchor, selection.active = selection.active, selection.anchor
      end
      vim.cmd("normal! o")
    end)
  end
  map("x", "v", "<Esc>")
  map("x", "<C-v>", "<Nop>")
  map("x", "<C-j>", function() split_selection("before") end)
  map("x", "<C-k>", function() split_selection("after") end)
  map("x", "d", revert_selection)

  map("n", "<C-j>", function() MiniDiff.goto_hunk("next") end)
  map("n", "<C-k>", function() MiniDiff.goto_hunk("prev") end)
  map("n", "  ", function() pick_file() end)
end

pick_file = function()
  local ok, err = pcall(function()
    assert(vim.env.JJUI_DIFF_REVISION, "File picking requires opening the editor from jjui")
    local result = vim.system({ "jj", "diff", "-r", vim.env.JJUI_DIFF_REVISION,
      "--color", "never", "-T", 'path ++ "\\0"' }, { text = true }):wait()
    assert(result.code == 0, result.stderr)
    local paths = {}
    for _, path in ipairs(vim.split(result.stdout, "\0", { plain = true, trimempty = true })) do paths[path] = true end
    -- Keep visited files available even after all their hunks have been moved.
    for path in pairs(files) do paths[path] = true end
    local candidates = vim.tbl_keys(paths)
    table.sort(candidates)
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local opts = require("telescope.themes").get_dropdown({ previewer = false })
    require("telescope.pickers").new(opts, {
      prompt_title = "Files in this change",
      finder = require("telescope.finders").new_table({ results = candidates }),
      sorter = require("telescope.config").values.generic_sorter(opts),
      attach_mappings = function(prompt_buf, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_buf)
          if entry then
            vim.schedule(function()
              local switched, failure = pcall(open_file, entry.value)
              if not switched then vim.notify(tostring(failure), vim.log.levels.ERROR) end
            end)
          end
        end)
        map("i", "<Esc>", actions.close)
        map("i", "<C-c>", actions.close)
        map("n", "<C-c>", actions.close)
        for _, mode in ipairs({ "i", "n" }) do
          map(mode, "<C-j>", actions.move_selection_next)
          map(mode, "<C-k>", actions.move_selection_previous)
        end
        return true
      end,
    }):find()
  end)
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      -- jj supplies temporary trees filtered to the selected file. The file can
      -- be absent from either side when it was added or removed.
      local paths = {}
      for _, directory in ipairs({ left, right }) do
        for path, kind in vim.fs.dir(directory, { depth = math.huge }) do
          if kind ~= "directory" and path ~= "JJ-INSTRUCTIONS" then
            paths[path] = true
          end
        end
      end
      local initial_files = vim.tbl_keys(paths)
      if #initial_files ~= 1 then
        vim.api.nvim_err_writeln("Expected a diff for exactly one file")
        vim.cmd("cq!")
        return
      end
      local initial_file = initial_files[1]
      local diff = require("mini.diff")
      diff.setup({
        source = diff.gen_source.none(),
        mappings = { apply = "", reset = "", textobject = "", goto_first = "", goto_prev = "", goto_next = "", goto_last = "" },
      })
      require("telescope").setup({})
      refresh_diff = function(reload, line)
        local buf, window = modified_buf, vim.api.nvim_get_current_win()
        line = line or vim.api.nvim_win_get_cursor(0)[1]
        if reload then
          vim.cmd("edit!")
        end
        vim.cmd("normal! zE")
        local original = vim.fs.joinpath(left, relative_file)
        local reference = vim.fn.filereadable(original) == 1 and table.concat(vim.fn.readfile(original), "\n") or ""
        -- Fold unchanged context once per reload; typing only updates the overlay.
        vim.wo.foldmethod = "manual"
        vim.api.nvim_create_autocmd("User", {
          pattern = "MiniDiffUpdated",
          once = true,
          callback = function()
            if not vim.api.nvim_win_is_valid(window) or vim.api.nvim_win_get_buf(window) ~= buf then return end
            vim.api.nvim_win_call(window, function()
              local hunks = diff.get_buf_data(buf).hunks
              local start = 1
              for _, hunk in ipairs(hunks) do
                local stop = math.max(1, hunk.buf_start - 6)
                if stop > start + 1 then
                  vim.cmd(start .. "," .. (stop - 1) .. "fold")
                end
                start = math.max(start, hunk.buf_start + hunk.buf_count + 6)
              end
              local count = vim.api.nvim_buf_line_count(buf)
              if #hunks > 0 and start < count then
                vim.cmd(start .. "," .. count .. "fold")
              end
              vim.cmd("normal! zvzz")
            end)
          end,
        })
        diff.set_ref_text(modified_buf, reference)
        if not diff.get_buf_data(modified_buf).overlay then diff.toggle_overlay(modified_buf) end
        if line then
          line = math.min(line, vim.api.nvim_buf_line_count(modified_buf))
          vim.api.nvim_win_set_cursor(0, { math.max(1, line), 0 })
          vim.cmd("normal! zvzz")
        end
      end
      open_file = function(path, line)
        if relative_file then files[relative_file].cursor = vim.api.nvim_win_get_cursor(0) end
        local file = files[path]
        local fileset = "file:" .. vim.json.encode(path)
        if not file then
          local previous_path, previous_fileset, previous_base = vim.env.JJUI_DIFF_PATH, vim.env.JJUI_DIFF_FILESET, vim.env.JJUI_DIFF_BASE
          vim.env.JJUI_DIFF_PATH, vim.env.JJUI_DIFF_FILESET = path, fileset
          local loaded, output = pcall(run_action, "load")
          if not loaded then
            vim.env.JJUI_DIFF_PATH, vim.env.JJUI_DIFF_FILESET, vim.env.JJUI_DIFF_BASE = previous_path, previous_fileset, previous_base
            error(output)
          end
          file = { base = vim.json.decode(output).base }
        end
        relative_file = path
        vim.env.JJUI_DIFF_PATH, vim.env.JJUI_DIFF_FILESET, vim.env.JJUI_DIFF_BASE = path, fileset, file.base
        if file.buf then
          vim.api.nvim_set_current_buf(file.buf)
        else
          vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(right, path)))
          file.buf = vim.api.nvim_get_current_buf()
          files[path] = file
        end
        modified_buf = file.buf
        vim.wo.winbar = " %<" .. vim.fn.strtrans(path):gsub("%%", "%%%%") .. " %m"
        editor_maps()
        refresh_diff(false, line or (file.cursor and file.cursor[1]) or 1)
        if file.cursor and not line then
          local cursor = { math.min(file.cursor[1], vim.api.nvim_buf_line_count(file.buf)), file.cursor[2] }
          vim.api.nvim_win_set_cursor(0, cursor)
        end
      end
      -- The initial snapshot has already been loaded by the coordinator.
      files[initial_file] = { base = vim.env.JJUI_DIFF_BASE }
      open_file(initial_file, target_line)
      if vim.env.JJUI_DIFF_PICKER == "true" then vim.schedule(pick_file) end
    end)
  end,
})
