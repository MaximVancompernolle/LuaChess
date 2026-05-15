io.stdout:setvbuf('no')

function love.conf(t)
	t.console = true

	t.window.title = "LuaChess"
	t.window.width = 800
	t.window.height = 800
end