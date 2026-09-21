-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

---@module 'lazy'
---@type LazySpec
return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '3.42.0',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  ---@module 'neo-tree'
  ---@type neotree.Config
  opts = {
    filesystem = {
      bind_to_cwd = true,
      cwd_target = {
        sidebar = 'global',
        current = 'window',
      },
      window = {
        mappings = {
          ['\\'] = 'close_window',
        },
      },
      use_libuv_file_watcher = true,
      filtered_items = {
        visible = true,
      },
    },
  },
  config = function(_, opts)
    require('neo-tree').setup(opts)

    -- Neo-tree does not yet observe linked-worktree common Git directories.
    local neo_tree_git_events = vim.api.nvim_create_augroup('NeoTreeGitRefresh', { clear = true })
    local function fire_git_event()
      local ok, events = pcall(require, 'neo-tree.events')
      if ok then
        events.fire_event(events.GIT_EVENT)
      end
    end

    -- Refresh after returning to Neo-tree until upstream supports git-common-dir.
    vim.api.nvim_create_autocmd({ 'FocusGained', 'TabEnter' }, {
      group = neo_tree_git_events,
      callback = fire_git_event,
    })

    vim.cmd [[
      hi NeoTreeNormal guibg=NONE ctermbg=NONE
      hi NeoTreeNormalNC guibg=NONE ctermbg=NONE
      hi NeoTreeSignColumn guibg=NONE ctermbg=NONE
    ]]
    vim.api.nvim_set_hl(0, 'NeoTreeDotfile', { link = 'Comment' })
  end,
}
