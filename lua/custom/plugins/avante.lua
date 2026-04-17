---@module 'lazy'
---@type LazySpec
return {
  {
    -- copilot.lua is required by avante's copilot provider (copilot.vim handles inline completions)
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    opts = {
      suggestion = { enabled = false }, -- copilot.vim handles suggestions
      panel = { enabled = false },
    },
  },
  {
    'yetone/avante.nvim',
    build = 'make',
    event = 'VeryLazy',
    version = false,
    ---@module 'avante'
    ---@type avante.Config
    opts = {
      provider = 'copilot',
      mode = 'agentic',
    },
    config = function(_, opts)
      require('avante').setup(opts)
      -- Transparent background for Avante windows
      vim.api.nvim_set_hl(0, 'AvantePromptInput', { bg = 'NONE' })
      vim.api.nvim_set_hl(0, 'AvanteSidebarNormal', { bg = 'NONE' })
      vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'NONE' })
    end,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
      'zbirenbaum/copilot.lua',
      'Kaiser-Yang/blink-cmp-avante',
      {
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { 'markdown', 'Avante' },
        },
        ft = { 'markdown', 'Avante' },
      },
    },
    keys = {
      {
        '<leader>a+',
        function() require('avante.extensions.neo_tree').add_file() end,
        desc = 'Avante: add file (neo-tree)',
        ft = 'neo-tree',
      },
      {
        '<leader>a-',
        function() require('avante.extensions.neo_tree').remove_file() end,
        desc = 'Avante: remove file (neo-tree)',
        ft = 'neo-tree',
      },
    },
  },
}
