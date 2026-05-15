require 'board_helper'
require 'misc_functions'
require 'piece_list'

---@class Board
Board = Object:extend()

--[[
	TODO store squares attacked by each side
	used for captures, checks, and castling

	64 bit number 1 for attacked and 0 for not attacked
	OR
	64 x 4 bit number storing # of attacks on each square
	15 max FEN 8/4n3/1nqrbn2/2qPr3/1nqqkn2/2n1n3/8/K7 w - - 0 1
]]

function Board:init()
	-- board state information
	self.ply = 0
	self.colorToMove = 1 -- WHITE = 1, black = -1
	self.enpassantSquare = nil
	self.castlingRights = {K = true, Q = true, k = true, q = true}

	self.selected = 0
	self.highlighted = {}
	
	-- piece information
	self.P = {}
	for i = 1, 64 do
		self.P[i] = 0
	end

	self.queens = {}
	self.queens[1] = PieceList()
	self.queens[-1] = PieceList()

	self.rooks = {}
	self.rooks[1] = PieceList()
	self.rooks[-1] = PieceList()

	self.bishops = {}
	self.bishops[1] = PieceList()
	self.bishops[-1] = PieceList()

	self.knights = {}
	self.knights[1] = PieceList()
	self.knights[-1] = PieceList()

	self.pawns = {}
	self.pawns[1] = PieceList()
	self.pawns[-1] = PieceList()

	self.kings = {}
	self.kings[1] = 0
	self.kings[-1] = 0

	self.attackMap = {}
	self.attackMap[1] = 0
	self.attackMap[-1] = 0

	self:fenToPosition('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR')
	-- self:fenToPosition('r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R')
end

function Board:fenToPosition(fen)
	local y = 8
	local x = 1

	for i = 1, #fen do
		local cur = fen[i]

		if cur == ' ' then break end -- need to handle turn order, castling, en passant, and turn count

		if tonumber(cur) then
			x = x + cur
		elseif cur == '/' then
			y = y - 1
			x = 1
		else
			local index = x + ((y - 1) * 8)
			self.P[index] = Piece(cur)
			x = x + 1
		end
	end
end

function Board:positionToFen()

end

function Board:toConsole()
	for y = 8, 1, -1 do
		local s = ''
		for x = 1, 8 do
			local index = x + ((y - 1) * 8)
			if self.P[index] ~= 0 then
				s = s .. self.P[index].type .. ' '
			else
				s = s .. '0 '
			end
		end
		print(s)
	end
end

function Board:trySelectSquare(x, y)
	local i = indexFromPixel(x, y)

	if self.P[i] == 0 or self.P[i].color ~= self.colorToMove then return end

	self.selected = {
		i = i,
		piece = self.P[i]
	}
end

function Board:tryHighlightSquare(x, y)
	local i = indexFromPixel(x, y)

	if self.highlighted.i and (self.highlighted.i == i) then
		self.highlighted = {}
		return
	end

	self.highlighted = {
		i = i,
		piece = self.P[i]
	}
end

function Board:tryMovePiece(x, y)
	local endSquare = indexFromPixel(x, y)

	for _, move in pairs(MG.M) do
		if move[1] == self.selected.i and move[2] == endSquare then
			self:makeMove(move[1], move[2], move.flag)
		end
	end

	self.selected = 0
end

function Board:makeMove(startSquare, endSquare, flag)
	-- flag is not getting pushed properly

	--[[
		increment ply, half move, and full move counters
		move piece from start square to end square
		
		first pawn move: set piece.hasMoved = true
		pawn promotion: update piece.type
		en passant: remove captured pawn, clear en passant square
		double push: set board.enpassantSquare
		first king move: set piece.hasMoved = true
		first rook move: set piece.hasMoved = true, set self.castlingRights = false
		castling: move rook

		add position to history for 3-fold repetition
	]]
	self.enpassantSquare = nil
	self.P[startSquare] = 0

	if not flag then goto skipFlags end

	if flag == 'double push' then
		-- set en passant square
		local pushDirection = self.colorToMove
		self.enpassantSquare = endSquare - (8 * pushDirection)
	end
	if flag == 'en passant' then
		-- remove captured pawn
		local pushDirection = self.colorToMove
		self.P[endSquare - (8 * pushDirection)] = 0
	end
	if string.find(flag, 'promote') then
		self.selected.piece = Piece(flag[-1])
	end
	if flag == 'O-O' then
		self.P[endSquare - 1] = self.P[endSquare + 1]
		self.P[endSquare + 1] = 0
	end
	if flag == 'O-O-O' then
		self.P[endSquare + 1] = self.P[endSquare - 2]
		self.P[endSquare - 2] = 0
	end

	::skipFlags::

	self.P[endSquare] = self.selected.piece
	self.P[endSquare].hasMoved = true
	self.colorToMove = self.colorToMove * -1
	MG:generateMoves()
end

function Board:clearSquares()
	-- self.selected = {}
	self.highlighted = {}
end

function Board:draw()
	love.graphics.draw(BH.I['board'].image, 0, 0, 0, 0.5, 0.5)

	if self.selected ~= 0 then
		-- TODO highlight start and end squares of previous move made
		MG:drawPieceMoves(self.selected.i)

		love.graphics.setColor(G.C.HIGHLIGHT_MOVE)
		local px, py = pixelFromIndex(self.selected.i)
		love.graphics.rectangle('fill', px, py, 100, 100)
		love.graphics.reset()
	end

	if self.highlighted.piece then
		love.graphics.setColor(G.C.HIGHLIGHT_SQUARE)
		local px, py = pixelFromIndex(self.highlighted.i)
		love.graphics.rectangle('fill', px, py, 100, 100)
		love.graphics.reset()
	end

	for i = 1, #self.P do
		local cur = self.P[i]
		local px, py = pixelFromIndex(i)

		if cur ~= 0 then love.graphics.draw(BH.I[cur.type].image, px, py, 0, 2/3, 2/3) end
	end
end
