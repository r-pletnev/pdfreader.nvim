local pickers = require("pdfreader.pickers")
local Book = require("pdfreader.book")
local Bookmark = require("pdfreader.bookmarks")
local validation = require("pdfreader.validation")
local utils = require("pdfreader.utils")

local function get_data_dir()
	return vim.fn.stdpath("data") .. "/pdfreader/data"
end

---@class pdfreader.Options
---@field mode mode
---@field autosave boolean

---@alias filepath string
---@class pdfreader.State
---@field books table<string,pdfreader.Book>
---@field opts pdfreader.Options
local State = {}
State.__index = State

State.default_options = {
	mode = utils.VIEW_MODES.normal,
	autosave = true,
}

---@param opts pdfreader.Options
---@return pdfreader.State
function State.new(opts)
	local self = setmetatable({}, State)
	local opts = opts or State.default_options
	self.books = {}
	self.opts = opts
	return self
end

function State:validate()
	validation.check_depencencies()
	if not validation.is_kitty_term() then
		vim.notify(
			"PDFReader DEPENDENCY MISSING ERROR: kitty terminal is require for image rendering - works only in text mode",
			vim.log.levels.WARN
		)
		self:set_mode(utils.VIEW_MODES.text)
	end
end

---@param filepath filepath
---@return pdfreader.Book
function State:add_book(filepath)
	local book = Book.new(filepath)
	self.books[filepath] = book
	return book
end

---@param filepath filepath
---@return pdfreader.Book|nil
function State:get_book(filepath)
	return self.books[filepath]
end

---Try to find book by buffer, then try to find book by filename, otherwise this a
--- new book
---@param filepath filepath
---@return pdfreader.Book
function State:get_or_create_book(filepath)
	local book = self:get_book(filepath)
	if book == nil then
		book = self:add_book(filepath)
	end
	return book
end

---@param mode mode
function State:set_mode(mode)
	self.opts.mode = mode
	self:dump()
end

function State:dump()
	local data_dir = get_data_dir()
	vim.fn.mkdir(data_dir, "p")
	local filepath = data_dir .. "/data.json"
	local state = { opts = self.opts, books = {} }
	for _, b in pairs(self.books) do
		local book = b:dump()
		state.books[b.filepath] = book
	end
	local ok = utils.to_json(state, filepath)
	if not ok then
		if not ok then
			vim.notify(string.format("PDFReader: failed to write state to %s", filepath), vim.log.levels.ERROR)
		end
	end
end

local function get_state_filepath()
	local data_dir = get_data_dir()
	if vim.fn.isdirectory(data_dir) == 0 then
		local ok, err = pcall(vim.fn.mkdir, data_dir, "p")
		if not ok then
			vim.notify("PDFReader: data directory can not be create", vim.log.levels.ERROR)
			vim.notify(string.format("Error: %s", err), vim.log.levels.ERROR)
		end

		return nil
	end
	local filepath = data_dir .. "/data.json"
	if not vim.fn.filereadable(filepath) then
		return nil
	end
	return filepath
end

function State:load()
	local filepath = get_state_filepath()
	if filepath == nil then
		return
	end
	local restored = utils.from_json(filepath)
	if restored then
		self.opts = restored.opts
		self.books = restored.books
		for _, book in pairs(self.books) do
			setmetatable(book, Book)
			book.pages = {}
			for key, bookmark in pairs(book.bookmarks) do
				book[key] = setmetatable(bookmark, Bookmark)
			end
		end
	end
end

function State:clear()
	local filepath = get_state_filepath()
	if filepath then
		vim.fn.delete(filepath)

		local covers_dir = Bookmark.get_covers_dir()
		vim.fn.delete(covers_dir, "rf")
	end
end

---@param book pdfreader.Book
---@param page_number page_number
---@param comment? string
function State:add_bookmark(book, page_number, comment)
	book:add_bookmark(page_number, comment, self.opts)
	self:dump()
end

function State:delete_bookmark(book, page_number)
	book:delete_bookmark(page_number)
	self:dump()
end

