SOURCES = {}
local soundFiles = love.filesystem.getDirectoryItems('resources/sounds')

for _, filename in ipairs(soundFiles) do
	local extension = string.sub(filename, -4)
	if extension == '.ogg' then
		local name = string.sub(filename, 1, -5)
		local s = {
			sound = love.audio.newSource('resources/sounds/' .. filename, 'static'),
			filepath = 'resources/sounds/'.. filename,
		}
		SOURCES[name] = {}
		table.insert(SOURCES[name], s)
		s.name = name
		s.sound:setVolume(0)
		love.audio.play(s.sound)
		s.sound:stop()
	end
end