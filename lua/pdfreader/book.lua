local utils = require("pdfreader.utils")
local Image = require("pdfreader.image") ---@type pdfreader.Image
local ImagePage = require("pdfreader.pages.image")
local TextPage = require("pdfreader.pages.text")
local Bookmark = require("pdfreader.bookmarks") ---@type pdfreader.Bookmark

---@alias datetime string|osdate

---@class pdfreader.Book
---@field id string
---@field pages table<string,pdfreader.Page>
---@field bookmarks table<string,pdfreader.Bookmark>
---@field scale? number
---@field filepath string: path to the PDF file
---@field filename string: filename (without extension)
---@field read_at datetime: timestamp of the last reading session
---@field current_page_number number: current page in pdf file (first page is 1)
---@field cover filepath
---@field number_of_pages number
---@field get_current_page fun(self:pdfreader.Book, opts?:pdfreader.Options): pdfreader.Page
---@field get_next_page fun(self:pdfreader.Book,  opts?:pdfreader.Options): pdfreader.Page
---@field get_prev_page fun(self:pdfreader.Book,  opts?:pdfreader.Options): pdfreader.Page
local Book = {}
Book.__index = Book

Book.get_covers_dir = function()
	return vim.fn.stdpath("data") .. "/pdfreader/covers/books"
end

---@param buffer number
---@return filepath|nil
function Book.get_book_filepath_from_buf_var(buffer)
	local ok, filepath = pcall(vim.api.nvim_buf_get_var, buffer, "book")
	if not ok then
		return nil
	end
	return filepath
end

---Create a new Book instance with the current page set on first page
---@param filepath filepath: The filepath of the pdf file
---@return pdfreader.Book
function Book.new(filepath)
	local current_page_number = 1
	local self = setmetatable({}, Book)
	self.id = utils.generate_random_string()
	self.filepath = filepath
	self.filename = vim.fn.fnamemodify(filepath, ":t:r")
	self.current_page_number = current_page_number
	self.pages = {}
	self.bookmarks = {}
	local number_of_pages = utils.get_pdf_page_count(filepath)
	if number_of_pages ~= nil then
		self.number_of_pages = number_of_pages
	end
	self.cover = utils.convert_pdf_to_png(
		self:get_input_filepath(1),
		self:get_output_filepath_cover(),
		{ mode = utils.VIEW_MODES.normal }
	)
	return self
end

---@return pdfreader.Book
function Book:dump()
	local pickle = {}
	for key, value in pairs(self) do
		pickle[key] = key == "pages" and {} or value
	end
	return pickle
end

---@param page_number page_number
---@return string
function Book:get_input_filepath(page_number)
	local page_number = math.max(0, page_number - 1)
	return string.format("%s[%s]", self.filepath, page_number)
end

---@return string
function Book:get_output_filepath_cover()
	local data_dir = string.format("%s/%s", self.get_covers_dir(), self.id)
	vim.fn.mkdir(data_dir, "p")
	return string.format("%s/cover.png", data_dir)
end

---@param page_number page_number
---@param opts pdfreader.Options
---@return pdfreader.Page
function Book:get_page(page_number, opts)
	local page = self.pages[tostring(page_number)]
	if opts.mode == utils.VIEW_MODES.text then
		page = TextPage:new(self.filepath, page_number, opts)
	else
		page = ImagePage:new(self.filepath, page_number, opts)
	end

	--TODO: Handle previous pages
	-- if page == nil or page.color_mode ~= opts.mode then
	-- 	if opts.mode == utils.VIEW_MODES.text then
	-- 		page = TextPage:new(self.filepath, page_number, opts)
	-- 	else
	-- 		page = ImagePage:new(self.filepath, page_number, opts)
	-- 	end
	-- else
	-- 	if opts.mode == utils.VIEW_MODES.text then
	-- 		page = TextPage:from_dump(page.text, page.page_number, opts)
	-- 	else
	-- 		page = ImagePage:from_dump(page.src, page.page_number, opts)
	-- 	end
	-- end
	self.pages[tostring(page_number)] = page
	return page
end

---@param opts pdfreader.Options
---@return pdfreader.ImagePage
function Book:get_current_page(opts)
	return assert(self:get_page(self.current_page_number, opts))
end

---@param opts pdfreader.Options
---@return pdfreader.ImagePage
function Book:get_next_page(opts)
	local next_page_number = self.current_page_number + 1
	next_page_number = math.min(self.number_of_pages, next_page_number)
	local next_page = assert(self:get_page(next_page_number, opts), "PDFreader: next page not found")
	self.current_page_number = next_page_number
	return next_page
end

---@param opts pdfreader.Options
---@return pdfreader.Image
function Book:get_prev_page(opts)
	local prev_page_number = math.max(1, self.current_page_number - 1)
	local prev_page = assert(self:get_page(prev_page_number, opts), "PDFreader: previous page not found")
	self.current_page_number = prev_page_number
	return prev_page
end

function Book:display_cover(buffer)
	local cover_image = Image.new(self.cover)
	cover_image:display(buffer)
end

---@param bufnr number
---@param page_number? number If nil will be use current page
---@param opts pdfreader.Options
function Book:display_page(bufnr, page_number, opts)
	self.read_at = os.date("%Y-%m-%d %H:%M:%S")
	local page_number = page_number or self.current_page_number
	if self.number_of_pages ~= nil then
		page_number = math.min(page_number, self.number_of_pages)
	end
	local page = self:get_page(page_number, opts)
	if page then
		self.current_page_number = page_number
		vim.schedule(function()
			page:render(bufnr, self.scale)
			self:show_statusline(bufnr, opts)
		end)
	end
end

---@param bufnr number
---@param opts pdfreader.Options
function Book:show_statusline(bufnr, opts)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if buf == bufnr then
			vim.api.nvim_set_option_value(
				"statusline",
				string.format(
					"Title: %s | Page: %s/%s | View Mode: %s",
					self.filename,
					self.current_page_number,
					self.number_of_pages,
					opts.mode == 0 and "standard" or opts.mode == 1 and "dark" or "text"
				),
				{
					win = win,
				}
			)
			--
		end
	end
end

function Book:zoom_in(scale_factor)
	local scale = self.scale or Image.DEFAULT_SCALE
	self.scale = scale + scale_factor
end

function Book:zoom_out(scale_factor)
	local scale = self.scale or Image.DEFAULT_SCALE
	self.scale = math.max(1, scale - scale_factor)
end

function Book:zoom_reset()
	self.scale = nil
end

---@param page_number page_number
---@param comment? string
---@param config pdfreader.Options
function Book:add_bookmark(page_number, comment, config)
	self.bookmarks[tostring(page_number)] =
		Bookmark.new(page_number, comment, self.filepath, self.id, self.number_of_pages, config)
end

---@param page_number page_number
function Book:delete_bookmark(page_number)
	self.bookmarks[tostring(page_number)] = nil
end

---@param page_number page_number
---@return pdfreader.Bookmark
function Book:get_bookmark(page_number)
	return self.bookmarks[tostring(page_number)]
end

function Book:get_bookmarks(buffer)
	local marks = {}
	for _, mark in pairs(self.bookmarks) do
		table.insert(marks, mark:to_ql_format(buffer, self.filepath))
	end
	return marks
end

function Book:to_ql_format(buffer)
	return {
		bufnr = buffer,
		module = "Book",
		user_data = {
			filename = self.filename,
			filepath = self.filepath,
			current_page_number = self.current_page_number,
		},
	}
end

function Book:save_to_buf_var(buffer)
	vim.api.nvim_buf_set_var(buffer, "book", self.filepath)
end

return Book
