function HEX(hex)
	if #hex <= 6 then hex = hex .. 'FF' end
	local _, _, r, g, b, a = hex:find('(%x%x)(%x%x)(%x%x)(%x%x)')
	local color = {tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255}

	return color
end