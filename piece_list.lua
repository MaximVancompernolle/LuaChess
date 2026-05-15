---@Class PieceList
PieceList = Object:extend()

function PieceList:init()
	self.occupiedSquares = {}
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
	table.insert(self.occupiedSquares, square)
	self.numPieces = self.numPieces + 1
end

function PieceList:removePieceAtSquare(square)
	table.remove(self.occupiedSquares, square)
	self.numPieces = self.numPieces - 1
end