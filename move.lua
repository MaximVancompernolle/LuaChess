local ffi = require('ffi')
local bit = require('bit')
local bnot, band, bor, bxor = bit.bnot, bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift

---@Class Move
Move = Object:extend()

NONE = 0
EN_PASSANT_CAPTURE = 1
CASTLING = 2
PROMOTE_QUEEN = 3
PROMOTE_KNIGHT = 4
PROMOTE_ROOK = 5
PROMOTE_BISHOP = 6
PAWN_DOUBLE_PUSH = 7

startSquareMask = ffi.new('uint16_t', 63)
endSquareMask = ffi.new('uint16_t', 4032)
flagMask = ffi.new('uint16_t', 61440)

function Move.startSquare(move)
	return band(move, startSquareMask)
end

function Move.endSquare(move)
	return rshift(band(move, endSquareMask), 6)
end

function Move.flag(move)
	return rshift(move, 12)
end

function Move.isPromotion(move)
	local flag = Move.flag(move)
	return flag == PROMOTE_QUEEN or flag == PROMOTE_KNIGHT or flag == PROMOTE_ROOK or flag == PROMOTE_BISHOP
end