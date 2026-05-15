require 'misc_functions'

local ffi = require('ffi')
local bit = require('bit')
local bnot, band, bor, bxor = bit.bnot, bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift

---@class MoveGenerator
MoveGenerator = Object:extend()

--[[
	TODO represent move as binary object
	bit 0-5: startSquare
	bit 6-11: endSquare
	bit 12-15: flag

	flag values
	none = 0
	enpassant = 1
	castling = 2
	promote queen = 3
	promote knight = 4
	promote rook = 5
	promote bishop = 6
	double push = 7
]]

-- TODO should we keep track of opponent color in Board instead of recalculating it with colorToMove * -1 ?

function MoveGenerator:init()
	self.debug = false

	self.slidingOffsets = {8, -8, -1, 1, 7, -7, 9, -9} -- N, S, W, E, NW, SE, NE, SW
	self.numSquaresToEdge = {}
	self.knightMoves = {}
	self:precomputedMoveData()
end

function MoveGenerator:generateMoves()
	self.M = {}

	self:calculateAttackData()
	
	-- TODO if in double check, only generate king moves
	for i = 1, #B.P do
		local piece = B.P[i]

		-- current square has no piece so skip this iteration
		if piece == 0 then goto continue end

		if piece.color == B.colorToMove then
			if piece:isSlidingPiece() then
				self:generateSlidingMoves(piece, i)
			elseif piece:isKnight() then
				self:generateKnightMoves(piece, i)
			elseif piece:isPawn() then
				self:generatePawnMoves(piece, i)
			elseif piece:isKing() then
				self:generateKingMoves(piece, i)
			end
		end

		::continue::
	end

	-- TODO no legal moves means we are in stalemate or checkmate
	if #self.M == 0 then
		if self:inCheck() then
			-- checkmate
		else
			-- stalemate
		end
	end

	if self.debug then self:printMoves() end
end

function MoveGenerator:generateSlidingMoves(piece, startSquare)
	-- queen (1, 8)
	-- rook (1, 4)
	-- bishop (5, 8)
	local startDirection = piece:isBishop() and 5 or 1
	local endDirection = piece:isRook() and 4 or 8

	for directionIndex = startDirection, endDirection do
		for n = 1, self.numSquaresToEdge[startSquare][directionIndex] do
			local endSquare = startSquare + self.slidingOffsets[directionIndex] * n
			local pieceOnEndSquare = B.P[endSquare]

			if pieceOnEndSquare ~= 0 and pieceOnEndSquare.color == piece.color then break end

			table.insert(self.M, {startSquare, endSquare})

			if pieceOnEndSquare ~= 0 and pieceOnEndSquare.color ~= piece.color then break end
		end
	end
end

function MoveGenerator:generateKnightMoves(piece, startSquare)
	for _, endSquare in pairs(self.knightMoves[startSquare]) do
		local pieceOnEndSquare = B.P[endSquare]

		if pieceOnEndSquare == 0 or pieceOnEndSquare.color ~= piece.color then
			table.insert(self.M, {startSquare, endSquare})
		end
	end
end

function MoveGenerator:generatePawnMoves(piece, startSquare)
	-- TODO en passant and promotion
	local pushDirection = piece.color
	local pushSquare = startSquare + 8 * pushDirection
	local canCaptureEast = startSquare % 8 ~= 0
	local canCaptureWest = startSquare % 8 ~= 1

	if piece.color == 1 then
		resultsInPromotion = math.floor((startSquare - 1) / 8) == 6
	else
		resultsInPromotion = math.floor((startSquare - 1) / 8) == 1
	end

	if B.P[pushSquare] == 0 then
		if resultsInPromotion then
			self:generatePromotionMoves(startSquare, pushSquare, piece.color)
		else
			table.insert(self.M, {startSquare, pushSquare})
		end

		-- TODO determine ability to double push based on position so we don't need to store piece.hasMoved
		local canDoublePush = not piece.hasMoved
		local doublePushSquare = pushSquare + 8 * pushDirection

		if canDoublePush and B.P[doublePushSquare] == 0 then
			table.insert(self.M, {startSquare, doublePushSquare, flag = 'double push'})
		end
	end

	if canCaptureEast then
		self:generatePawnCaptureMoves(piece, startSquare, pushSquare + 1, resultsInPromotion)
	end

	if canCaptureWest then
		self:generatePawnCaptureMoves(piece, startSquare, pushSquare - 1, resultsInPromotion)
	end
end

function MoveGenerator:generatePawnCaptureMoves(piece, startSquare, captureSquare, resultsInPromotion)
	local capturePiece = B.P[captureSquare]

	if captureSquare == B.enpassantSquare then
		table.insert(self.M, {startSquare, captureSquare, flag = 'en passant'})
	end

	if (capturePiece ~= 0) and capturePiece.color ~= piece.color then
		if resultsInPromotion then
			self:generatePromotionMoves(startSquare, captureSquare, piece.color)
		else
			table.insert(self.M, {startSquare, captureSquare})
		end
	end
end

function MoveGenerator:generatePromotionMoves(startSquare, endSquare, color)
	if color == 1 then
		promotions = {'Q', 'R', 'B', 'N'}
	else
		promotions = {'q', 'r', 'b', 'n'}
	end

	for _, type in pairs(promotions) do
		table.insert(self.M, {startSquare, endSquare, flag = 'promote ' .. type})
	end
end

