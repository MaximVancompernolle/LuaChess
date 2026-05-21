function MoveGenerator:precomputedMoveData()
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

			local rookBitBoard = ffi.new('uint64_t', 0)
			for directionIndex = 1, 4 do
				for n = 1, self.numSquaresToEdge[index][directionIndex] do
					local rookEndSquare = index + self.slidingOffsets[directionIndex] * n
					rookBitBoard = bor(rookBitBoard, lshift(mask, rookEndSquare - 1))
				end
			end
			self.rookMoves[index] = rookBitBoard

			local bishopBitBoard = ffi.new('uint64_t', 0)
			for directionIndex = 5, 8 do
				for n = 1, self.numSquaresToEdge[index][directionIndex] do
					local bishopEndSquare = index + self.slidingOffsets[directionIndex] * n
					bishopBitBoard = bor(bishopBitBoard, lshift(mask, bishopEndSquare - 1))
				end
			end
			self.bishopMoves[index] = bishopBitBoard

			self.queenMoves[index] = bor(rookBitBoard, bishopBitBoard)
		end
	end

	for i = 1, 126 do
		local offset = i - 64
		local absOffset = math.abs(offset)
		local absDir = 1

		if absOffset % 9 == 0 then
			absDir = 9
		elseif absOffset % 8 == 0 then
			absDir = 8
		elseif absOffset % 7 == 0 then
			absDir = 7
		end

		self.rayLookup[i] = absDir * sign(offset)
	end
end