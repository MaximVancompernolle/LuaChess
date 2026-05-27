local bit = require('bit')
local bnot, band, bor, bxor = bit.bnot, bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift

fileNames = 'abcdefgh'
rankNames = '12345678'

a1 = 1
b1 = 2
c1 = 3
d1 = 4
e1 = 5
f1 = 6
g1 = 7
h1 = 8

a8 = 57
b8 = 58
c8 = 59
d8 = 60
e8 = 61
f8 = 62
g8 = 63
h8 = 64

-- Rank (0-7)
function RankIndex(square)
	return rshift(square, 3)
end

-- File (0-7)
function FileIndex(square)
	return band(square, 7)
end