function MoveGenerator:generateKingMoves(piece, startSquare)
	for directionIndex = 1, #self.slidingOffsets do
		local endSquare = startSquare + self.slidingOffsets[directionIndex]

		if endSquare < 1 or endSquare > 64 then goto continue end

		local pieceOnEndSquare = B.P[endSquare]

		if pieceOnEndSquare == 0 or pieceOnEndSquare.color ~= piece.color then
			table.insert(self.M, {startSquare, endSquare})
		end

		::continue::
	end

	--[[
		TODO castling
		1. neither the king nor the rook has previously moved
		2. there are no pieces between the king and the rook
		3. the king is not in check
		4. the king does not pass through or end on a square that is attacked by an enemy piece
	]]
	local canCastle = not (piece.hasMoved or self:inCheck())

	if canCastle then
		if piece.color == 1 then
			kingsideRights = B.castlingRights['K']
			queensideRights = B.castlingRights['Q']
		else
			kingsideRights = B.castlingRights['k']
			queensideRights = B.castlingRights['q']
		end

		if kingsideRights then
			if B.P[startSquare + 1] == 0 and B.P[startSquare + 2] == 0 then
				table.insert(self.M, {startSquare, startSquare + 2, flag = 'O-O'})
			end
		end
		if queensideRights then
			if B.P[startSquare - 1] == 0 and B.P[startSquare - 2] == 0 and B.P[startSquare - 3] == 0 then
				table.insert(self.M, {startSquare, startSquare - 2, flag = 'O-O-O'})
			end
		end
	end
end

-- need logic to prevent pinned pieces from moving and revealing attacks on the king
-- however, allow a pinned piece to move along the pinned ray
function MoveGenerator:isPinned(piece)
	return false
end

function MoveGenerator:inCheck()
	return false
end

function MoveGenerator:inDoubleCheck()
	return false
end

function MoveGenerator:calculateSlidingAttackData()
	-- TODO replace queens.numPieces with #queens
	-- need __len metamethod in PieceList

	self.slidingAttackMap = ffi.new('uint64_t', 0)
	local opponentColor = B.colorToMove * -1

	local queens = B.queens[opponentColor]
	for i = 1, queens.numPieces do
		print('calculating queen attack data')
		self:calculateSlidingAttackPiece(queens[i], 1, 8)
	end

	local rooks = B.rooks[opponentColor]
	for i = 1, rooks.numPieces do
		print('calculating rook attack data')
		self:calculateSlidingAttackPiece(rooks[i], 1, 4)
	end

	local bishops = B.bishops[opponentColor]
	for i = 1, bishops.numPieces do
		print('calculating bishop attack data')
		self:calculateSlidingAttackPiece(bishops[i], 5, 8)
	end
end

function MoveGenerator:calculateSlidingAttackPiece(startSquare, startDirection, endDirection)
	local mask = ffi.new('uint64_t', 1)
	for directionIndex = startDirection, endDirection do
		for n = 1, self.numSquaresToEdge[startSquare][directionIndex] do
			local endSquare = startSquare + self.slidingOffsets[directionIndex] * n
			local pieceOnEndSquare = B.P[endSquare]

			self.slidingAttackMap = bor(self.slidingAttackMap, lshift(mask, endSquare - 1))

			if endSquare ~= B.kings[B.colorToMove] then
				if pieceOnEndSquare ~= 0 then
					break
				end
			end
		end
	end
end

function MoveGenerator:calculateAttackData()
	self:calculateSlidingAttackData()

	print(tobinary_64(self.slidingAttackMap))
end

function MoveGenerator:precomputedMoveData()
	-- TODO precompute move offsets for sliding pieces

	local knightOffsets = {6, -6, 10, -10, 15, -15, 17, -17}
	for file = 1, 8 do
		for rank = 1, 8 do
			local numNorth = 8 - rank
			local numSouth = rank - 1
			local numWest = file - 1
			local numEast = 8 - file

			local index = file + ((rank - 1) * 8)

			self.numSquaresToEdge[index] = {
				numNorth,
				numSouth,
				numWest,
				numEast,
				math.min(numNorth, numWest),
				math.min(numSouth, numEast),
				math.min(numNorth, numEast),
				math.min(numSouth, numWest),
			}

			self.knightMoves[index] = {}

			for offsetIndex = 1, #knightOffsets do
				local knightEndSquare = index + knightOffsets[offsetIndex]
				if knightEndSquare >= 1 and knightEndSquare <= 64 then
					local knightSquareX = ((knightEndSquare - 1) % 8) + 1
					local knightSquareY = math.floor((knightEndSquare - 1) / 8) + 1

					if math.max(math.abs(file - knightSquareX), math.abs(rank - knightSquareY)) == 2 then
						table.insert(self.knightMoves[index], knightEndSquare)
					end
				end
			end
		end
	end
end

function MoveGenerator:printMoves()
	for k, v in pairs(self.M) do
		s = v[1] .. ' -> ' .. v[2]

		if v.flag then
			s = s .. ' ' .. v.flag
		end

		print(s)
	end
end

function MoveGenerator:printKnightMoves()
	for i = 1, 64 do
		s = i .. ': '

		for k, v in pairs(self.knightMoves[i]) do
			s = s .. v .. ' '
		end
		
		print(s)
	end
end

function MoveGenerator:drawPieceMoves(square)
	for k, v in pairs(self.M) do
		if v[1] == square then
			local px, py = centerPixelFromIndex(v[2])

			if B.P[v[2]] == 0 then
				drawMove(px, py)
			else
				drawCapture(px, py)
			end
		end
	end
end

function drawMove(px, py)
	love.graphics.setColor(G.C.GRAY)
	love.graphics.circle('fill', px, py, 15)
	love.graphics.reset()
end

function drawCapture(px, py)
	love.graphics.setColor(G.C.GRAY)
	love.graphics.setLineWidth(8)
	love.graphics.circle('line', px, py, 46)
	love.graphics.reset()
end