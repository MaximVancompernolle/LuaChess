require 'misc_functions'
require 'precomputed_move_data'
require 'board_representation'

local ffi = require('ffi')
local bit = require('bit')
local bnot, band, bor, bxor = bit.bnot, bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift

---@class MoveGenerator
MoveGenerator = Object:extend()

function MoveGenerator:init()
	-- self.opponentAttackMap = nil -- bit board of all squares attacked by opponent

	-- self.slidingOffsets = {8, -8, -1, 1, 7, -7, 9, -9} -- N, S, W, E, NW, SE, NE, SW
	-- self.numSquaresToEdge = {}

	-- self.kingMoves = {}
	-- self.kingAttackBitBoards = {}

	-- self.knightMoves = {}
	-- self.knightAttackBitBoards = {}

	-- self.pawnAttackBitBoards = {}
	-- self.pawnAttackBitBoards[1] = {}
	-- self.pawnAttackBitBoards[-1] = {}

	-- self.bishopMoves = {}
	-- self.rookMoves = {}
	-- self.queenMoves = {}

	-- self:precomputedMoveData()
end

function MoveGenerator:clear()
	self.moves = {}
	self.inCheck = false
	self.inDoubleCheck = false
	self.pinsExist = false
	self.pinRayBitMask = ffi.new('uint64_t', 0)
	self.checkRayBitMask = ffi.new('uint64_t', 0)

	self.friendlyColor = self.B.colorToMove
	self.opponentColor = self.B.opponentColor
	self.friendlyKingSquare = self.B.kings[self.friendlyColor]
end

function MoveGenerator:generateMoves(board, includeQuietMoves)
	self.B = board
	self.generateQuietMoves = includeQuietMoves

	self:clear()

	self:calculateAttackData()
	self:generateKingMoves()

	if self.inDoubleCheck then
		print('in double check')
		return self.moves
	end

	self:generateSlidingMoves()
	self:generateKnightMoves()
	self:generatePawnMoves()

	self:printMoves()

	return self.moves
end

function MoveGenerator:generateKingMoves()
	print('generating king moves')
	for i = 1, #kingMoves[self.friendlyKingSquare] do
		local endSquare = kingMoves[self.friendlyKingSquare][i]
		local pieceOnEndSquare = self.B.P[endSquare]

		if Piece.colorIndex(pieceOnEndSquare) == self.friendlyColor then goto continue end

		local isCapture = (Piece.colorIndex(pieceOnEndSquare) == self.opponentColor)

		if not isCapture then
			if self:isSquareInCheckRay(endSquare) then goto continue end
		end

		if not self:isSquareAttacked(endSquare) then
			table.insert(self.moves, {self.friendlyKingSquare, endSquare})

			if not self.inCheck and not isCapture then
				if (endSquare == 6 or endSquare == 62) and self.B.castlingRights[self.friendlyColor]['K'] then
					local kingsideCastleSquare = endSquare + 1

					if self.B.P[kingsideCastleSquare] == 0 and not self:isSquareAttacked(kingsideCastleSquare) then
						table.insert(self.moves, {self.friendlyKingSquare, kingsideCastleSquare, 'O-O'})
					end
				elseif (endSquare == 4 or endSquare == 60) and self.B.castlingRights[self.friendlyColor]['Q'] then
					local queensideCastleSquare = endSquare - 1

					if self.B.P[queensideCastleSquare] == 0 and self.B.P[queensideCastleSquare - 1] == 0 and not self:isSquareAttacked(queensideCastleSquare) then
						table.insert(self.moves, {self.friendlyKingSquare, queensideCastleSquare, 'O-O-O'})
					end
				end
			end
		end

		::continue::
	end
end

