--[[
	evaluate:
	material difference
	piece bonuses from PST (blend earlygame/midgame/endgame)
	evaluate king safety
		pawn shield
		open lines of attack on king
		pins
	bonus for controlling more space
	bishop penalty for diagonal with lots of pawns
	knight bonus for closed positions
	rook bonus for open/semi-open files
	pawn bonus for passed pawns and protected passed pawns
]]

function love.load()
	require 'string_helper'
	require 'object'
	require 'piece'
	require 'board'
	require 'game'
	require 'move_generator'

	G = Game()
	B = Board()
	precomputeMoveData()
	MG = MoveGenerator()
	MG:generateMoves(B, true)
end

function love.update(dt)
end

function love.draw()
	B:draw()
end

function love.keypressed(key, scancode, isrepeat)
	if key == 'escape' then
		love.event.quit()
	end
end

function love.mousepressed(x, y, button, istouch, presses)
	if button == 1 then
		B:clearSquares()

		if B.selected ~= 0 then
			B:tryMovePiece(x, y)
		else
			B:trySelectSquare(x, y)
		end
	elseif button == 2 then
		-- TODO allow highlighting of multiple squares
		B:tryHighlightSquare(x, y)
	end
end
