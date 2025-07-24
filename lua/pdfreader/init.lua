local State = require("pdfreader.state")
local Bookmarks = require("pdfreader.bookmarks")
local commands = require("pdfreader.commands")

local M = {}

local group = vim.api.nvim_create_augroup("pdfreader.nvim", { clear = true })

M.setup = function(opts)
	local opts = opts or State.default_options
	local state = State.new(opts)
	state:load()

	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*.pdf",
		group = group,
		callback = function()
			state:validate()
			local buffer = vim.api.nvim_get_current_buf()
			local book = state:get_book_from_buffer_var(buffer)
			if book then
				book:display_page(buffer, nil, state.opts)
			end

			vim.keymap.set("n", "n", function()
				state:get_next_page(buffer)
			end, { buffer = buffer, desc = "Get next page" })

			vim.keymap.set("n", "p", function()
				state:get_prev_page(buffer)
			end, { buffer = buffer, desc = "Get previous page" })

			vim.keymap.set("n", "z", function()
				local book = state:get_book_from_buffer_var(buffer)
				if book == nil then
					return
				end
				book:zoom_in(5)
				book:display_page(buffer, nil, state.opts)
			end, { buffer = buffer, desc = "Zoom in" })

			vim.keymap.set("n", "q", function()
				local book = state:get_book_from_buffer_var(buffer)
				if book == nil then
					return
				end
				book:zoom_out(5)
				book:display_page(buffer, nil, state.opts)
			end, { buffer = buffer, desc = "Zoom out" })

			vim.keymap.set("n", "e", function()
				local book = state:get_book_from_buffer_var(buffer)
				if book == nil then
					return
				end
				book:zoom_reset()
				book:display_page(buffer, nil, state.opts)
			end, { buffer = buffer, desc = "Zoom reset" })
		end,
	})
	vim.api.nvim_create_autocmd({ "BufWriteCmd", "BufWritePre", "BufWritePost", "FileWritePre", "FileWritePost" }, {
		pattern = "*.pdf",
		group = group,
		callback = function()
			state:dump()
		end,
	})

	vim.api.nvim_create_user_command("PDFReader", commands.get_root_cmd(state), {
		nargs = "+",
		desc = "PDFReader command with subcommands completion",
		complete = commands.get_root_cmd_completion_function(),
		bang = false,
	})
end

return M
