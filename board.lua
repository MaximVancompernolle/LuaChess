require 'board_helper'
require 'misc_functions'
require 'piece_list'

---@class Board
Board = Object:extend()

function Board:init()
	-- board state information
	self.ply = 0

	-- WHITE = 1, black = -1
	self.colorToMove = 1
	self.opponentColor = -1
	
	self.enpassantSquare = nil
	self.castlingRights = {
		[1] = {K = true, Q = true},
		[-1] = {K = true, Q = true},
	}

	self.selected = 0
	self.highlighted = {}
	
	-- piece information
	self.P = {}
	for i = 1, 64 do
		self.P[i] = 0
	end

	self.kings = {
		[1] = nil,
		[-1] = nil,
	}

	self.pawns = {
		[1] = PieceList(),
		[-1] = PieceList(),
	}

	self.knights = {
		[1] = PieceList(),
		[-1] = PieceList(),
	}

	self.bishops = {
		[1] = PieceList(),
		[-1] = PieceList(),
	}

	self.rooks = {
		[1] = PieceList(),
		[-1] = PieceList(),
	}

	self.queens = {
		[1] = PieceList(),
		[-1] = PieceList(),
	}

	self.allPieceLists = {
		[Piece.KING] = self.kings,
		[Piece.PAWN] = self.pawns,
		[Piece.KNIGHT] = self.knights,
		[Piece.BISHOP] = self.bishops,
		[Piece.ROOK] = self.rooks,
		[Piece.QUEEN] = self.queens,
	}

	self.attackMap = {
		[1] = 0,
		[-1] = 0,
	}

	self:fenToPosition('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR')
	-- self:fenToPosition('rnbqkbnr/8/8/8/8/8/8/RNBQKBNR')
	-- self:fenToPosition('rnbqkbnr/ppp1pppp/8/8/8/p6p/PPP1pPPP/RNBQKBNR')
	-- self:fenToPosition('4k3/8/8/8/8/8/8/4K3')
	-- self:fenToPosition('r3k2r/8/8/8/8/8/8/R3K2R')
	-- self:fenToPosition('rnbqk2r/ppppPppp/8/8/8/8/PPPPPPPP/RNBQKBNR')
	-- self:fenToPosition('r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R')
	-- self:fenToPosition('4k3/6b1/8/4pP2/8/2K5/8/8')
	-- self:fenToPosition('4k3/8/8/1K2pP1r/8/8/8/8')
end

function Board:fenToPosition(fen)
	local rank = 8
	local file = 1

	for i = 1, #fen do
		local cur = fen[i]

		if cur == ' ' then break end -- need to handle turn order, castling, en passant, and turn count

		if tonumber(cur) then
			file = file + cur
		elseif cur == '/' then
			rank = rank - 1
			file = 1
		else
			local index = file + ((rank - 1) * 8)
			local piece = Piece.new(cur)
			self:addPieceToBitBoard(piece, index)
			self.P[index] = piece
			file = file + 1
		end
	end
end

function Board:positionToFen()

end

function Board:addPieceToBitBoard(piece, square)
	local pieceType = Piece.type(piece)
	local colorIndex = Piece.colorIndex(piece)

	if pieceType == Piece.PAWN then
		self.pawns[colorIndex]:addPieceAtSquare(square)
	elseif pieceType == Piece.KNIGHT then
		self.knights[colorIndex]:addPieceAtSquare(square)
	elseif pieceType == Piece.BISHOP then
		self.bishops[colorIndex]:addPieceAtSquare(square)
	elseif pieceType == Piece.ROOK then
		self.rooks[colorIndex]:addPieceAtSquare(square)
	elseif pieceType == Piece.QUEEN then
		self.queens[colorIndex]:addPieceAtSquare(square)
	elseif pieceType == Piece.KING then
		self.kings[colorIndex] = square
	end
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

-- function Board:trySelectSquare(x, y)
-- 	local i = indexFromPixel(x, y)

-- 	if self.P[i] == 0 or self.P[i].color ~= self.colorToMove then return end

-- 	-- can this just store an index
-- 	self.selected = {
-- 		i = i,
-- 		piece = self.P[i]
-- 	}
-- end

