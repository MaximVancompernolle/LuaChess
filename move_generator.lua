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

	self.inCheck = false
	self.inDoubleCheck = false
	self.pinsExist = false
	self.pinRayBitMask = ffi.new('uint64_t', 0)
	self.checkRayBitMask = ffi.new('uint64_t', 0)

	self.opponentAttackMap = nil -- bit board of all squares attacked by opponent

	self.slidingOffsets = {8, -8, -1, 1, 7, -7, 9, -9} -- N, S, W, E, NW, SE, NE, SW
	self.numSquaresToEdge = {}

	self.kingMoves = {}
	self.kingAttackBitBoards = {}

	self.knightMoves = {}
	self.knightAttackBitBoards = {}

	self.pawnAttackBitBoards = {}
	self.pawnAttackBitBoards[1] = {}
	self.pawnAttackBitBoards[-1] = {}

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
		if self.inCheck then
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
	local canCastle = not (piece.hasMoved or self.inCheck)

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
				if not (containsSquare(self.attackMap, startSquare + 1) or containsSquare(self.attackMap, startSquare + 2)) then
					table.insert(self.M, {startSquare, startSquare + 2, flag = 'O-O'})
				end
			end
		end
		if queensideRights then
			if B.P[startSquare - 1] == 0 and B.P[startSquare - 2] == 0 and B.P[startSquare - 3] == 0 then
				if not (containsSquare(self.attackMap, startSquare - 1) or containsSquare(self.attackMap, startSquare - 2) or containsSquare(self.attackMap, startSquare - 3)) then
					table.insert(self.M, {startSquare, startSquare - 2, flag = 'O-O-O'})
				end
			end
		end
	end
end

-- need logic to prevent pinned pieces from moving and revealing attacks on the king
-- however, allow a pinned piece to move along the pinned ray
-- function MoveGenerator:isPinned(piece)
-- 	return false
-- end

-- function MoveGenerator:inCheck()
-- 	return self.check
-- end

-- function MoveGenerator:inDoubleCheck()
-- 	return self.doubleCheck
-- end

function MoveGenerator:calculateSlidingAttackData()
	-- TODO replace queens.numPieces with #queens
	-- need __len metamethod in PieceList

	self.slidingAttackMap = ffi.new('uint64_t', 0)
	local opponentColor = B.colorToMove * -1

	local queens = B.queens[opponentColor]
	for i = 1, queens.numPieces do
		self:calculateSlidingAttackPiece(queens[i], 1, 8)
	end

	local rooks = B.rooks[opponentColor]
	for i = 1, rooks.numPieces do
		self:calculateSlidingAttackPiece(rooks[i], 1, 4)
	end

	local bishops = B.bishops[opponentColor]
	for i = 1, bishops.numPieces do
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

function MoveGenerator:calculateKnightAttackData()
	self.knightAttackMap = ffi.new('uint64_t', 0)
	self.inKnightCheck = false

	local mask = ffi.new('uint64_t', 1)
	local opponentColor = B.colorToMove * -1
	local knights = B.knights[opponentColor]

	for i = 1, knights.numPieces do
		local startSquare = knights[i]
		self.knightAttackMap = bor(self.knightAttackMap, self.knightAttackBitBoards[startSquare])

		if not self.inKnightCheck and containsSquare(self.knightAttackMap, B.kings[B.colorToMove]) then
			self.inKnightCheck = true
			self.inDoubleCheck = self.inCheck
			self.inCheck = true
			self.checkRayBitMask = bor(self.checkRayBitMask, lshift(mask, startSquare - 1))
		end
	end
end

function MoveGenerator:calculatePawnAttackData()
	self.pawnAttackMap = ffi.new('uint64_t', 0)
	self.inPawnCheck = false

	local mask = ffi.new('uint64_t', 1)
	local opponentColor = B.colorToMove * -1
	local pawns = B.pawns[opponentColor]

	for i = 1, pawns.numPieces do
		local startSquare = pawns[i]
		self.pawnAttackMap = bor(self.pawnAttackMap, self.pawnAttackBitBoards[opponentColor][startSquare])

		if not self.inPawnCheck and containsSquare(self.pawnAttackMap, B.kings[B.colorToMove]) then
			self.inPawnCheck = true
			self.inDoubleCheck = self.inCheck
			self.inCheck = true
			self.checkRayBitMask = bor(self.checkRayBitMask, lshift(mask, startSquare - 1))
		end
	end
