require 'hex_helper'

---@class Game
Game = Object:extend()

function Game:setGlobals()
	self.VERSION = 'alpha'

	-- Feature Flags
	self.F_VARIANT = 'standard'

	-- Settings
	-- self.PROMOTIONS = {} allow promotions to be queen only, queen and knight only, or all

	-- Colors
	self.C = {
		LIGHT_SQUARE = HEX('F0D9B5'),
		DARK_SQUARE = HEX('B58863'),
		HIGHLIGHT_MOVE = HEX('FFFF3380'),
		HIGHLIGHT_SQUARE = HEX('FF333380'),
		WHITE = {1, 1, 1},
		BLACK = {0, 0, 0},
		GRAY = {0.5, 0.5, 0.5, 1/3}
	}
end

function Game:gameOver(player)
	-- 1 WHITE won
	-- 0 draw
	-- -1 black won
end

function Game:init()
	self:setGlobals()
end