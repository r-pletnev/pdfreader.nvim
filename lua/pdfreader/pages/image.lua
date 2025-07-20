local Page = require("pdfreader.pages.base")
local utils = require("pdfreader.utils")
local Image = require("pdfreader.image")

---@class pdfreader.ImagePage : pdfreader.Page
---@field image pdfreader.Image
local ImagePage = setmetatable({}, { __index = Page })
ImagePage.__index = ImagePage

---@param filepath filepath
---@param page_number page_number
---@param opts pdfreader.Options
---@return pdfreader.ImagePage
function ImagePage:new(filepath, page_number, opts)
	local instance = setmetatable(self, ImagePage)
	local src =
		utils.convert_pdf_to_png(self.get_input_filepath(filepath, page_number), self.get_output_filepath(), opts)
	instance.image = Image.new(src, opts)
	instance.color_mode = opts.mode
	instance.page_number = page_number
	return instance
end

---@param src filetype
---@param page_number page_number
---@param opts pdfreader.Options
---@return pdfreader.ImagePage
function ImagePage:from_dump(src, page_number, opts)
	local instance = setmetatable(self, ImagePage)
	--TODO: Add check for file exists
	instance.image = Image.new(src, opts)
	instance.color_mode = opts.mode
	instance.page_number = page_number
	return instance
end

---@param filepath filepath
---@param page_number page_number
---@return string
function ImagePage.get_input_filepath(filepath, page_number)
	local page_number = math.max(0, page_number - 1)
	return string.format("%s[%s]", filepath, page_number)
end

---@return string
function ImagePage.get_output_filepath()
	return string.format("%s.png", vim.fn.tempname())
end

---@param buffer number
---@param scale? number
function ImagePage:render(buffer, scale)
	self.image:display(buffer, scale)
end

function ImagePage:remove(buffer)
	self.image:remove(buffer)
end

return ImagePage
