-- TravelRef pure routing rules.
-- coding: utf-8 'ä
-- This module intentionally has no Turbine dependency so it can be unit-tested.

-- A requirement string before a comma applies to swift travel; codes after a
-- comma also gate the normal route. Examples:
--   R29,Q6 -> swift needs R29 + Q6; normal needs Q6
--   ,Q7    -> both swift and normal need Q7
--   R29    -> swift needs R29; normal has no extra requirement
function TR_RequirementCodesMet(code, req, normalOnly)
    if type(code) ~= "string" or code == "" then return true end
    req = type(req) == "table" and req or {}

    if normalOnly then
        local comma = string.find(code, ",", 1, true)
        if not comma then return true end
        code = string.sub(code, comma + 1)
    end

    for requirement in string.gmatch(code, "%u%d+") do
        if not req[requirement] then return false end
    end
    return true
end

-- Keep route calculation and destination display on exactly the same discount
-- rules, including the special R17/R18 stacking and the global S2 reduction.
function TR_DiscountRate(code, req, discounts, requirements)
    req = type(req) == "table" and req or {}
    discounts = type(discounts) == "table" and discounts or {}
    requirements = type(requirements) == "table" and requirements or {}

    local rate = 1
    if code and req[code] then
        if discounts[code] then rate = discounts[code]
        elseif requirements[code] then rate = 0.9 end
    end
    if code == "R17" and req.R18 then rate = rate - 0.1 end
    if req.S2 then rate = rate * 0.8 end
    return rate
end
