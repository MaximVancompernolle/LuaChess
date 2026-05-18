---@Class PieceList
PieceList = Object:extend()

function PieceList:init()
	self.occupiedSquares = {}
	self.map = {}
	self.numPieces = 0

	setmetatable(self, {
        __index = function(t, key)
            local method = PieceList[key]
            if method ~= nil then return method end
            return rawget(t, 'occupiedSquares')[key]
        end
    })
end

function PieceList:addPieceAtSquare(square)
	self.numPieces = self.numPieces + 1
	table.insert(self.occupiedSquares, self.numPieces, square)
	self.map[square] = self.numPieces
end

function PieceList:removePieceAtSquare(square)
	local index = self.map[square]
	self.occupiedSquares[index] = self.occupiedSquares[numPieces - 1]
	self.map[self.occupiedSquares[index]] = index
	self.numPieces = self.numPieces - 1
end

function PieceList:movePiece(startSquare, endSquare)
	local index = self.map[startSquare]
	self.occupiedSquares[index] = endSquare
	self.map[endSquare] = index
end

function PieceList:tostring()
	s = ''
	if self.numPieces == 0 then return s end

	for k, v in pairs(self.occupiedSquares) do
		s = s .. v .. ' '
	end

	return s
end