function MoveGenerator:generateSlidingMoves()
	print('generating sliding moves')
	local queens = self.B.queens[self.friendlyColor]
	for i = 1, queens.numPieces do
		print('generating queen moves')
		self:generateSlidingPieceMoves(queens[i], 1, 8)
	end

	local rooks = self.B.rooks[self.friendlyColor]
	for i = 1, rooks.numPieces do
		print('generating rook moves')
		self:generateSlidingPieceMoves(rooks[i], 1, 4)
	end

	local bishops = self.B.bishops[self.friendlyColor]
	for i = 1, bishops.numPieces do
		print('generating bishop moves')
		self:generateSlidingPieceMoves(bishops[i], 5, 8)
	end
end

function MoveGenerator:generateSlidingPieceMoves(startSquare, startDirection, endDirection)
	local isPinned = self:isSquarePinned(startSquare)

	if self.inCheck and isPinned then return end

	for directionIndex = startDirection, endDirection do
		local directionOffset = slidingOffsets[directionIndex]

		if isPinned and not self:isAlongRay(directionOffset, startSquare, self.friendlyKingSquare) then goto continue end

		for n = 1, numSquaresToEdge[startSquare][directionIndex] do
			local endSquare = startSquare + directionOffset * n
			local pieceOnEndSquare = self.B.P[endSquare]

			if Piece.colorIndex(pieceOnEndSquare) == self.friendlyColor then break end

			local movePreventsCheck = self:isSquareInCheckRay(endSquare)
			local isCapture = pieceOnEndSquare ~= 0

			if not self.inCheck or movePreventsCheck then
				if self.generateQuietMoves or isCapture then
					table.insert(self.moves, {startSquare, endSquare})
				end
			end

			if isCapture or movePreventsCheck then break end
		end

		::continue::
	end
end

function MoveGenerator:generateKnightMoves()
	print('generating knight moves')
	local knights = self.B.knights[self.friendlyColor]

	for i = 1, knights.numPieces do
		local startSquare = knights[i]

		if self:isSquarePinned(startSquare) then goto continue end

		local knightMoves = knightMoves[startSquare]
		for m = 1, #knightMoves do
			local endSquare = knightMoves[m]
			local pieceOnEndSquare = self.B.P[endSquare]

			if Piece.colorIndex(pieceOnEndSquare) ~= self.friendlyColor and (not self.inCheck or self:isSquareInCheckRay(endSquare)) then
				local isCapture = pieceOnEndSquare ~= 0

				if self.generateQuietMoves or isCapture then
					table.insert(self.moves, {startSquare, endSquare})
				end
			end
		end

		::continue::
	end
end

function MoveGenerator:generatePawnMoves()
	print('generating pawn moves')
	local pawns = self.B.pawns[self.friendlyColor]
	local pushOffset = self.friendlyColor * 8
	local enpassantSquare = self.B.enpassantSquare
	
	local startRank										-- 0 indexed
	if self.friendlyColor == 1 then
		startRank = 1
	else
		startRank = 6
	end

	local rankBeforePromotion = 7 - startRank			-- 0 indexed

	for i = 1, pawns.numPieces do
		local startSquare = pawns[i]
		local rank = RankIndex(startSquare - 1)				-- 0 indexed
		local resultsInPromotion = rank == rankBeforePromotion
		local isPinned = self:isSquarePinned(startSquare)

		if self.generateQuietMoves then
			local pushSquare = startSquare + pushOffset

			if self.B.P[pushSquare] == 0 then
				if isPinned and not self:isAlongRay(pushOffset, startSquare, self.friendlyKingSquare) then goto captures end

				if not self.inCheck or self:isSquareInCheckRay(pushSquare) then
					if resultsInPromotion then
						self:generatePromotionMoves(startSquare, pushSquare)
					else
						table.insert(self.moves, {startSquare, pushSquare})
					end
				end

				if rank == startRank then
					local doublePushSquare = pushSquare + pushOffset

					if self.B.P[doublePushSquare] == 0 then
						if not self.inCheck or self:isSquareInCheckRay(doublePushSquare) then
							table.insert(self.moves, {startSquare, doublePushSquare})
						end
					end
				end
			end
		end

		::captures::

		for j = 1, 2 do
			local captureDirection = pawnAttackDirections[self.friendlyColor][j]
			if numSquaresToEdge[startSquare][captureDirection] > 0 then
				local captureOffset = slidingOffsets[captureDirection]
				local captureSquare = startSquare + captureOffset

				if isPinned and not self:isAlongRay(captureOffset, startSquare, self.friendlyKingSquare) then goto continue end

				local pieceOnEndSquare = self.B.P[captureSquare]

				if Piece.colorIndex(pieceOnEndSquare) == self.opponentColor then
					if not self.inCheck or self:isSquareInCheckRay(captureSquare) then
						if resultsInPromotion then
							self:generatePromotionMoves(startSquare, captureSquare)
						else
							table.insert(self.moves, {startSquare, captureSquare})
						end
					end
				elseif captureSquare == self.B.enpassantSquare then
					local epCapturedPawnSquare = captureSquare - pushOffset
					if not self:inCheckAfterEnPassant(startSquare, captureSquare, epCapturedPawnSquare) then
						table.insert(self.moves, {startSquare, captureSquare, flag = 'enpassant'})
					end
				end
			end

			::continue::
		end
	end
