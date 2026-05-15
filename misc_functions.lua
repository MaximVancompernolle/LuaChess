function pixelFromIndex(index)
	return ((index - 1) % 8) * 100, 700 - (100 * (math.floor((index - 1) / 8)))
end

function centerPixelFromIndex(index)
	local px, py = pixelFromIndex(index)
	return px + 50, py + 50
end

function indexFromPixel(x, y)
	local x = math.floor((x / 100) + 1)
	local y = math.floor(9 - (y / 100))

	return x + ((y - 1) * 8)
end