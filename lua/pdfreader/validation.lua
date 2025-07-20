local M = {}

M.is_kitty_term = function()
	if os.getenv("KITTY_WINDOW_ID") then
		return true
	end

	if os.getenv("TMUX") then
		local handle = io.popen("tmux show-environment -g KITTY_WINDOW_ID 2>/dev/null")
		if handle then
			local out = handle:read("*a")
			handle:close()
			if out and out:match("=") then
				return true
			end
		end
	end

	return false
end

-- check whether an external executable is available in $path.
--- @param cmd string   the program to look for.
--- @return boolean    when the command is found.
M.command_exits = function(cmd)
	if vim and vim.fn and vim.fn.executable then
		return vim.fn.executable(cmd) == 1
	end
	return false
end

local dependencies = {
	{
		command = "magick",
		message = "PDFReader DEPENDENCY MISING ERROR: 'magick' not found in $PATH. Please install ImageMagick.",
	},
	{
		command = "pdftotext",
		message = "PDFReader DEPENDENCY MISSING ERROR: 'pdftotext' not found in $PATH. Please install poppler-utils.",
	},
	{
		command = "pdfinfo",
		message = "PDFReader DEPENDENCY MISSING ERROR: 'pdfinfo' not found $PATH. Please install poppler-utils.",
	},
}

function M.check_depencencies()
	for _, dep in pairs(dependencies) do
		if not M.command_exits(dep.command) then
			vim.notify(dep.message, vim.log.levels.ERROR)
			return false
		end
	end
	return true
end

return M