end

function MoveGenerator:generatePromotionMoves(startSquare, endSquare)
	table.insert(self.moves, {startSquare, endSquare, flag = 'promote '})
	table.insert(self.moves, {startSquare, endSquare, flag = 'promote '})
	table.insert(self.moves, {startSquare, endSquare, flag = 'promote '})
	table.insert(self.moves, {startSquare, endSquare, flag = 'promote '})
end

-- endSquare seems to not be necessary
function MoveGenerator:inCheckAfterEnPassant(startSquare, endSquare, epCapturedPawnSquare)
	return false
	-- self.B.P[endSquare] = self.B.P[startSquare]
	-- self.B.P[startSquare] = Piece.NONE
	-- self.B.P[epCapturedPawnSquare] = Piece.NONE

	-- get direction from friendlyKingSquare to epCapturedPawnSquare
	-- move along direction from friendlyKingSquare
	-- if first piece found is friendlyColor, no check
	-- if first piece found is opponentColor, check if that piece can move along the direction


end

function MoveGenerator:calculateAttackData()
	print('calculating attack data')
	self:calculateSlidingAttackData()

	-- TODO small optimization: if no queens and no rooks/bishops don't need to check all directions around the king
	local startDirection = 1
	local endDirection = 8

	local mask = ffi.new('uint64_t', 1)

	for directionIndex = startDirection, endDirection do
		local isDiagonal = directionIndex > 4
		local isFriendlyPieceAlongRay = false
		local rayMask = ffi.new('uint64_t', 0)

		for n = 1, numSquaresToEdge[self.friendlyKingSquare][directionIndex] do
			local square = self.friendlyKingSquare + slidingOffsets[directionIndex] * n
			local piece = self.B.P[square]
			rayMask = bor(rayMask, lshift(mask, square - 1))

			if piece ~= 0 then
				if Piece.colorIndex(piece) == self.friendlyColor then
					if not isFriendlyPieceAlongRay then -- first friendly piece on ray; might be pinned
						isFriendlyPieceAlongRay = true
					else 								-- second friendly piece on ray; no pin
						break
					end
				else
					if (isDiagonal and Piece.isBishopOrQueen(piece)) or (not isDiagonal and Piece.isRookOrQueen(piece)) then
						if isFriendlyPieceAlongRay then
							self.pinsExist = true
							self.pinRayBitMask = bor(self.pinRayBitMask, rayMask)
						else
							self.checkRayBitMask = bor(self.checkRayBitMask, rayMask)
							self.inDoubleCheck = self.inCheck
							self.inCheck = true
						end
						break
					else
						break							-- piece cannot move along ray
					end
				end
			end
		end
		if self.inDoubleCheck then
			break
		end
	end

	self:calculateKnightAttackData()
	self:calculatePawnAttackData()

	self.noPawnsAttackMap = bor(self.slidingAttackMap, self.knightAttackMap)
	self.attackMap = bor(self.noPawnsAttackMap, self.pawnAttackMap)
