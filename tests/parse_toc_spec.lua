---@diagnostic disable: undefined-field, undefined-global

local OutlineNode = require("pdfreader.toc")
local same = assert.are.same
local eq = assert.are.equal

describe("pdfreader.toc.parse", function()
	it("parses a flat outline", function()
		local src = [[
      <outline>
        <item page="1">Cover</item>
        <item page="8">Table of Contents</item>
        <item page="18">Preface</item>
      </outline>
    ]]

		local expected = {
			{ title = "Cover", page = 1 },
			{ title = "Table of Contents", page = 8 },
			{ title = "Preface", page = 18 },
		}

		same(expected, OutlineNode.parse(src))
	end)

	it("parses one level of nesting", function()
		local src = [[
      <outline>
        <item page="19">I. Problems</item>
        <outline>
          <item page="20">1 Searching</item>
          <item page="29">2 Sorting</item>
        </outline>
      </outline>
    ]]

		local expected = {
			{
				title = "I. Problems",
				page = 19,
				children = {
					{ title = "1 Searching", page = 20 },
					{ title = "2 Sorting", page = 29 },
				},
			},
		}

		same(expected, OutlineNode.parse(src))
	end)

	it("parses deep levels of nesting", function()
		local src = [[
      <outline>
        <item page="19">I. Problems</item>
        <outline>
          <item page="20">1 Searching</item>
	  <outline>
	     <item page="21">1.1 Types of searching</item>
	     <outline>
	       <item page="22">1.1.a Naive approach</item>
	       <item page="23">1.1.b Binary search</item>
	     </outline>
	  </outline>
          <item page="29">2 Sorting</item>
	  <outline>
	    <item page="30">2.1 Normal sorting order</item>
	    <item page="31">2.2 Reverse sorting order</item>
	  </outline>
        </outline>
      </outline>
    ]]

		local expected = {

			{
				title = "I. Problems",
				page = 19,
				children = {
					{
						title = "1 Searching",
						page = 20,
						children = {
							{
								title = "1.1 Types of searching",
								page = 21,
								children = {

									{ title = "1.1.a Naive approach", page = 22 },
									{ title = "1.1.b Binary search", page = 23 },
								},
							},
						},
					},
					{
						title = "2 Sorting",
						page = 29,
						children = {
							{ title = "2.1 Normal sorting order", page = 30 },
							{ title = "2.2 Reverse sorting order", page = 31 },
						},
					},
				},
			},
		}
		same(expected, OutlineNode.parse(src))
	end)

	it("parse different level of nesting", function()
		local src = [[
<outline>
<item page="14">Preface</item>
<outline>
<item page="18">Introduction</item>
<item page="21">Acknowledgments</item>
<item page="22">About the Author</item>
</outline>
<item page="23">Part I. Introduction</item>
<outline>
<item page="25">Chapter 1. What Are Design and Architecture?</item>
<outline>
<item page="26">The Goal?</item>
<item page="27">A Case Study</item>
<item page="33">Conclusion</item>
</outline>
</outline>
		]]
		local expected = {
			{
				title = "Preface",
				page = 14,
				children = {
					{ title = "Introduction", page = 18 },
					{ title = "Acknowledgments", page = 21 },
					{ title = "About the Author", page = 22 },
				},
			},
			{
				title = "Part I. Introduction",
				page = 23,
				children = {
					{
						title = "Chapter 1. What Are Design and Architecture?",
						page = 25,
						children = {
							{ title = "The Goal?", page = 26 },
							{ title = "A Case Study", page = 27 },
							{ title = "Conclusion", page = 33 },
						},
					},
				},
			},
		}
		same(expected, OutlineNode.parse(src))
	end)

	it("returns an empty table when no <outline> is present", function()
		same({}, OutlineNode.parse('<item page="1">Cover</item>'))
	end)

	it("converts page attributes to numbers", function()
		local out = OutlineNode.parse([[
      <outline><item page="42">Answer</item></outline>
    ]])
		assert.is_number(out[1].page)
		eq(42, out[1].page)
	end)
	it("wrong data type in page attributes", function()
		local out = OutlineNode.parse([[
      <outline><item page="nyet">Answer</item></outline>
    ]])
		assert.is_number(out[1].page)
		eq(0, out[1].page)
	end)
end)
