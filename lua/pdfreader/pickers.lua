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
						string.format("%s, page: %d", entry.user_data.filename, entry.user_data.current_page_number)
					return {
						value = entry,
						display = display,
						ordinal = display,
					}
				end,
			}),

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

return M
