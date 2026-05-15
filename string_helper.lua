string_meta = getmetatable('')
original_index = string_meta.__index

function string_meta:__index(key)
	if type(key) == 'number' then
		return string.sub(self, key, key)
	end
	return original_index[key]
end