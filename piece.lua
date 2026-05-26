local ffi = require('ffi')
local bit = require('bit')
local bnot, band, bor, bxor = bit.bnot, bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift

---@Class Piece
Piece = Object:extend()

--[[
	Piece values
	standard
	pawn	1
	knight	3
	bishop	3
	rook	5
	queen	9

	by most squares attacked
	pawn	2
	knight	8
	bishop	13
	rook	14
	queen	27

	by average squares attacked
	pawn	1.75
	knight	5.25
	bishop	8.75
	rook	14
	queen	22.75
]]

Piece.NONE = 0
Piece.KING = 1
Piece.PAWN = 2
Piece.KNIGHT = 3
Piece.BISHOP = 5
Piece.ROOK = 6
Piece.QUEEN = 7

local pieceFromSymbol = {
	['k'] = Piece.KING,
	['p'] = Piece.PAWN,
	['n'] = Piece.KNIGHT,
	['b'] = Piece.BISHOP,
	['r'] = Piece.ROOK,
	['q'] = Piece.QUEEN,
}

Piece.WHITE = 8
Piece.BLACK = 16

typeMask = ffi.new('uint16_t', 7)
whiteMask = ffi.new('uint16_t', 8)
blackMask = ffi.new('uint16_t', 16)
colorMask = bor(whiteMask, blackMask)

function Piece.new(char)
	local piece = pieceFromSymbol[char:lower()]
	if string.byte(char) <= 90 then
		piece = piece + Piece.WHITE
	else
		piece = piece + Piece.BLACK
	end

	return piece
end

function Piece.isColor(piece, color)
	return band(piece, colorMask) == color
end

function Piece.color(piece)
	return band(piece, colorMask)
end

function Piece.colorIndex(piece)
	local color = Piece.color(piece)

	if color == Piece.WHITE then return 1 end
	if color == Piece.BLACK then return -1 end
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