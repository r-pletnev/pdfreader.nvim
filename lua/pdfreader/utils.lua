local M = {}

---@enum mode
M.VIEW_MODES = {
	normal = 0,
	dark = 1,
	text = 2,
}

---@param input string
---@param output string
---@param mode mode
---@return table
local function get_magick_cmd_presets(input, output, mode)
	if mode == M.VIEW_MODES.dark then
		return {
			"magick",
			"-density",
			"200",
			input,
			"-alpha",
			"remove",
			"-colorspace",
			"Gray",
			"-negate",
			output,
		}
	else
		return {
			"magick",
			"-density",
			"200",
			input,
			"-alpha",
			"remove",
			output,
		}
	end
end

---@param cmd table
---@return vim.SystemCompleted
local function execute_system_command(cmd)
	local result = vim.system(cmd, { text = true }):wait()
	if result.code ~= 0 then
		vim.notify(result.stderr, vim.log.levels.ERROR)
	end
	return result
end

---convert pdf to png by magick
---@param input_filepath string
---@param output_filepath string
---@return string
M.convert_pdf_to_png = function(input_filepath, output_filepath, config)
	local cmd = get_magick_cmd_presets(input_filepath, output_filepath, config.mode)
	execute_system_command(cmd)
	return output_filepath
end

---convert pdf to text by pdftotext
---@param filepath filepath
---@param page_number page_number
---@return string
M.convert_pdf_to_text = function(filepath, page_number)
	local cmd = {
		"pdftotext",
		"-layout",
		"-f",
		page_number,
		"-l",
		page_number,
		filepath,
		"-",
	}
	local result = execute_system_command(cmd)
	if result.code == 0 then
		return result.stdout
	end
	return ""
end

---@param filepath filepath
---@param last_page_number page_number
---@return string|nil
M.parse_outlines_from_pdf = function(filepath, last_page_number)
	local cmd = {
		"pdftohtml",
		"-f",
		last_page_number,
		"-l",
		last_page_number,
		"-stdout",
		"-i",
		"-xml",
		filepath,
	}
	local result = execute_system_command(cmd)
	if result.code ~= 0 then
		return nil
	end
	return result.stdout
end

---@param current_page_number page_number
---@param last_page_number page_number
---@return page_number
M.get_actual_page_number = function(current_page_number, last_page_number)
	local page_number = math.max(0, current_page_number - 1)
	return math.min(page_number, last_page_number - 1)
end

M.generate_random_string = function()
	local ok, openssl = pcall(require, "openssl.rand")
	if ok and openssl then
		-- Generate 16 random bytes (128 bits)
		local raw = openssl.bytes(16)
		return (raw:gsub(".", function(c)
			return string.format("%02x", string.byte(c))
		end))
	end

	local urandom = io.open("/dev/urandom", "rb")
	if urandom then
		local raw = urandom:read(16)
		urandom:close()
		return (raw:gsub(".", function(c)
			return string.format("%02x", string.byte(c))
		end))
	end

	-- Fallback (⚠️ not secure, avoid for crypto)
	local function fallback_random_bytes(n)
		local t = {}
		for i = 1, n do
			table.insert(t, string.char(math.random(0, 255)))
		end
		return table.concat(t)
	end

	math.randomseed(os.time() + tonumber(tostring({}):sub(8), 16))
	local raw = fallback_random_bytes(16)
	return (raw:gsub(".", function(c)
		return string.format("%02x", string.byte(c))
	end))
end

--- Get number of pages in a PDF file using pdfinfo, fallback to ImageMagick identify
--- @param filepath string: absolute or relative path to PDF
--- @return integer|nil, string|nil: number of pages or nil, and error message if failed
M.get_pdf_page_count = function(filepath)
	-- First try pdfinfo
	local pdfinfo_result = vim.system({ "pdfinfo", filepath }, { text = true }):wait()
	if pdfinfo_result.code == 0 then
		for _, line in ipairs(vim.split(pdfinfo_result.stdout, "\n")) do
			local pages = line:match("^Pages:%s+(%d+)")
			if pages then
				return tonumber(pages)
			end
		end
	end

	-- Fallback: try ImageMagick identify
	local identify_result = vim.system({ "identify", filepath }, { text = true }):wait()
	if identify_result.code == 0 then
		local lines = vim.split(identify_result.stdout, "\n", { trimempty = true })
		if #lines > 0 then
			return #lines
		else
			return nil, "ImageMagick identify ran but returned no lines"
		end
	end

	return nil,
		"Failed to get page count: pdfinfo stderr:\n"
			.. (pdfinfo_result.stderr or "")
			.. "\nidentify stderr:\n"
			.. (identify_result.stderr or "")
end

M.to_json = function(obj, filepath)
	local ok, encoded = pcall(vim.json.encode, obj)
	if ok then
		local file = io.open(filepath, "w")
		if file then
			file:write(encoded)
			file:close()
			return true
		end
	end
	return false
end

M.from_json = function(filepath)
	local file = io.open(filepath, "r")
	if file then
		local encoded = file:read("*all")
		file:close()
		local ok, decoded = pcall(vim.json.decode, encoded)
		if ok then
			return decoded
		end
	end
	return nil
end

return M
