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

	for i = 64, 1, -1 do
		local bit_set = band(rshift(value, i - 1), 1)
		table.insert(bits, tonumber(bit_set))
	end
	return table.concat(bits)
end

function tobinaryboard(value)
	local s = ''
	for rank = 8, 1, -1 do
		local rank_bits = {}
		for file = 1, 8 do
			local index = file + ((rank - 1) * 8)
			local bit_set = band(rshift(value, index - 1), 1)
			table.insert(rank_bits, tonumber(bit_set))
		end
		s = s .. table.concat(rank_bits) .. '\n'
	end
	return s
end

function containsSquare(bitboard, square)
	return band(rshift(bitboard, square - 1), 1) ~= 0
end