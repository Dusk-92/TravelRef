dofile("Dusk/TravelRef/TR_RouteRules.lua")

local function check(value, message)
    if not value then error(message, 2) end
end

-- Mixed requirement: reputation is for swift, quest also gates normal travel.
check(TR_RequirementCodesMet("R29,Q6", {R29=true,Q6=true}, false), "swift R29,Q6 should pass with both")
check(not TR_RequirementCodesMet("R29,Q6", {Q6=true}, false), "swift R29,Q6 must require R29")
check(TR_RequirementCodesMet("R29,Q6", {Q6=true}, true), "normal R29,Q6 should require only Q6")
check(not TR_RequirementCodesMet("R29,Q6", {R29=true}, true), "normal R29,Q6 must require Q6")

-- Leading comma means a requirement shared by normal and swift travel.
check(TR_RequirementCodesMet(",Q7", {Q7=true}, true), "normal ,Q7 should pass with Q7")
check(not TR_RequirementCodesMet(",Q7", {}, true), "normal ,Q7 must require Q7")

-- No comma: no extra requirement on the normal route.
check(TR_RequirementCodesMet("R29", {}, true), "normal R29 should not require the swift reputation")
check(not TR_RequirementCodesMet("R29", {}, false), "swift R29 must require R29")

-- Discount behavior shared by display and route calculation.
local discounts = {R17=.9, R23=.75}
check(math.abs(TR_DiscountRate("R23", {R23=true}, discounts) - .75) < 0.000001, "R23 discount")
check(math.abs(TR_DiscountRate("R23", {R23=true,S2=true}, discounts) - .60) < 0.000001, "R23 + S2 discount")
check(math.abs(TR_DiscountRate("R17", {R17=true,R18=true}, discounts) - .80) < 0.000001, "R17 + R18 discount")
check(math.abs(TR_DiscountRate("UNKNOWN", {UNKNOWN=true}, discounts) - 1) < 0.000001, "unknown discount must be safe")

print("TravelRef route-rule tests OK")
