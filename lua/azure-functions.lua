local M = {
  buffer_number = nil,
  window_number = nil,
  job_id = nil,
}

P = function(v)
  print(vim.inspect(v))
  return v
end

local default_opts = {
  compress_log = true,
}

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", default_opts, opts)

  vim.api.nvim_create_user_command('FuncRun', M.start, {})
  vim.api.nvim_create_user_command('FuncDebug', M.start_with_debug, {})
end

local function scroll_to_end(bufnr)
  local cur_win = vim.api.nvim_get_current_win()

  -- switch to buf and set cursor
  vim.api.nvim_buf_call(bufnr, function()
    local target_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(target_win)

    local target_line = vim.tbl_count(vim.api.nvim_buf_get_lines(0, 0, -1, true))
    vim.api.nvim_win_set_cursor(target_win, { target_line, 0 })
  end)

  -- return to original window
  vim.api.nvim_set_current_win(cur_win)
end

local function log(_, data)
  if data and M.buffer_number then
    local output_lines = {}
    for _, v in pairs(data) do
      if M.config.compress_log then
        if v ~= '' then
          table.insert(output_lines, v)
        end
      else
        table.insert(output_lines, v)
      end
    end
    vim.api.nvim_buf_set_option(M.buffer_number, "modifiable", true)
    vim.api.nvim_buf_set_lines(M.buffer_number, -1, -1, true, output_lines)
    vim.api.nvim_buf_set_option(M.buffer_number, "modifiable", false)
    scroll_to_end(M.buffer_number)
  end
end

M.open_logging = function()
  if not M.window_number then
    M.buffer_number = nil
  end
  if not M.buffer_number then
    vim.api.nvim_command('botright new')
    M.window_number = vim.api.nvim_get_current_win()
    vim.api.nvim_command('enew!')
    M.buffer_number = vim.api.nvim_get_current_buf()
    vim.api.nvim_create_autocmd({ 'WinClosed' }, {
      group = vim.api.nvim_create_augroup('Azure-Functions', { clear = true }),
      buffer = M.buffer_number,
      callback = function(ev)
        -- print(vim.inspect(ev))
        M.close_logging()
      end
    })
  end
end

M.close_logging = function()
  -- print(M.job_id, M.window_number, M.buffer_number)
  if M.job_id then
    vim.fn.jobstop(M.job_id)
    M.job_id = nil
  end
  if M.window_number then
    vim.api.nvim_win_close(M.window_number, true)
    M.window_number = nil
  end
  if M.buffer_number then
    vim.api.nvim_buf_delete(M.buffer_number, { force = true })
    M.buffer_number = nil
  end
  return true
end

M.start_logging = function()
  M.open_logging()
  vim.api.nvim_buf_set_lines(M.buffer_number, 0, -1, true, {})
  vim.api.nvim_buf_set_option(M.buffer_number, "modifiable", false)
end

M.exit_job = function()
  M.job_id = nil
  M.close_logging()
end

M.start = function()
  M.start_logging()
  M.job_id = vim.fn.jobstart({ 'func', 'host', 'start' }, {
    on_stdout = log,
    on_stderr = log,
    on_exit = M.exit_job
  })
end

M.start_with_debug = function()
  M.start_logging()
  M.job_id = vim.fn.jobstart({ 'func', 'host', 'start', '--dotnet-isolated-debug' }, {
    on_stdout = log,
    on_stderr = log,
    on_exit = M.exit_job
  })
end

return M
