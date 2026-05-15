Object = {}
Object.__index = Object

function Object:init()
end

function Object:extend()
	local cls = {}
	for k, v in pairs(self) do
		if k:find("__") == 1 then
			cls[k] = v
		end
	end
	cls.__index = cls
	cls.super = self
	setmetatable(cls, self)
	return cls
end

function Object:__call(...)
	local obj = setmetatable({}, self)
	obj:init(...)
	return obj
end