function State:get_books(buffer)
	local books = {}
	for _, book in pairs(self.books) do
		table.insert(books, book:to_ql_format(buffer))
	end
	return books
end

--#region telescope picker_functions

---Show bookmarks if the search for the book by filepath was successful
---@param buffer number
---@param filepath filepath
function State:show_bookmarks(buffer, filepath)
	local book = self:get_book(filepath)
	if book == nil then
		vim.notify(string.format("Book not found in buffer, filepath: %s", filepath), vim.log.levels.ERROR)
		return
	end
	local bookmarks = book:get_bookmarks(buffer)
	pickers.telescope_bookmark_picker(book.filename, bookmarks, function(page_number)
		book:display_page(buffer, page_number, self.opts)
	end, function(page_number)
		self:delete_bookmark(book, page_number)
	end, function()
		self:show_bookmarks(buffer, filepath)
	end, function(preview_buffer, page_number)
		local bookmark = book:get_bookmark(page_number)
		if bookmark then
			bookmark:display_cover(preview_buffer, self.opts)
		end
	end)
end

---@param buffer number
function State:show_recent_books(buffer)
	pickers.telescope_recent_books_picker(self:get_books(buffer), function(preview_buffer, filepath)
		local book = self:get_book(filepath)
		if book then
			book:display_cover(preview_buffer)
		end
	end, function(filepath)
		local book = self:get_book(filepath)
		if book then
			local bufnr = vim.fn.bufadd(filepath)
			book:save_to_buf_var(bufnr)
			vim.fn.bufload(bufnr)
			vim.api.nvim_win_set_buf(0, bufnr)
		end
	end)
end

---show table of content of current book in telescope picker
---@param buffer number
function State:show_toc(buffer, filename)
	local book = self:get_book_from_buffer_var(buffer)
	if book == nil then
		return
	end

	local outlines = book:get_outlines(buffer)
	if outlines then
		pickers.telescope_toc_picker(book.filename, outlines, function(filepath) end)
	end
end

--#endregion picker_functions

---Redraw book page on the current buffer
---@param filepath filepath
function State:redraw(filepath)
	local book = self:get_book(filepath)
	if book == nil then
		return
	end
	local bufnr = vim.fn.bufadd(filepath)
	vim.fn.bufload(bufnr)
	vim.api.nvim_win_set_buf(0, bufnr)
	book:display_page(bufnr, nil, self.opts)
end

---@param buffer number
---@return pdfreader.Book|nil
function State:get_book_from_buffer_var(buffer)
	local filepath = Book.get_book_filepath_from_buf_var(buffer)
	if filepath == nil then
		filepath = vim.fn.expand("%:p")
	end
	if filepath == nil or filepath == "" then
		return nil
	end
	local book = self:get_or_create_book(filepath)
	if book == nil then
		vim.notify("PDFReader: Book not found in current buffer", vim.log.levels.ERROR)
	end
	return book
end

---@param buffer number
function State:get_next_page(buffer)
	local book = self:get_book_from_buffer_var(buffer)
	if book == nil then
		return
	end
	book:get_next_page(self.opts)
	book:display_page(buffer, nil, self.opts)
	if self.opts.autosave then
		vim.schedule(function()
			self:dump()
		end)
	end
end

---@param buffer number
function State:get_prev_page(buffer)
	local book = self:get_book_from_buffer_var(buffer)
	if book == nil then
		return
	end
	book:get_prev_page(self.opts)
	book:display_page(buffer, nil, self.opts)
	if self.opts.autosave then
		vim.schedule(function()
			self:dump()
		end)
	end
end

---@param buffer number
---@param page_number page_number
function State:get_page_by_number(buffer, page_number)
	local book = self:get_book_from_buffer_var(buffer)
	if book == nil then
		return
	end
	book:display_page(buffer, page_number, self.opts)
	if self.opts.autosave then
		vim.schedule(function()
			self:dump()
		end)
	end
end

---@param autosave boolean
function State:set_autosave_mode(autosave)
	self.opts.autosave = autosave
	self:dump()
end

return State
