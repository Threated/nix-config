-- A dedicated editor for jj's temporary before/after trees. Only Apply commits
-- the session; even saved temporary files are discarded on ordinary exit.
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
vim.opt.statusline = " jj diff edit | Ctrl j/k: next/prev hunk | Ctrl c: apply | q: discard "

-- One Dark Pro supplies syntax colors and mini.diff overlay highlights.
require("onedarkpro").setup({
  plugins = {
    all = false,
    treesitter = true,
    mini_diff = true,
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

vim.api.nvim_create_user_command("Apply", function()
  local ok, err = pcall(function()
    if modified_buf and vim.bo[modified_buf].modified then
      vim.api.nvim_buf_call(modified_buf, function()
        vim.cmd.write()
      end)
    end
    assert(vim.fn.writefile({ "accepted" }, accepted) == 0, "Could not accept the session")
  end)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.cmd("qa!")
end, { desc = "Save this file and apply it to the selected jj change" })

vim.api.nvim_create_user_command("Discard", function()
  vim.cmd("cq!")
end, { desc = "Discard this diff edit, including saved temporary files" })

vim.keymap.set("n", "<C-c>", "<Cmd>Apply<CR>")
vim.keymap.set("n", "q", "<Cmd>Discard<CR>")

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
      local files = vim.tbl_keys(paths)
      if #files ~= 1 then
        vim.api.nvim_err_writeln("Expected a diff for exactly one file")
        vim.cmd("cq!")
        return
      end
      local original = vim.fs.joinpath(left, files[1])
      local reference = vim.fn.filereadable(original) == 1 and table.concat(vim.fn.readfile(original), "\n") or ""
      vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(right, files[1])))
      modified_buf = vim.api.nvim_get_current_buf()
      local diff = require("mini.diff")
      diff.setup({
        source = diff.gen_source.none(),
        mappings = { apply = "", reset = "", textobject = "", goto_first = "", goto_prev = "", goto_next = "", goto_last = "" },
      })
      vim.keymap.set("n", "<C-j>", function()
        diff.goto_hunk("next")
      end)
      vim.keymap.set("n", "<C-k>", function()
        diff.goto_hunk("prev")
      end)
      -- Fold unchanged context once; later edits update the overlay without
      -- resetting folds the user has opened.
      vim.wo.foldmethod = "manual"
      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniDiffUpdated",
        once = true,
        callback = function()
          local hunks = diff.get_buf_data(modified_buf).hunks
          local start = 1
          for _, hunk in ipairs(hunks) do
            local stop = math.max(1, hunk.buf_start - 6)
            if stop > start + 1 then
              vim.cmd(start .. "," .. (stop - 1) .. "fold")
            end
            start = math.max(start, hunk.buf_start + hunk.buf_count + 6)
          end
          local count = vim.api.nvim_buf_line_count(modified_buf)
          if #hunks > 0 and start < count then
            vim.cmd(start .. "," .. count .. "fold")
          end
          vim.cmd("normal! zvzz")
        end,
      })
      diff.set_ref_text(modified_buf, reference)
      diff.toggle_overlay(modified_buf)
      if target_line then
        local line = math.min(target_line, vim.api.nvim_buf_line_count(modified_buf))
        vim.api.nvim_win_set_cursor(0, { math.max(1, line), 0 })
        vim.cmd("normal! zz")
      end
    end)
  end,
})
