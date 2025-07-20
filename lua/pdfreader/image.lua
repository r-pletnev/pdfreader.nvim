local api = require("snacks.image")

---@class pdfreader.Image
---@field src string
---@field mode mode
local Image = {}
Image.__index = Image
Image.DEFAULT_SCALE = 60

---render image via api
---@param buffer any
---@param filepath any
---@param scale? number
local function api_render_image(buffer, filepath, scale)
	local opts = { auto_resize = nil }
	if scale then
		opts.height = scale
	end
	api.placement.new(buffer, filepath, opts)

	vim.bo[buffer].modifiable = true
	vim.bo[buffer].modified = true
	vim.api.nvim_buf_set_lines(buffer, -1, -1, false, { "" })
	vim.bo[buffer].modifiable = false
	vim.bo[buffer].modified = false
end

local function api_delete_image(buffer)
	api.placement.clean(buffer)
end

---@param src string
---@param opts? pdfreader.Options
---@return pdfreader.Image
function Image.new(src, opts)
	local opts = opts or { mode = 0 }
	local self = setmetatable({}, Image)
	self.src = src
	self.mode = opts.mode
	return self
end

---
---@param buffer number
---@param scale? number
function Image:display(buffer, scale)
	local scale = scale or Image.DEFAULT_SCALE
	api_render_image(buffer, self.src, scale)
end

---@param buffer number
function Image:remove(buffer)
	api_delete_image(buffer)
end

return Image