end

function MoveGenerator:calculateAttackData()
	self:calculateSlidingAttackData()

	-- search for checks and pins
	-- TODO small optimization: if no queens and no rooks/bishops don't need to check all directions around the king
	local startDirection = 1
	local endDirection = 8

	local friendlyKingSquare = B.kings[B.colorToMove]

	local mask = ffi.new('uint64_t', 1)

	for directionIndex = startDirection, endDirection do
		local isDiagonal = directionIndex > 4
		local isFriendlyPieceAlongRay = false
		local rayMask = ffi.new('uint64_t', 0)

		for n = 1, self.numSquaresToEdge[friendlyKingSquare][directionIndex] do
			local square = friendlyKingSquare + self.slidingOffsets[directionIndex] * n
			local piece = B.P[square]
			rayMask = bor(rayMask, lshift(mask, square - 1))

			if piece ~= 0 then
				if piece.color == B.colorToMove then
					if not isFriendlyPieceAlongRay then -- first friendly piece on ray; might be pinned
						isFriendlyPieceAlongRay = true
					else 								-- second friendly piece on ray; no pin
						break
					end
				else
					if (isDiagonal and piece:isBishop()) or (not isDiagonal and piece:isRook()) or piece:isQueen() then
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

function MoveGenerator:isSquareAttacked(square)
	return containsSquare(self.attackMap, square)
end

function MoveGenerator:precomputedMoveData()
	-- TODO precompute move offsets for sliding pieces

	local knightOffsets = {6, -6, 10, -10, 15, -15, 17, -17}
	local mask = ffi.new('uint64_t', 1)

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
			local knightBitBoard = ffi.new('uint64_t', 0)
			for offsetIndex = 1, #knightOffsets do
				local knightEndSquare = index + knightOffsets[offsetIndex]
				if knightEndSquare >= 1 and knightEndSquare <= 64 then
					local knightSquareX = ((knightEndSquare - 1) % 8) + 1
					local knightSquareY = math.floor((knightEndSquare - 1) / 8) + 1

					if math.max(math.abs(file - knightSquareX), math.abs(rank - knightSquareY)) == 2 then
						table.insert(self.knightMoves[index], knightEndSquare)
						knightBitBoard = bor(knightBitBoard, lshift(mask, knightEndSquare - 1))
					end
				end
			end
			self.knightAttackBitBoards[index] = knightBitBoard

			self.kingMoves[index] = {}
			local kingBitBoard = ffi.new('uint64_t', 0)
			for offsetIndex = 1, #self.slidingOffsets do
				local kingEndSquare = index + self.slidingOffsets[offsetIndex]
				if kingEndSquare >= 1 and kingEndSquare <= 64 then
					local kingSquareX = ((kingEndSquare - 1) % 8) + 1
					local kingSquareY = math.floor((kingEndSquare - 1) / 8) + 1

					if math.max(math.abs(file - kingSquareX), math.abs(rank - kingSquareY)) == 1 then
						table.insert(self.kingMoves[index], kingEndSquare)
						kingBitBoard = bor(kingBitBoard, lshift(mask, kingEndSquare - 1))
					end
				end
			end
			self.kingAttackBitBoards[index] = kingBitBoard

			local pawnBitBoardWhite = ffi.new('uint64_t', 0)
			local pawnBitBoardBlack = ffi.new('uint64_t', 0)
			if file > 1 then
				if rank < 8 then
					pawnBitBoardWhite = bor(pawnBitBoardWhite, lshift(mask, index + 6))
				end
				if rank > 1 then
					pawnBitBoardBlack = bor(pawnBitBoardBlack, lshift(mask, index - 10))
				end
			end
			if file < 8 then
				if rank < 8 then
					pawnBitBoardWhite = bor(pawnBitBoardWhite, lshift(mask, index + 8))
				end
				if rank > 1 then
					pawnBitBoardBlack = bor(pawnBitBoardBlack, lshift(mask, index - 8))
				end
			end
			self.pawnAttackBitBoards[1][index] = pawnBitBoardWhite
			self.pawnAttackBitBoards[-1][index] = pawnBitBoardBlack
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