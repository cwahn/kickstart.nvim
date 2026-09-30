local M = {}

local api = vim.api
local namespace = api.nvim_create_namespace 'copilot-partial'
local states = {}

local function cursor(bufnr)
  local win = api.nvim_get_current_win()
  if api.nvim_win_get_buf(win) ~= bufnr then return end
  local pos = api.nvim_win_get_cursor(win)
  return pos[1] - 1, pos[2], win
end

local function clear(bufnr)
  local state = states[bufnr]
  if not state then return end
  states[bufnr] = nil
  if api.nvim_buf_is_valid(bufnr) then
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    if state.native_enabled then vim.lsp.inline_completion.enable(true, { bufnr = bufnr }) end
  end
end

local function show(state)
  local bufnr = state.bufnr
  api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  if state.remaining == '' then
    clear(bufnr)
    return
  end

  local lines = vim.split(state.remaining, '\n', { plain = true })
  local virt_lines = {}
  for i = 2, #lines do
    virt_lines[#virt_lines + 1] = { { lines[i], 'ComplHint' } }
  end
  api.nvim_buf_set_extmark(bufnr, namespace, state.row, state.col, {
    virt_text = { { lines[1], 'ComplHint' } },
    virt_lines = virt_lines,
    virt_text_pos = 'inline',
    hl_mode = 'combine',
  })
end

local function reconcile(bufnr)
  local state = states[bufnr]
  if not state then return end
  local row, col = cursor(bufnr)
  if row == nil or col == nil or row < state.row or (row == state.row and col < state.col) then
    clear(bufnr)
    return
  end

  local changed = table.concat(api.nvim_buf_get_text(bufnr, state.row, state.col, row, col, {}), '\n')
  local tick = vim.b[bufnr].changedtick
  if not vim.startswith(state.remaining, changed) or (changed == '' and tick ~= state.tick) or (changed ~= '' and tick == state.tick) then
    clear(bufnr)
    return
  end
  if changed ~= '' then
    state.remaining = state.remaining:sub(#changed + 1)
    state.accepted = state.accepted .. changed
    state.row, state.col = row, col
  end
  state.tick = tick
  show(state)
end

local group = api.nvim_create_augroup('copilot-partial', { clear = true })
api.nvim_create_autocmd({ 'TextChangedI', 'TextChangedP', 'CursorMovedI' }, {
  group = group,
  callback = function(event) reconcile(event.buf) end,
})
api.nvim_create_autocmd({ 'InsertLeave', 'BufLeave', 'BufWipeout' }, {
  group = group,
  callback = function(event) clear(event.buf) end,
})
api.nvim_create_autocmd('LspDetach', {
  group = group,
  callback = function(event)
    local state = states[event.buf]
    if state and state.client_id == event.data.client_id then clear(event.buf) end
  end,
})

local function next_part(text, kind)
  if kind == 'line' then
    local newline = text:find('\n', 1, true)
    return newline and text:sub(1, newline) or text
  end
  local _, start, finish = unpack(vim.fn.matchstrpos(text, [[\k\+]]))
  if start >= 0 then return text:sub(1, finish) end
  return vim.fn.strcharpart(text, 0, 1)
end

local function insert_at_cursor(bufnr, text)
  local row, col, win = cursor(bufnr)
  if row == nil or col == nil or win == nil then return end
  local lines = vim.split(text, '\n', { plain = true })
  api.nvim_buf_set_text(bufnr, row, col, row, col, lines)
  row = row + #lines - 1
  col = (#lines == 1 and col or 0) + #lines[#lines]
  api.nvim_win_set_cursor(win, { row + 1, col })
  return row, col
end

local function notify_partial(state)
  local client = state.client_id and vim.lsp.get_client_by_id(state.client_id)
  if not client or not state.original or not state.original.range then return end
  -- Copilot extends LSP with this notification; Neovim's method type lists only standard methods.
  local method = 'textDocument/didPartiallyAcceptCompletion'
  ---@cast method vim.lsp.protocol.Method.ClientToServer.Notification
  client:notify(method, {
    item = state.original,
    acceptedLength = vim.str_utfindex(state.accepted, 'utf-16'),
  })
end

local function finish(state)
  local client = state.client_id and vim.lsp.get_client_by_id(state.client_id)
  if client and state.command then client:exec_cmd(state.command, { bufnr = state.bufnr }) end
  clear(state.bufnr)
end

---Called by Neovim's on_accept hook; return nil after handling a partial accept ourselves.
function M.accept_item(item, kind)
  if type(item.insert_text) ~= 'string' then return item end
  local bufnr = api.nvim_get_current_buf()
  local row, col = cursor(bufnr)
  if row == nil or col == nil then return end

  local insert_text = item.insert_text:gsub('\r\n', '\n')
  local already_typed = ''
  if item.range then
    local start_row, start_col, end_row, end_col = item.range:to_extmark()
    -- Only insertions at the cursor can be partially accepted without replacing unrelated text.
    if start_row ~= row or end_row ~= row or end_col ~= col or start_col > col then return end
    already_typed = api.nvim_buf_get_text(bufnr, row, start_col, row, col, {})[1]
    if not vim.startswith(insert_text, already_typed) then return end
  end

  local remaining = insert_text:sub(#already_typed + 1)
  local part = next_part(remaining, kind)
  if part == '' then return item end
  if part == remaining then return item end

  local client = item.client_id and vim.lsp.get_client_by_id(item.client_id)
  local original
  if client then
    original = {
      insertText = item.insert_text,
      range = item.range and item.range:to_lsp(client.offset_encoding),
      command = item.command,
      filterText = item._filter_text,
    }
  end

  local native_enabled = vim.lsp.inline_completion.is_enabled { bufnr = bufnr }
  if native_enabled then vim.lsp.inline_completion.enable(false, { bufnr = bufnr }) end
  local new_row, new_col = insert_at_cursor(bufnr, part)
  local state = {
    bufnr = bufnr,
    client_id = item.client_id,
    command = item.command,
    original = original,
    accepted = already_typed .. part,
    remaining = remaining:sub(#part + 1),
    row = new_row,
    col = new_col,
    tick = vim.b[bufnr].changedtick,
    native_enabled = native_enabled,
  }
  states[bufnr] = state
  show(state)
  notify_partial(state)
end

function M.accept_part(kind)
  local bufnr = api.nvim_get_current_buf()
  if states[bufnr] then
    reconcile(bufnr)
    local state = states[bufnr]
    if not state then return false end
    vim.schedule(function()
      if states[bufnr] ~= state then return end
      local part = next_part(state.remaining, kind)
      local row, col = insert_at_cursor(bufnr, part)
      if not row then return clear(bufnr) end
      state.row, state.col = row, col
      state.remaining = state.remaining:sub(#part + 1)
      state.accepted = state.accepted .. part
      state.tick = vim.b[bufnr].changedtick
      if state.remaining == '' then
        finish(state)
      else
        show(state)
        notify_partial(state)
      end
    end)
    return true
  end

  return vim.lsp.inline_completion.get {
    on_accept = function(item) return M.accept_item(item, kind) end,
  }
end

function M.accept_all()
  local bufnr = api.nvim_get_current_buf()
  if states[bufnr] then
    reconcile(bufnr)
    local state = states[bufnr]
    if not state then return false end
    vim.schedule(function()
      if states[bufnr] ~= state then return end
      if insert_at_cursor(bufnr, state.remaining) then finish(state) end
    end)
    return true
  end
  return vim.lsp.inline_completion.get()
end

return M
