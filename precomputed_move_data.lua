local ffi = require('ffi')
local bit = require('bit')
local bnot, band, bor, bxor = bit.bnot, bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift

slidingOffsets = {8, -8, -1, 1, 7, -7, 9, -9}
numSquaresToEdge = {}
kingMoves = {}
kingAttackBitBoards = {}
pawnAttackBitBoards = {
	[1] = {},
	[-1] = {},
}
pawnAttackDirections = {
	[1] = {5, 7},
	[-1] = {6, 8},
}
knightMoves = {}
knightAttackBitBoards = {}
rookMoves = {}
bishopMoves = {}
queenMoves = {}
rayLookup = {}

function precomputeMoveData()
	local knightOffsets = {6, -6, 10, -10, 15, -15, 17, -17}
	local mask = ffi.new('uint64_t', 1)

	for file = 1, 8 do
		for rank = 1, 8 do
			local numNorth = 8 - rank
			local numSouth = rank - 1
			local numWest = file - 1
			local numEast = 8 - file

			local index = file + ((rank - 1) * 8)

			numSquaresToEdge[index] = {
				numNorth,
				numSouth,
				numWest,
				numEast,
				math.min(numNorth, numWest),
				math.min(numSouth, numEast),
				math.min(numNorth, numEast),
				math.min(numSouth, numWest),
			}

			kingMoves[index] = {}
			local kingBitBoard = ffi.new('uint64_t', 0)
			for offsetIndex = 1, #slidingOffsets do
				local kingEndSquare = index + slidingOffsets[offsetIndex]
				if kingEndSquare >= 1 and kingEndSquare <= 64 then
					local kingSquareX = ((kingEndSquare - 1) % 8) + 1
					local kingSquareY = math.floor((kingEndSquare - 1) / 8) + 1

					if math.max(math.abs(file - kingSquareX), math.abs(rank - kingSquareY)) == 1 then
						table.insert(kingMoves[index], kingEndSquare)
						kingBitBoard = bor(kingBitBoard, lshift(mask, kingEndSquare - 1))
					end
				end
			end
			kingAttackBitBoards[index] = kingBitBoard

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
			pawnAttackBitBoards[1][index] = pawnBitBoardWhite
			pawnAttackBitBoards[-1][index] = pawnBitBoardBlack

			knightMoves[index] = {}
			local knightBitBoard = ffi.new('uint64_t', 0)
			for offsetIndex = 1, #knightOffsets do
				local knightEndSquare = index + knightOffsets[offsetIndex]
				if knightEndSquare >= 1 and knightEndSquare <= 64 then
					local knightSquareX = ((knightEndSquare - 1) % 8) + 1
					local knightSquareY = math.floor((knightEndSquare - 1) / 8) + 1

					if math.max(math.abs(file - knightSquareX), math.abs(rank - knightSquareY)) == 2 then
						table.insert(knightMoves[index], knightEndSquare)
						knightBitBoard = bor(knightBitBoard, lshift(mask, knightEndSquare - 1))
					end
				end
			end
			knightAttackBitBoards[index] = knightBitBoard

			local rookBitBoard = ffi.new('uint64_t', 0)
			for directionIndex = 1, 4 do
				for n = 1, numSquaresToEdge[index][directionIndex] do
					local rookEndSquare = index + slidingOffsets[directionIndex] * n
					rookBitBoard = bor(rookBitBoard, lshift(mask, rookEndSquare - 1))
				end
			end
			rookMoves[index] = rookBitBoard

			local bishopBitBoard = ffi.new('uint64_t', 0)
			for directionIndex = 5, 8 do
				for n = 1, numSquaresToEdge[index][directionIndex] do
					local bishopEndSquare = index + slidingOffsets[directionIndex] * n
					bishopBitBoard = bor(bishopBitBoard, lshift(mask, bishopEndSquare - 1))
				end
			end
			bishopMoves[index] = bishopBitBoard

			queenMoves[index] = bor(rookBitBoard, bishopBitBoard)
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

		rayLookup[i] = absDir * sign(offset)
	end
end