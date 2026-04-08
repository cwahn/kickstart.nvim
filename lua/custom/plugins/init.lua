-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

---@module 'lazy'
---@type LazySpec
return {
  {
    'mrcjkb/rustaceanvim',
    version = '^6', -- Recommended
    lazy = false, -- This plugin is already lazy
  },
  {
    'mfussenegger/nvim-dap',
  },
  {
    'github/copilot.vim',
    event = 'InsertEnter',
    cmd = 'Copilot',
    init = function()
      -- Disable default <Tab> map to avoid conflict with blink.cmp
      vim.g.copilot_no_tab_map = true
    end,
    config = function()
      -- <C-J>          accept full suggestion  (official docs example)
      -- <C-L>          accept next word        (insert mode only; no conflict with <C-l> window nav which is normal mode)
      -- <M-]> / <M-[>  next / previous         (copilot.vim defaults, require option_as_alt in alacritty)
      -- <C-]>          dismiss                 (copilot.vim default)
      -- <M-\>          explicit trigger        (copilot.vim default)
      vim.keymap.set('i', '<C-J>', 'copilot#Accept("")', { expr = true, replace_keycodes = false, desc = 'Copilot: accept suggestion' })
      vim.keymap.set('i', '<C-L>', '<Plug>(copilot-accept-word)', { desc = 'Copilot: accept next word' })
    end,
  },
}
