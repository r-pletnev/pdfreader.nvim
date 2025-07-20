local Page = require("pdfreader.pages.base")
local utils = require("pdfreader.utils")

---@class pdfreader.TextPage : pdfreader.Page
---@field text string
local TextPage = setmetatable({}, { __index = Page })
TextPage.__index = TextPage

---@param filepath filepath
---@param page_number page_number
---@param opts pdfreader.Options
---@return pdfreader.TextPage
function TextPage:new(filepath, page_number, opts)
	local instance = setmetatable({}, TextPage)
	local text = utils.convert_pdf_to_text(filepath, page_number)
	instance.text = text
	instance.color_mode = opts.mode
	instance.page_number = page_number
	return instance
end

---@param text string
---@param page_number page_number
---@param opts pdfreader.Options
---@return pdfreader.TextPage
function TextPage:from_dump(text, page_number, opts)
	local instance = setmetatable({}, TextPage)
	instance.text = text
	instance.color_mode = opts.mode
	instance.page_number = page_number
	return instance
end

---@param buffer number
---@param scale number
function TextPage:render(buffer, scale)
	vim.bo[buffer].modifiable = true
	vim.bo[buffer].modified = true

	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {})
	local lines = vim.fn.split(self.text, "\n")
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)

	vim.bo[buffer].modifiable = false
	vim.bo[buffer].modified = false
end

return TextPage
