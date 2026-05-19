---@class Piece
Piece = Object:extend()

--[[
	TODO represent piece as binary object
	none = 0
	king = 1
	pawn = 2
	knight = 3
	bishop = 5
	rook = 6
	queen = 7

	white = 8
	black = 16

	use bitwise operands to get color/type of piece
	typeMask = 0b00111
	whiteMask = 0b01000
	blackMask = 0b10000
	colorMask = whiteMask | blackMask
]]

function Piece:init(char)
	local b = string.byte(char)

	-- WHITE = 1
	-- black = -1
	if b >= 65 and b <= 90 then
		self.color = 1
	elseif b >= 97 and b <= 122 then
		self.color = -1
	end

	self.type = char
	
	-- used by pawn for double pushes and king for castling
	-- TODO remove this field, it's not necessary
	self.hasMoved = false
end

function Piece:isSlidingPiece()
	local char = self.type:lower()
	
	return char == 'b' or char == 'r' or char == 'q'
end

function Piece:isQueen()
	return self.type:lower() == 'q'
end

function Piece:isBishop()
	return self.type:lower() == 'b'
end

function Piece:isRook()
	return self.type:lower() == 'r'
end

function Piece:isKnight()
	return self.type:lower() == 'n'
end

function Piece:isPawn()
	return self.type:lower() == 'p'
end

function Piece:isKing()
	return self.type:lower() == 'k'
end