---@Class PieceList
PieceList = Object:extend()

function PieceList:init()
	self.occupiedSquares = {}
end

function PieceList:addPieceAtSquare(square)
	table.insert(self.occupiedSquares, square)
end

function PieceList:removePieceAtSquare(square)
	table.remove(self.occupiedSquares, square)
end