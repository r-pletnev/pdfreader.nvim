--- The code in this file heavy inspired by https://github.com/nvim-neorocks/nvim-best-practices
local Bookmarks = require("pdfreader.bookmarks")

local M = {}

---@class pdfreader.Subcommand
---@field impl fun(state: pdfreader.State, args:string[], opts: table) The command implementation
---@field complete? fun(subcmd_arg_lead: string): string[] (optional) Command completions callback, taking the lead of the subcommand's arguments

---@param arg_lead string
---@param args string[]
local function completion_filter(arg_lead, args)
	return vim.iter(args)
		:filter(function(install_arg)
			return install_arg:find(arg_lead) ~= nil
		end)
		:totable()
end

---@type table<string, pdfreader.Subcommand>
local subcommand_tbl = {
	["setViewMode"] = {
		impl = function(state, args, _)
			local arg = args[1]
			if arg == "dark" then
				state:set_mode(1)
			elseif arg == "text" then
				state:set_mode(2)
			else
				state:set_mode(0)
			end
			local buffer = vim.api.nvim_get_current_buf()
			local book = state:get_book_from_buffer_var(buffer)
			if book then
				book:display_page(buffer, nil, state.opts)
			end
		end,
		complete = function(subcmd_arg_lead)
			return completion_filter(subcmd_arg_lead, {
				"dark",
				"standard",
				"text",
			})
		end,
	},
	["setAutosave"] = {
		impl = function(state, args, _)
			state:set_autosave_mode(args[1] == "on")
		end,
		complete = function(subcmd_arg_lead)
			return completion_filter(subcmd_arg_lead, {
				"on",
				"off",
			})
		end,
	},
	["setPage"] = {
		impl = function(state, args, _)
			local _, page_number = pcall(tonumber, args[1])
			if page_number then
				local buffer = vim.api.nvim_get_current_buf()
				state:get_page_by_number(buffer, page_number)
				return
			end
			vim.notify("PDFReader: setPage accept only numbers as argument", vim.log.levels.WARN)
		end,
	},
	["addBookmark"] = {
		impl = function(state, args, _)
			local filepath = vim.fn.expand("%:p")
			local result = Bookmarks.parse_bookmark_args(args[1])
			local number = result.page_number
			local comment = result.comment
			if number == nil and comment == nil then
				vim.notify("PDFReader: addBookmark require at least one argument", vim.log.levels.WARN)
				return
			end
			local book = state:get_book(filepath)
			if book then
				number = number and tonumber(number) or book.current_page_number
				state:add_bookmark(book, number, comment)
				vim.notify("PDFReader: Bookmark saved", vim.log.levels.INFO)
			end
		end,
	},

	["showBookmarks"] = {
		impl = function(state, args, _)
			local buffer = vim.api.nvim_get_current_buf()
			local filepath = vim.fn.expand("%:p")
			state:show_bookmarks(buffer, filepath)
		end,
	},

	["showRecentBooks"] = {
		impl = function(state, args, _)
			local buffer = vim.api.nvim_get_current_buf()
			state:show_recent_books(buffer)
		end,
	},

	["saveState"] = {
		impl = function(state, args, opts)
			state:dump()
		end,
	},

	["clearState"] = {
		impl = function(state, args, opts)
			state:clear()
		end,
	},

	["redrawPage"] = {
		impl = function(state, args, opts)
			local filepath = vim.fn.expand("%:p")
			state:redraw(filepath)
		end,
	},
	["showToc"] = {
		impl = function(state, args, opts)
			local buffer = vim.api.nvim_get_current_buf()
			state:show_toc(buffer)
		end,
	},
}

---@param state pdfreader.State
function M.get_root_cmd(state)
	---@param opts table :h lua-guide-commands-create
	return function(opts)
		local fargs = opts.fargs
		local subcommand_key = fargs[1]
		-- Get the subcommand's arguments, if any
		local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
		local subcommand = subcommand_tbl[subcommand_key]
		if not subcommand then
			vim.notify("PDFReader: Unknown command: " .. subcommand_key, vim.log.levels.ERROR)
			return
		end
		-- Invoke the subcommand
		subcommand.impl(state, args, opts)
	end
end

---@return fun(arg_lead:string, cmdline: string, _:any): string[]|nil
function M.get_root_cmd_completion_function()
	return function(arg_lead, cmdline, _)
		local subcmd_key, subcmd_arg_lead = cmdline:match("^['<,'>]*PDFReader[!]*%s(%S+)%s(.*)$")
		if subcmd_key and subcmd_arg_lead and subcommand_tbl[subcmd_key] and subcommand_tbl[subcmd_key].complete then
			-- The subcommand has completions. Return them.
			return subcommand_tbl[subcmd_key].complete(subcmd_arg_lead)
		end
		-- Check if cmdline is a subcommand
		if cmdline:match("^['<,'>]*PDFReader[!]*%s+%w*$") then
			-- Filter subcommands that match
			local subcommand_keys = vim.tbl_keys(subcommand_tbl)
			return completion_filter(arg_lead, subcommand_keys)
		end
	end
end

return M