function Board:trySelectSquare(x, y)
	local i = indexFromPixel(x, y)

	-- if self.P[i] == 0 or self.P[i].color ~= self.colorToMove then return end
	if Piece.colorIndex(self.P[i]) == self.colorToMove then
		-- can this just store an index
		self.selected = {
			i = i,
			piece = self.P[i]
		}
	end
end

function Board:tryHighlightSquare(x, y)
	local i = indexFromPixel(x, y)

	if self.highlighted.i and (self.highlighted.i == i) then
		self.highlighted = {}
		return
	end

	-- can this just store an index
	self.highlighted = {
		i = i,
		piece = self.P[i]
	}
end

function Board:tryMovePiece(x, y)
	local endSquare = indexFromPixel(x, y)

	for _, move in pairs(MG.moves) do
		if move[1] == self.selected.i and move[2] == endSquare then
			self:makeMove(move[1], move[2], move.flag)
		end
	end

	self.selected = 0
end

function Board:makeMove(startSquare, endSquare, flag)
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

	-- TODO use this piece instead of self.selected.piece
	local pieceToMove = self.P[startSquare]

	self.enpassantSquare = nil
	self.P[startSquare] = Piece.NONE

	if not flag then goto skipFlags end

	--[[
		test that piece lists are being updated properly for all flags
	]]

	if flag == 'double push' then
		local pushDirection = self.colorToMove
		self.enpassantSquare = endSquare - (8 * pushDirection)
	end
	if flag == 'enpassant' then
		local pushDirection = self.colorToMove
		self.P[endSquare - (8 * pushDirection)] = 0

		self.pawns[self.colorToMove * -1]:removePieceAtSquare(endSquare - (8 * pushDirection))
	end
	if string.find(flag, 'promote') then
		self.selected.piece = Piece(flag[-1])
	end
	if flag == 'O-O' then
		self.P[endSquare - 1] = self.P[endSquare + 1]
		self.P[endSquare + 1] = 0

		self.rooks[self.colorToMove]:movePiece(endSquare + 1, endSquare - 1)
		self.kings[self.colorToMove] = endSquare
	end
	if flag == 'O-O-O' then
		self.P[endSquare + 1] = self.P[endSquare - 2]
		self.P[endSquare - 2] = 0

		self.rooks[self.colorToMove]:movePiece(endSquare - 2, endSquare + 1)
		self.kings[self.colorToMove] = endSquare
	end

	::skipFlags::

	-- update piece list when piece is captured
	if self.P[endSquare] ~= Piece.NONE then
		local pieceToCaptureType = tonumber(Piece.type(self.P[endSquare]))
		self.allPieceLists[pieceToCaptureType][self.opponentColor]:removePieceAtSquare(endSquare)
	end

	self.P[endSquare] = self.selected.piece

	local pieceToMoveType = tonumber(Piece.type(pieceToMove))

	-- TODO fix adding piece to list on promotion
	if pieceToMoveType ~= Piece.KING then
		self.allPieceLists[pieceToMoveType][self.colorToMove]:movePiece(startSquare, endSquare)
	else
		self.kings[self.colorToMove] = endSquare
	end

	self.colorToMove, self.opponentColor = self.opponentColor, self.colorToMove
	MG:generateMoves(self, true)
end

function Board:printAllPieceLists()
	print('white')
	print('king: ' .. self.kings[1])
	print('pawns: ' .. self.pawns[1]:tostring())
	print('knights: ' .. self.knights[1]:tostring())
	print('bishops: ' .. self.bishops[1]:tostring())
	print('rooks: ' .. self.rooks[1]:tostring())
	print('queens: ' .. self.queens[1]:tostring())

	print('black')
	print('king: ' .. self.kings[-1])
	print('pawns: ' .. self.pawns[-1]:tostring())
	print('knights: ' .. self.knights[-1]:tostring())
	print('bishops: ' .. self.bishops[-1]:tostring())
	print('rooks: ' .. self.rooks[-1]:tostring())
	print('queens: ' .. self.queens[-1]:tostring())
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

		if cur ~= 0 then love.graphics.draw(imageForPiece(cur), px, py, 0, 2/3, 2/3) end
	end
end
