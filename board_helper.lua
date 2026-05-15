BH = {
	I = {}
}

local imageFiles = love.filesystem.getDirectoryItems('resources/textures')

for _, filename in ipairs(imageFiles) do
	local extension = string.sub(filename, -4)

	if extension == '.png' then
		local name = string.sub(filename, 1, -5)
		local i = {
			image = love.graphics.newImage('resources/textures/' .. filename),
			filepath = 'resources/textures/' .. filename,
		}

		BH.I[name] = i
	end
end

local startingFEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'

-- double check positions
local GundersenFaul1928 = 'r1bq1r2/pp2n3/4N2k/3pPppP/1b1n2Q1/2N5/PP3PP1/R1B1K2R w - g6 0 14'
local RetiTartakower1910 = 'rnb1kb1r/pp3ppp/2p5/4q3/4n3/3Q4/PPPB1PPP/2KR1BNR w kq - 0 8'
local AnderssenDufresne1852 = '1r2k1r1/pbppnp1p/1bn2P2/8/Q7/B1PB1q2/P4PPP/3RR1K1 w - - 0 19'

-- perft positions
local position5 = 'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8'