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
  {
    'nickjvandyke/opencode.nvim',
    version = '*',
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    config = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        server = {
          url = nil, -- Use process discovery (CWD match + latest-first auto-connect)
        },
      }

      -- Auto-connect on startup: discover opencode server via CWD match, pick latest
      vim.api.nvim_create_autocmd('VimEnter', {
        group = vim.api.nvim_create_augroup('OpencodeConnect', { clear = true }),
        callback = function()
          vim.schedule(function()
            pcall(function()
              local process = require('opencode.server.discovery.process')
              local server_mod = require('opencode.server')

              local processes = process.get()
              if #processes == 0 then return end

              local nvim_cwd = vim.fn.getcwd()
              local candidates = {}

              for _, p in ipairs(processes) do
                local cwd = vim
                  .fn.system('lsof -a -d cwd -p ' .. p.pid .. ' -Fn 2>/dev/null')
                  :match('n([^\n]+)')
                if cwd then
                  cwd = vim.trim(cwd)
                  if
                    cwd:find(nvim_cwd, 1, true) == 1
                    or nvim_cwd:find(cwd, 1, true) == 1
                  then
                    local etime_str = vim.trim(
                      vim.fn.system('ps -o etime= -p ' .. p.pid .. ' 2>/dev/null')
                        or ''
                    )
                    candidates[#candidates + 1] = {
                      port = p.port,
                      etime_str = etime_str,
                    }
                  end
                end
              end

              if #candidates == 0 then return end

              local function etime_to_sec(s)
                if s == '' then return 0 end
                local d, h, m, sec = s:match('(%d+)%-(%d+):(%d+):(%d+)')
                if d then
                  return tonumber(d) * 86400 + tonumber(h) * 3600 + tonumber(m) * 60
                    + tonumber(sec)
                end
                h, m, sec = s:match('(%d+):(%d+):(%d+)')
                if h then
                  return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)
                end
                m, sec = s:match('(%d+):(%d+)')
                if m then return tonumber(m) * 60 + tonumber(sec) end
                return 0
              end

              table.sort(candidates, function(a, b)
                return etime_to_sec(a.etime_str) < etime_to_sec(b.etime_str)
              end)

              server_mod.new('http://localhost:' .. candidates[1].port):next(function(server)
                server:connect():catch(function(err)
                  if err then
                    vim.notify(
                      'opencode connect: ' .. tostring(err),
                      vim.log.levels.WARN,
                      { title = 'opencode' }
                    )
                  end
                end)
              end)
            end)
          end)
        end,
      })

      -- Auto-reload + refresh Neo-tree when opencode edits files
      vim.api.nvim_create_autocmd('User', {
        pattern = 'OpencodeEvent:file.edited',
        callback = function()
          pcall(function()
            require('neo-tree.sources.manager').refresh('filesystem')
          end)
        end,
      })

      -- Preserve native increment/decrement (<C-a>/<C-x> are used by opencode.nvim)
      vim.keymap.set('n', '+', '<C-a>', { desc = 'Increment under cursor' })
      vim.keymap.set('n', '-', '<C-x>', { desc = 'Decrement under cursor' })

      -- opencode keymaps
      vim.keymap.set({ 'n', 'x' }, '<C-a>', function()
        require('opencode').ask('@this: ', { submit = true })
      end, { desc = 'Ask opencode about selection' })

      vim.keymap.set({ 'n', 'x' }, '<C-x>', function()
        require('opencode').select()
      end, { desc = 'Select opencode action' })

      vim.keymap.set({ 'n', 't' }, '<C-.>', function()
        require('opencode').toggle()
      end, { desc = 'Toggle opencode' })
    end,
  },
}
