-- SvgWriter.lua

-- Simple object for writing SVG files out of incrementally-constructed geometries





local SvgWriter = {}

local fmt = string.format
local assert = assert
local type = type
local concat = table.concat
local error = error
local setmetatable = setmetatable




function SvgWriter.new(aWidth, aHeight)
	local res =
	{
		width = aWidth,
		height = aHeight,
		out = { n = 0 },
		groups = {},  -- Dict of GroupID -> LineNumber for all defined groups
		groupDepth = 0,
	}
	local meta = { __index = SvgWriter }
	setmetatable(res, meta)
	return res
end





function SvgWriter:addArc(aX1, aY1, aX2, aY2, aRadiusX, aRadiusY, aAxisAngle, aIsLargeArc, aSweepFlag, aParams)
	assert(type(self) == "table")
	assert(type(aX1) == "number")
	assert(type(aY1) == "number")
	assert(type(aX2) == "number")
	assert(type(aY2) == "number")
	assert(type(aRadiusX) == "number")
	assert(type(aRadiusY) == "number")
	assert(type(aAxisAngle) == "number")
	assert(type(aIsLargeArc) == "boolean")
	assert(type(aSweepFlag) == "boolean")

	local largeArcFlag = aIsLargeArc and "1" or "0"
	local sweepFlag = aSweepFlag and "1" or "0"
	local def = fmt("M %f %f A %f %f %f %s %s %f %f",
		aX1, aY1,
		aRadiusX, aRadiusY,
		aAxisAngle,
		largeArcFlag, sweepFlag,
		aX2, aY2
	)

	self.out.n = self.out.n + 1
	self.out[self.out.n] = fmt("<path d=\"%s\" %s/>", def, SvgWriter.serializeParams(aParams))
end





function SvgWriter:addCircle(aX, aY, aRadius, aParams)
	assert(type(self) == "table")

	self.out.n = self.out.n + 1
	self.out[self.out.n] = fmt("<circle cx=\"%f\" cy=\"%f\" r=\"%f\" %s/>", aX, aY, aRadius, SvgWriter.serializeParams(aParams))
end





function SvgWriter:addCurve(aXStart, aYStart, aXControl1, aYControl1, aXControl2, aYControl2, aXEnd, aYEnd, aParams)
	assert(type(self) == "table")
	assert(type(aXStart) == "number")
	assert(type(aYStart) == "number")
	assert(type(aXControl1) == "number")
	assert(type(aYControl1) == "number")
	assert(type(aXControl2) == "number")
	assert(type(aYControl2) == "number")
	assert(type(aXEnd) == "number")
	assert(type(aYEnd) == "number")

	local def = fmt("M %f %f C %f %f %f %f %f %f",
		aXStart, aYStart,
		aXControl1, aYControl1,
		aXControl2, aYControl2,
		aXEnd, aYEnd
	)
	self.out.n = self.out.n + 1
	self.out[self.out.n] = fmt("<path d=\"%s\" %s/>",def, SvgWriter.serializeParams(aParams))
end





function SvgWriter:addEllipse(aX, aY, aRadiusX, aRadiusY, aParams)
	assert(type(self) == "table")

	self.out.n = self.out.n + 1
	self.out[self.out.n] = fmt("<ellipse cx=\"%f\" cy=\"%f\" rx=\"%f\" ry=\"%f\" %s/>", aX, aY, aRadiusX, aRadiusY, SvgWriter.serializeParams(aParams))
end





function SvgWriter:addLine(aX1, aY1, aX2, aY2, aParams)
	assert(type(self) == "table")
	assert(type(aX1) == "number")
	assert(type(aY1) == "number")
	assert(type(aX2) == "number")
	assert(type(aY2) == "number")

	local def = fmt("M %f %f L %f %f", aX1, aY1, aX2, aY2)
	self.out.n = self.out.n + 1
	self.out[self.out.n] = fmt("<path d=\"%s\" %s/>",def, SvgWriter.serializeParams(aParams))
end





function SvgWriter:addManual(aText)
	assert(type(self) == "table")
	assert(type(aText) == "string")

	self.out.n = self.out.n + 1
	self.out[self.out.n] = aText
end





function SvgWriter:beginGroup(aGroupID, aParams)
	assert(type(self) == "table")
	assert(type(aGroupID) == "string")

	if (self.groups[aGroupID]) then
		error("Group already defined on line " .. self.groups[aGroupID])
	end

	self.groupDepth = self.groupDepth + 1
	self.out.n = self.out.n + 1
	self.out[self.out.n] = fmt("<g id=\"%s\" %s>", aGroupID, SvgWriter.serializeParams(aParams))
	self.groups[aGroupID] = self.out.n
end





function SvgWriter:endGroup()
	assert(type(self) == "table")
	assert(self.groupDepth > 0)

	self.out.n = self.out.n + 1
	self.out[self.out.n] = fmt("</g>")
	self.groupDepth = self.groupDepth - 1
end





function SvgWriter:setDimensions(aWidth, aHeight)
	assert(type(self) == "table")
	assert(tonumber(aWidth))
	assert(tonumber(aHeight))

	self.width = aWidth
	self.height = aHeight
end





function SvgWriter:useGroup(aGroupID, aTransform, aParams)
	assert(type(self) == "table")
	assert(type(aGroupID) == "string")

	if not(self.groups[aGroupID]) then
		error("Group with ID " .. aGroupID .. " wasn't defined yet.")
	end

	self.out.n = self.out.n + 1
	self.out[self.out.n] = fmt("<use xlink:href=\"#%s\" transform=\"%s\" %s/>",
		aGroupID, aTransform,
		SvgWriter.serializeParams(aParams)
	)
end





--- Serializes the Params table into a string containing all the params from the table
-- aParams may be nil, or a dict table of "param" = "value"
function SvgWriter.serializeParams(aParams)
	assert((aParams == nil) or (type(aParams) == "table"))

	local res = {}
	local n = 1
	for k, v in pairs(aParams or {}) do
		res[n] = fmt("%s=\"%s\"", k, v)
		n = n + 1
	end
	return table.concat(res, " ")
end





function SvgWriter:writeToFile(aFileName)
	assert(type(self) == "table")

	local f = assert(io.open(aFileName, "wb"))
	f:write(self:writeToString())
	f:close()
end




function SvgWriter:writeToString()
	assert(type(self) == "table")
	assert(self.groupDepth == 0, "A group definition hasn't been closed properly")

	return
		fmt("<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%f\" height=\"%f\">\n", self.width, self.height) ..
		concat(self.out, "\n") ..
		"\n</svg>"
end





return { new = SvgWriter.new }
