local M = {
	buffer_number = nil, -- maintain ID of buffer for Function Host Log
	window_number = nil, -- maintain ID of window for Function Host Log
	job_id = nil, -- maintain ID of job that has been started for Function Host
	process_id = nil, -- maintain ID of dotnet isolated process extracted from log
}

local default_opts = {
	compress_log = true,
}

M.scroll_to_end = function()
	if M.buffer_number then
		local cur_win = vim.api.nvim_get_current_win()

		-- switch to buf and set cursor
		vim.api.nvim_buf_call(M.buffer_number, function()
			local target_win = vim.api.nvim_get_current_win()
			vim.api.nvim_set_current_win(target_win)

			local target_line = vim.tbl_count(vim.api.nvim_buf_get_lines(0, 0, -1, true))
			vim.api.nvim_win_set_cursor(target_win, { target_line, 0 })
		end)

		-- return to original window
		vim.api.nvim_set_current_win(cur_win)
	end
end

local start_debugger = function(process_id)
	require("dap").run({
		type = "coreclr",
		name = "attach Azure Function",
		request = "attach",
		processId = process_id,
	}, {
		filetype = "cs",
		new = true,
	})
end

local log = function(_, data)
	if data and M.buffer_number then
		local output_lines = {}
		for _, v in pairs(data) do
			local process_id = tonumber(v:match("PID: ([0-9]+)"))
			if process_id then
				M.process_id = process_id
				start_debugger(process_id)
			end

			if M.config.compress_log then
				if v ~= "" then
					table.insert(output_lines, v)
				end
			else
				table.insert(output_lines, v)
			end
		end
		vim.api.nvim_buf_set_option(M.buffer_number, "modifiable", true)
		vim.api.nvim_buf_set_lines(M.buffer_number, -1, -1, true, output_lines)
		vim.api.nvim_buf_set_option(M.buffer_number, "modifiable", false)
		-- scroll_to_end(M.buffer_number)
	end
end

M.open_logging = function()
	local cur_win = vim.api.nvim_get_current_win()
	if not M.window_number then
		M.buffer_number = nil
	end
	if not M.buffer_number then
		vim.api.nvim_command("botright new")
		M.window_number = vim.api.nvim_get_current_win()
		vim.api.nvim_command("enew!")
		M.buffer_number = vim.api.nvim_get_current_buf()
		vim.api.nvim_create_autocmd({ "WinClosed" }, {
			group = vim.api.nvim_create_augroup("Azure-Functions", { clear = true }),
			buffer = M.buffer_number,
			callback = function(ev)
				M.close_logging()
			end,
		})
	end
	vim.api.nvim_set_current_win(cur_win)
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

	return true
end

M.start_logging = function()
	M.process_id = nil
	M.open_logging()
	vim.api.nvim_buf_set_lines(M.buffer_number, 0, -1, true, {})
	vim.api.nvim_buf_set_option(M.buffer_number, "modifiable", false)
end

-- ------------------------------------------------------
M.setup = function(opts)
	M.config = vim.tbl_deep_extend("force", default_opts, opts)

	vim.api.nvim_create_user_command("FuncRun", M.start_without_debug, {})
	vim.api.nvim_create_user_command("FuncDebug", M.start_with_debug, {})
	vim.api.nvim_create_user_command("FuncStop", M.stop, {})
	vim.api.nvim_create_user_command("FuncShowLog", M.scroll_to_end, {})
end

M.get_process_id = function()
	return M.process_id
end

M.stop = function()
	M.close_logging()
end

M.exit_job = function()
	M.job_id = nil
	M.close_logging()
end

M.start_without_debug = function()
	M.start_logging()
	M.job_id = vim.fn.jobstart({ "func", "host", "start" }, {
		on_stdout = log,
		on_stderr = log,
		on_exit = M.exit_job,
	})
end

M.start_with_debug = function()
	M.start_logging()
	M.job_id = vim.fn.jobstart({ "func", "host", "start", "--dotnet-isolated-debug" }, {
		on_stdout = log,
		on_stderr = log,
		on_exit = M.exit_job,
	})
end

return M
