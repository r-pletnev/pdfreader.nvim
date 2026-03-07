local M = {}

local telescope_ok = pcall(require, "telescope")
if not telescope_ok then
	local function warn()
		vim.notify("PDFReader: telescope.nvim is not installed. Pickers are disabled.", vim.log.levels.WARN)
	end

	M.telescope_bookmark_picker = warn
	M.telescope_recent_books_picker = warn
	M.telescope_toc_picker = warn

	return M
end

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values

M.telescope_bookmark_picker = function(
	filepath,
	title,
	bookmarks,
	show_current_page,
	delete_bookmark,
	show_bookmarks,
	display_cover
)
	pickers
		.new({}, {
			prompt_title = string.format("Bookmarks of %s", title),
			finder = finders.new_table({
				results = bookmarks,
				entry_maker = function(entry)
					local display = string.format("Page %d: Comment: %s", entry.lnum or 1, entry.text or "-")
					return {
						value = entry,
						display = display,
						ordinal = display,
					}
				end,
			}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry, _)
					local page_number = entry.value.lnum
					display_cover(self.state.bufnr, page_number)
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry().value
					local page_number = selection.lnum
					show_current_page(page_number)
				end)

				map("i", "<C-d>", function()
					local selection = action_state.get_selected_entry().value
					local page_number = selection.lnum
					delete_bookmark(page_number)
					actions.close(prompt_bufnr)
					vim.schedule(show_bookmarks) -- reload picker
				end)

				map("i", "<C-q>", function()
					local qf_items = vim.tbl_map(function(entry)
						return {
							filename = filepath,
							lnum = entry.lnum,
							text = entry.text or "-",
						}
					end, bookmarks)
					vim.fn.setqflist(qf_items)
					vim.cmd("copen")
					vim.api.nvim_buf_set_keymap(0, "n", "<CR>", "", {
						callback = function()
							local idx = vim.fn.line(".") - 1
							local items = vim.fn.getqflist({ items = true }).items
							local item = items[idx + 1]
							show_current_page(item.lnum)
						end,
						noremap = true,
						silent = true,
					})
				end)

				return true
			end,
		})
		:find()
end

---comment
---@param books pdfreader.Book[]
---@param display_preview fun(preview_buffer: integer, filepath: string) Callback shows book cover
---@param show_page fun(filepath: string) Callback opens particular book on the last page
M.telescope_recent_books_picker = function(books, display_preview, show_page)
	pickers
		.new({}, {
			prompt_title = "Recent books",
			finder = finders.new_table({
				results = books,
				entry_maker = function(entry)
					local display =
						string.format("%s; (page - %d)", entry.user_data.filename, entry.user_data.current_page_number)
					return {
						value = entry,
						display = display,
						ordinal = display,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry, _)
					local filepath = entry.value.user_data.filepath
					display_preview(self.state.bufnr, filepath)
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry().value
					local filepath = selection.user_data.filepath
					show_page(filepath)
				end)

				map("i", "<C-q>", function()
					local qf_items = vim.tbl_map(function(entry)
						return {
							filename = entry.user_data.filepath,
							lnum = entry.user_data.current_page_number,
							text = entry.user_data.filename,
							user_data = { filepath = entry.user_data.filepath },
						}
					end, books)
					vim.fn.setqflist(qf_items)
					vim.cmd("copen")
					vim.api.nvim_buf_set_keymap(0, "n", "<CR>", "", {
						callback = function()
							local idx = vim.fn.line(".") - 1
							local items = vim.fn.getqflist({ items = true }).items
							local item = items[idx + 1]
							show_page(item.user_data.filepath)
						end,
						noremap = true,
						silent = true,
					})
				end)

				return true
			end,
		})
		:find()
end

---@param filepath string
---@param book_title string
---@param outlines pdfreader.OutlineNode[]
---@param show_page fun(page_number: integer) Callback that receives selected page number from ToC
M.telescope_toc_picker = function(filepath, book_title, outlines, show_page)
	local function flatten_outlines(nodes, depth)
		local items = {}
		depth = depth or 0
		for _, node in ipairs(nodes) do
			local item = {
				text = node.text,
				user_data = node.user_data,
				depth = depth,
				children = node.user_data.children,
			}
			table.insert(items, item)
			if node.user_data.children and #node.user_data.children > 0 then
				local child_items = flatten_outlines(node.user_data.children, depth + 1)
				vim.list_extend(items, child_items)
			end
		end
		return items
	end

	local flattened_outlines = flatten_outlines(outlines)

	pickers
		.new({}, {
			prompt_title = string.format("ToC of %s", book_title),
			finder = finders.new_table({
				results = flattened_outlines,
				entry_maker = function(entry)
					local prefix = string.rep("  ", entry.depth)
					local display = string.format("%s- %s (page %d)", prefix, entry.text, entry.user_data.page_number)
					return {
						value = entry,
						display = display,
						ordinal = display,
						depth = entry.depth,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry().value
					show_page(selection.user_data.page_number)
				end)

				-- Add keyboard mapping to expand/collapse children
				map("i", "<CR>", function(_)
					local selection = action_state.get_selected_entry()
					if selection.value.children and #selection.value.children > 0 then
						-- Toggle children visibility
						-- This would need additional state management to persist toggle state
						-- Currently just shows full hierarchy by default
					end
					actions.select_default(prompt_bufnr)
				end)

				map("i", "<C-q>", function()
					local qf_items = vim.tbl_map(function(entry)
						return {
							filename = filepath,
							lnum = entry.user_data.page_number,
							text = entry.text,
						}
					end, flattened_outlines)
					vim.fn.setqflist(qf_items)
					vim.cmd("copen")
					vim.api.nvim_buf_set_keymap(0, "n", "<CR>", "", {
						callback = function()
							local idx = vim.fn.line(".") - 1
							local items = vim.fn.getqflist({ items = true }).items
							local item = items[idx + 1]
							show_page(item.lnum)
						end,
						noremap = true,
						silent = true,
					})
				end)

				return true
			end,
		})
		:find()
end

return M
