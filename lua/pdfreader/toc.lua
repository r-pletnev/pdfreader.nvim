---@param s string
---@return string
local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

---@class pdfreader.OutlineNode
---@field title string -- title
---@field page page_number
---@field children? pdfreader.OutlineNode[] -- nested outline structured
local OutlineNode = {}
OutlineNode.__index = OutlineNode

---@param title string
---@param page page_number
---@param children? pdfreader.OutlineNode
---@return pdfreader.OutlineNode
function OutlineNode.new(title, page, children)
	local instance = {
		title = title,
		page = page,
	}
	if children then
		instance.children = children
	end
	instance = setmetatable(instance, OutlineNode)
	return instance
end

function OutlineNode:to_ql_format(buffer, filepath)
	local children = {}
	if self.children ~= nil then
		for _, child in ipairs(self.children) do
			table.insert(children, child:to_ql_format(buffer, filepath))
		end
	end
	return {
		bufnr = buffer,
		module = "Outline",
		text = self.title,
		user_data = {
			filepath = filepath,
			page_number = self.page,
			children = children,
		},
	}
end

---@param txt string
---@param i number -- current byte index
---@return pdfreader.OutlineNode[]
---@return number
local function walk(txt, i)
	local out = {}

	while true do
		local open, close, tag = txt:find("<([^>]+)>", i)
		if not open then
			break
		end

		if tag == "/outline" then
			return out, close + 1
		end

		if tag:match("^item%s") then
			local page = tonumber(tag:match('page="(%d+)"')) or 0
			local t1 = close + 1 -- title start
			local t2 = txt:find("</item>", t1, true) - 1
			local title = trim(txt:sub(t1, t2))
			local node = OutlineNode.new(title, page)

			i = t2 + #"</item>" + 1 -- move past </item>

			-- immediately following outline?
			local next_open, next_close, next_tag = txt:find("<([^>]+)>", i)
			if next_tag == "outline" then
				node.children, i = walk(txt, next_close + 1)
			end

			out[#out + 1] = node
		elseif tag == "outline" then
			local child, new_i = walk(txt, close + 1)
			for _, v in ipairs(child) do
				out[#out + 1] = v
			end
			i = new_i
		else
			i = close + 1 -- skip unknown tag
		end
	end
	return out, #txt + 1
end

---@param text string
---@return pdfreader.OutlineNode[]
function OutlineNode.parse(text)
	local start = text:find("<outline>")
	if not start then
		return {}
	end
	local result, _ = walk(text, start + #"<outline>")
	return result
end

return OutlineNode
