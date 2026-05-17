local bit = require('bit')
local bnot, band, bor, bxor = bit.bnot, bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift

function pixelFromIndex(index)
	return ((index - 1) % 8) * 100, 700 - (100 * (math.floor((index - 1) / 8)))
end

function centerPixelFromIndex(index)
	local px, py = pixelFromIndex(index)
	return px + 50, py + 50
end

function indexFromPixel(x, y)
	local x = math.floor((x / 100) + 1)
	local y = math.floor(9 - (y / 100))

	return x + ((y - 1) * 8)
end

function tobinary_64(value)
	-- TODO ? rewrite to print 64 bit values mapping to a board view
	local bits = {}

	for i = 63, 0, -1 do
		local bit_set = bit.band(bit.rshift(value, i), 1)
		table.insert(bits, tonumber(bit_set))
	end
	return table.concat(bits)
end

function containsSquare(bitboard, square)
	return band(rshift(bitboard, square - 1), 1) ~= 0
end