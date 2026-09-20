--!nonstrict
--[[
	SeededRandom.lua — deterministic randomness.

	Every match has a seed. Every round's candidate draw is derived from that seed, so any
	bug report can be replayed exactly by recreating the match seed. This matters enormously
	when several AI agents are writing modifiers in parallel: "it broke on round 4" becomes
	reproducible.
]]

local SeededRandom = {}

--! FNV-flavoured 32-bit string hash (shift-add-xor). Stays inside double precision.
function SeededRandom.hash(text: string): number
	local h = 0x811C9DC5
	for index = 1, #text do
		h = bit32.band(h + string.byte(text, index), 0xFFFFFFFF)
		h = bit32.band(h + bit32.lshift(h, 10), 0xFFFFFFFF)
		h = bit32.bxor(h, bit32.rshift(h, 6))
	end
	h = bit32.band(h + bit32.lshift(h, 3), 0xFFFFFFFF)
	h = bit32.bxor(h, bit32.rshift(h, 11))
	h = bit32.band(h + bit32.lshift(h, 15), 0xFFFFFFFF)
	return h
end

function SeededRandom.new(seed: number | string): Random
	local numeric
	if type(seed) == "number" then
		numeric = math.floor(seed) % 2147483647
	else
		numeric = SeededRandom.hash(seed) % 2147483647
	end
	if numeric == 0 then
		numeric = 1
	end
	return Random.new(numeric)
end

--! Derive a child RNG from a parent seed and a label. Same inputs, same stream, forever.
function SeededRandom.derive(seed: number | string, label: string): Random
	local base = type(seed) == "number" and tostring(math.floor(seed)) or seed
	return SeededRandom.new(base .. ":" .. label)
end

function SeededRandom.matchSeed(): number
	return math.floor(os.time() * 1000 + math.random(1, 1000000)) % 2147483647
end

return SeededRandom
