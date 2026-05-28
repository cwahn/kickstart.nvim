-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

---@module 'lazy'
---@type LazySpec
return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
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

    -- Refresh Neo-tree when Neovim regains focus (external edits, e.g. opencode)
    vim.api.nvim_create_autocmd({ 'VimResume', 'FocusGained' }, {
      desc = 'Refresh Neo-tree on focus',
      callback = function()
        pcall(function()
          require('neo-tree.sources.manager').refresh('filesystem')
        end)
      end,
    })

    -- Detect external file changes when the user pauses typing
    vim.api.nvim_create_autocmd('CursorHold', {
      desc = 'Check for external file changes on hold',
      callback = function()
        pcall(vim.cmd.checktime)
      end,
    })

    -- Reveal externally changed file in Neo-tree when checktime reloads it
    vim.api.nvim_create_autocmd('FileChangedShellPost', {
      desc = 'Reveal externally changed file in Neo-tree',
      callback = function(args)
        vim.schedule(function()
          local filepath = vim.api.nvim_buf_get_name(args.buf)
          if filepath == '' then return end
          pcall(function()
            require('neo-tree.command').execute({
              source = 'filesystem',
              action = 'show',
              reveal_file = filepath,
              reveal_force_cwd = true,
            })
          end)
        end)
      end,
    })

    vim.cmd [[
      hi NeoTreeNormal guibg=NONE ctermbg=NONE
      hi NeoTreeNormalNC guibg=NONE ctermbg=NONE
      hi NeoTreeSignColumn guibg=NONE ctermbg=NONE
    ]]
    vim.api.nvim_set_hl(0, 'NeoTreeDotfile', { link = 'Comment' })
  end,
}
