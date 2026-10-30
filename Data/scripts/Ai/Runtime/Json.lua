--[[
JSON for saved content state: numbers, strings, booleans, arrays and string-keyed tables.
--]]

json = {}

local function encode(v, out)
	local t = type(v)
	if t == "nil" then
		table.insert(out, "null")
	elseif t == "boolean" or t == "number" then
		table.insert(out, tostring(v))
	elseif t == "string" then
		table.insert(out, (string.format("%q", v):gsub("\\\n", "\\n")))
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			table.insert(out, "[")
			for i, x in ipairs(v) do
				if i > 1 then table.insert(out, ",") end
				encode(x, out)
			end
			table.insert(out, "]")
		else
			table.insert(out, "{")
			local first = true
			for k, x in pairs(v) do
				if type(x) ~= "function" then
					if not first then table.insert(out, ",") end
					first = false
					encode(tostring(k), out)
					table.insert(out, ":")
					encode(x, out)
				end
			end
			table.insert(out, "}")
		end
	end
end

function json.encode(v)
	local out = {}
	encode(v, out)
	return table.concat(out)
end

local function skip(s, i)
	return s:find("[^%s]", i) or #s + 1
end

local decodeValue

local function decodeString(s, i)
	local out, j = {}, i + 1
	while j <= #s do
		local c = s:sub(j, j)
		if c == '"' then return table.concat(out), j + 1 end
		if c == "\\" then
			local n = s:sub(j + 1, j + 1)
			local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
			table.insert(out, map[n] or n)
			j = j + 2
		else
			table.insert(out, c)
			j = j + 1
		end
	end
	error("unterminated string")
end

decodeValue = function(s, i)
	i = skip(s, i)
	local c = s:sub(i, i)
	if c == "{" then
		local t = {}
		i = skip(s, i + 1)
		if s:sub(i, i) == "}" then return t, i + 1 end
		while true do
			local k
			k, i = decodeString(s, skip(s, i))
			i = skip(s, i) + 1
			t[k], i = decodeValue(s, i)
			i = skip(s, i)
			local d = s:sub(i, i)
			i = i + 1
			if d == "}" then return t, i end
		end
	elseif c == "[" then
		local t = {}
		i = skip(s, i + 1)
		if s:sub(i, i) == "]" then return t, i + 1 end
		while true do
			local v
			v, i = decodeValue(s, i)
			table.insert(t, v)
			i = skip(s, i)
			local d = s:sub(i, i)
			i = i + 1
			if d == "]" then return t, i end
		end
	elseif c == '"' then
		return decodeString(s, i)
	elseif s:sub(i, i + 3) == "true" then
		return true, i + 4
	elseif s:sub(i, i + 4) == "false" then
		return false, i + 5
	elseif s:sub(i, i + 3) == "null" then
		return nil, i + 4
	else
		local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
		return tonumber(num), i + #num
	end
end

function json.decode(s)
	if s == nil or s == "" then return nil end
	local ok, v = pcall(decodeValue, s, 1)
	return ok and v or nil
end