end

function MoveGenerator:calculateSlidingAttackData()
	print('calculating sliding attack data')
	self.slidingAttackMap = ffi.new('uint64_t', 0)

	local queens = self.B.queens[self.opponentColor]
	for i = 1, queens.numPieces do
		self:calculateSlidingAttackPiece(queens[i], 1, 8)
	end

	local rooks = self.B.rooks[self.opponentColor]
	for i = 1, rooks.numPieces do
		self:calculateSlidingAttackPiece(rooks[i], 1, 4)
	end

	local bishops = self.B.bishops[self.opponentColor]
	for i = 1, bishops.numPieces do
		self:calculateSlidingAttackPiece(bishops[i], 5, 8)
	end
end

function MoveGenerator:calculateSlidingAttackPiece(startSquare, startDirection, endDirection)
	local mask = ffi.new('uint64_t', 1)
	for directionIndex = startDirection, endDirection do
		for n = 1, numSquaresToEdge[startSquare][directionIndex] do
			local endSquare = startSquare + slidingOffsets[directionIndex] * n
			local pieceOnEndSquare = self.B.P[endSquare]

			self.slidingAttackMap = bor(self.slidingAttackMap, lshift(mask, endSquare - 1))

			if endSquare ~= self.friendlyKingSquare then
				if pieceOnEndSquare ~= 0 then
					break
				end
			end
		end
	end
end

function MoveGenerator:calculateKnightAttackData()
	print('calculating knight attack data')
	self.knightAttackMap = ffi.new('uint64_t', 0)
	self.inKnightCheck = false

	local mask = ffi.new('uint64_t', 1)
	local knights = self.B.knights[self.opponentColor]

	for i = 1, knights.numPieces do
		local startSquare = knights[i]
		self.knightAttackMap = bor(self.knightAttackMap, knightAttackBitBoards[startSquare])

		if not self.inKnightCheck and containsSquare(self.knightAttackMap, self.friendlyKingSquare) then
			self.inKnightCheck = true
			self.inDoubleCheck = self.inCheck
			self.inCheck = true
			self.checkRayBitMask = bor(self.checkRayBitMask, lshift(mask, startSquare - 1))
		end
	end
end

function MoveGenerator:calculatePawnAttackData()
	print('calculating pawn attack data')
	self.pawnAttackMap = ffi.new('uint64_t', 0)
	self.inPawnCheck = false

	local mask = ffi.new('uint64_t', 1)
	local pawns = self.B.pawns[self.opponentColor]

	for i = 1, pawns.numPieces do
		local startSquare = pawns[i]
		self.pawnAttackMap = bor(self.pawnAttackMap, pawnAttackBitBoards[self.opponentColor][startSquare])

		if not self.inPawnCheck and containsSquare(self.pawnAttackMap, self.friendlyKingSquare) then
			self.inPawnCheck = true
			self.inDoubleCheck = self.inCheck
			self.inCheck = true
			self.checkRayBitMask = bor(self.checkRayBitMask, lshift(mask, startSquare - 1))
		end
	end
end

function MoveGenerator:isSquareAttacked(square)
	return containsSquare(self.attackMap, square)
end

function MoveGenerator:isSquareInCheckRay(square)
	return self.inCheck and containsSquare(self.checkRayBitMask, square)
end

function MoveGenerator:isSquarePinned(square)
	return self.pinsExist and containsSquare(self.pinRayBitMask, square)
end

function MoveGenerator:isAlongRay(rayDirection, startSquare, endSquare)
	local moveDirection = rayLookup[endSquare - startSquare + 64]
	return (rayDirection == moveDirection) or (-1 * rayDirection == moveDirection)
end

function MoveGenerator:printMoves()
	for k, v in pairs(self.moves) do
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

-- TODO move to different class, probably board_helper which should handle all visuals
function MoveGenerator:drawPieceMoves(square)
	for k, v in pairs(self.moves) do
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