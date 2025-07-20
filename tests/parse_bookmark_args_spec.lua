---@diagnostic disable: undefined-field, undefined-global

local parse = require("pdfreader.bookmarks").parse_bookmark_args
local eq = assert.are.same

describe("pdfreader.bookmarks.parse_bookmark_args", function()
	it("should parse empty line", function()
		eq({
			page_number = nil,
			comment = nil,
		}, parse(""))
	end)

	it("should parse one number arg", function()
		eq({
			page_number = 1,
			comment = nil,
		}, parse("1"))
	end)

	it("should parse big number arg", function()
		eq({
			page_number = 16423,
			comment = nil,
		}, parse("16423"))
	end)

	it("should parse one string arg", function()
		eq({
			page_number = nil,
			comment = "test",
		}, parse("test"))
	end)

	it("should parse both number and string args", function()
		eq({
			page_number = 1,
			comment = "test",
		}, parse("1 test"))
	end)

	it("should parse multiply string args", function()
		eq({
			page_number = nil,
			comment = "test it",
		}, parse("test it"))
	end)

	it("should parse both number and multiply string args", function()
		eq({
			page_number = 1,
			comment = "test it here",
		}, parse("1 test it here"))
	end)

	it("should parse both number and multiply number args", function()
		eq({
			page_number = 1,
			comment = "1 test here",
		}, parse("1 1 test here"))
	end)

	it("should parse both big number and multiply number args", function()
		eq({
			page_number = 100500,
			comment = "1 test here",
		}, parse("100500 1 test here"))
	end)
end)
