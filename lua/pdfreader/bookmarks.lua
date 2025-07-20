local utils = require("pdfreader.utils")
local Image = require("pdfreader.image")

---@alias page_number number

---@class pdfreader.Bookmark
---@field page_number page_number
---@field comment? string
---@field cover filepath
local Bookmark = {}
Bookmark.__index = Bookmark

Bookmark.get_covers_dir = function()
	return vim.fn.stdpath("data") .. "/pdfreader/covers/bookmarks"
end

---@param page_number page_number
---@param comment? string
---@param filepath filepath
---@param book_id string
---@param last_page_number page_number
---@param config pdfreader.Options
---@return pdfreader.Bookmark
function Bookmark.new(page_number, comment, filepath, book_id, last_page_number, config)
	local self = setmetatable({}, Bookmark)
	self.page_number = page_number
	self.comment = comment
	self.cover = utils.convert_pdf_to_png(
		self:get_input_filepath(filepath, last_page_number),
		self:get_output_filepath(book_id),
		config
	)
	return self
end

---@param args string
---@return {page_number: number|nil, comment: string|nil}
function Bookmark.parse_bookmark_args(args)
	local words = vim.fn.split(args)
	local page_number = words[1] and tonumber(words[1]) or nil
	local start_idx = page_number and 2 or 1
	local comment_words = vim.list_slice(words, start_idx)
	local comment = #comment_words > 0 and vim.fn.join(comment_words) or nil
	return { page_number = page_number, comment = comment }
end

---@param filepath filepath
---@param last_page_number page_number
---@return string
function Bookmark:get_input_filepath(filepath, last_page_number)
	local page_number = utils.get_actual_page_number(self.page_number, last_page_number)
	return string.format("%s[%s]", filepath, page_number)
end

---@param book_id string
---@return string
function Bookmark:get_output_filepath(book_id)
	local data_dir = string.format("%s/%s", self.get_covers_dir(), book_id)
	vim.fn.mkdir(data_dir, "p")
	return string.format("%s/%s.png", data_dir, self.page_number)
end

---@param buffer number
---@param opts pdfreader.Options
function Bookmark:display_cover(buffer, opts)
	local cover_image = Image.new(self.cover, opts)
	cover_image:display(buffer)
end

function Bookmark:to_ql_format(buffer, filepath)
	return {
		bufnr = buffer,
		module = "Page",
		text = self.comment,
		lnum = self.page_number,
		user_data = { filepath = filepath },
	}
end

return Bookmark
