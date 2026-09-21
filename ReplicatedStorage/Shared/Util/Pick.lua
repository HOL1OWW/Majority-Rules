--!nonstrict
--[[
	Pick.lua — weighted selection helpers. All randomness flows through a caller-supplied
	Random so draws stay reproducible from the match seed.
]]

local Pick = {}

--! Weighted single pick. `weightOf` defaults to a `Weight` field, then to 1.
function Pick.weighted<T>(list: { T }, weightOf: ((T) -> number)?, rng: Random): T?
	if #list == 0 then
		return nil
	end

	local total = 0
	local weights = table.create(#list)
	for index, item in list do
		local weight = 1
		if weightOf then
			weight = weightOf(item) or 1
		elseif type(item) == "table" and (item :: any).Weight then
			weight = (item :: any).Weight
		end
		weight = math.max(weight, 0)
		weights[index] = weight
		total += weight
	end

	if total <= 0 then
		return list[rng:NextInteger(1, #list)]
	end

	local roll = rng:NextNumber() * total
	local running = 0
	for index, item in list do
		running += weights[index]
		if roll <= running then
			return item
		end
	end
	return list[#list]
end

--! Weighted sample without replacement. Used for the vote candidate draw.
function Pick.sample<T>(list: { T }, count: number, weightOf: ((T) -> number)?, rng: Random): { T }
	local pool = table.clone(list)
	local picked = {}
	local target = math.min(count, #pool)
	for _ = 1, target do
		local item = Pick.weighted(pool, weightOf, rng)
		if item == nil then
			break
		end
		table.insert(picked, item)
		local index = table.find(pool, item)
		if index then
			table.remove(pool, index)
		else
			break
		end
	end
	return picked
end

function Pick.shuffled<T>(list: { T }, rng: Random): { T }
	local pool = table.clone(list)
	local out = {}
	while #pool > 0 do
		local index = rng:NextInteger(1, #pool)
		table.insert(out, table.remove(pool, index))
	end
	return out
end

return Pick
