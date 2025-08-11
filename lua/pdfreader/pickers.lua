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

				return true
			end,
		})
		:find()
end

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
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry().value
					local filepath = selection.user_data.filepath
					show_page(filepath)
				end)
				return true
			end,
		})
		:find()
end

---@param book_title string
---@param outlines pdfreader.OutlineNode[]
---@param show_page fun(page_number: integer) Callback that receives selected page number from ToC
M.telescope_toc_picker = function(book_title, outlines, show_page)
	local function flatten_outlines(nodes, depth)
		local items = {}
		depth = depth or 0
		for _, node in ipairs(nodes) do
			local item = {
				text = node.text,
				user_data = node.user_data,
				depth = depth,
				children = node.user_data.children
			}
			table.insert(items, item)
			if node.user_data.children and #node.user_data.children > 0 then
				local child_items = flatten_outlines(node.user_data.children, depth + 1)
				vim.list_extend(items, child_items)
			end
		end
		return items
	end

	pickers
		.new({}, {
			prompt_title = string.format("ToC of %s", book_title),
			finder = finders.new_table({
				results = flatten_outlines(outlines),
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

				return true
			end,
		})
		:find()
end

return M
