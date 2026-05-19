local ffi = require('ffi')
local bit = require('bit')
local bnot, band, bor, bxor = bit.bnot, bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift

---@Class Piece
Piece = Object:extend()

NONE = 0
KING = 1
PAWN = 2
KNIGHT = 3
BISHOP = 5
ROOK = 6
QUEEN = 7

WHITE = 8
BLACK = 16

typeMask = ffi.new('uint8_t', 7)
whiteMask = ffi.new('uint8_t', 8)
blackMask = ffi.new('uint8_t', 16)
colorMask = bor(whiteMask, blackMask)

function Piece.isColor(piece, color)
	return band(piece, colorMask) == color
end

function Piece.color(piece)
	return band(piece, colorMask)
end

function Piece.type(piece)
	return band(piece, typeMask)
end

function Piece.isRookOrQueen(piece)
	return band(piece, ffi.new('uint8_t', 6)) == 6
end

function Piece.isBishopOrQueen(piece)
	return band(piece, ffi.new('uint8_t', 5)) == 5
end

function Piece.isSlidingPiece(piece)
	return band(piece, ffi.new('uint8_t', 4)) ~= 0
end