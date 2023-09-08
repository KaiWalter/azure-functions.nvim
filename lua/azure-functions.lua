local M = {
  buffer_number = nil,
  window_number = nil,
  job_id = nil,
}

M.setup = function(opts)
  vim.api.nvim_create_user_command('FuncRun', M.start, {})
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
    vim.api.nvim_buf_set_option(M.buffer_number, "modifiable", true)
    vim.api.nvim_buf_set_lines(M.buffer_number, -1, -1, true, data)
    scroll_to_end(M.buffer_number)
    vim.api.nvim_buf_set_option(M.buffer_number, "modifiable", false)
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
    vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
      buffer = M.buffer_number,
      callback = M.close_logging
    })
  end
end

M.close_logging = function()
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

return M
