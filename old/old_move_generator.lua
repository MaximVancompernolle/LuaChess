function OldMoveGenerator:generateMoves()
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

function OldMoveGenerator:generateSlidingMoves(piece, startSquare)
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

function OldMoveGenerator:generateKnightMoves(piece, startSquare)
	for _, endSquare in pairs(self.knightMoves[startSquare]) do
		local pieceOnEndSquare = B.P[endSquare]

		if pieceOnEndSquare == 0 or pieceOnEndSquare.color ~= piece.color then
			table.insert(self.M, {startSquare, endSquare})
		end
	end
end

function OldMoveGenerator:generatePawnMoves(piece, startSquare)
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

function OldMoveGenerator:generatePawnCaptureMoves(piece, startSquare, captureSquare, resultsInPromotion)
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

function OldMoveGenerator:generatePromotionMoves(startSquare, endSquare, color)
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