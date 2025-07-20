local Image = require("pdfreader.image")
local utils = require("pdfreader.utils")

---@class pdfreader.Page
---@field page_number page_number
local Page = {}
Page.__index = Page

---@param buffer number
---@param scale? number
function Page:render(buffer, scale) end
function Page:remove(buffer) end
return Page
