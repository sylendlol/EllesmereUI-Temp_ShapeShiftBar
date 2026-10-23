-------------------------------------------------------------------------------
--  EllesmereUI Temp Shapeshift Bar
--  EllesmereUI Action Bars pages Action Bar 1 for [overridebar], [vehicleui],
--  [possessbar], [bonusbar:N], but not for [shapeshift], the temporary
--  shapeshift bar (event forms, e.g. the zombie debuff). Blizzard's own bar
--  pages to GetTempShapeshiftBarIndex() there (32 on WoW Forever); EUI stays
--  on page 1, so the form's spells never show on any EUI bar.
--
--  Fix: build the same MainBar paging string EUI builds, add
--  "[shapeshift] <index>" and register it on EABBar_MainBar ourselves; redo it
--  whenever EUI rebuilds the paging (ns.RebuildBarPaging). No EUI file modified.
--
--  1.0.0 post-hooked the global RegisterStateDriver: that never fired, because
--  EUI_ActionBars_Bars.lua keeps its own local copy of RegisterStateDriver.
-------------------------------------------------------------------------------
local PREFIX = "|cff0cd29fTemp Shapeshift Bar:|r "

local function TempIndex()
    local f = GetTempShapeshiftBarIndex
        or (C_ActionBar and C_ActionBar.GetTempShapeshiftBarIndex)
    if not f then return nil end
    local ok, v = pcall(f)
    v = ok and tonumber(v) or nil
    if v and v < 1 then v = nil end
    return v
end

local function EABns()
    local reg = EllesmereUI and rawget(EllesmereUI, "_ModuleNS")
    return reg and reg["EllesmereUIActionBars"]
end

-- Insert after the vehicle/possess clause, else after the override clause,
-- else in front (Blizzard: override, then temp shapeshift, then vehicle).
local function Patch(values, idx)
    if type(values) ~= "string" then return nil end
    if values:find("%[shapeshift%]") then return values end
    local clause = "[shapeshift] " .. idx .. "; "
    local _, e = values:find("%[vehicleui%]%[possessbar%] %d+; ")
    if not e then _, e = values:find("%[overridebar%] %d+; ") end
    if e then
        return values:sub(1, e) .. clause .. values:sub(e + 1)
    end
    return clause .. values
end

-- The exact string EUI's RebuildBarPaging("MainBar") registers.
local function BaseConditions(ns)
    local V = rawget(ns, "EAB_VTABLE")
    local EAB = rawget(ns, "EAB")
    local I = rawget(ns, "_internals")
    if not V then return nil end
    local bs = EAB and EAB.db and EAB.db.profile and EAB.db.profile.bars
        and EAB.db.profile.bars.MainBar
    if V.HasCustomPaging and V.HasCustomPaging(bs) and V.BuildPagingConditions then
        return V.BuildPagingConditions("MainBar", bs.paging, 1)
    end
    local f = I and rawget(I, "GetClassPagingConditions")
    return f and f() or nil
end

local lastValues, lastError
local pendingRegen = false

local function Apply()
    if InCombatLockdown() then pendingRegen = true; return false end
    local bar = _G.EABBar_MainBar
    local ns = EABns()
    local idx = TempIndex()
    if not (bar and ns and idx) then
        lastError = not bar and "Action Bar 1 not built yet"
            or not ns and "EllesmereUI Action Bars not found"
            or "no temp shapeshift index"
        return false
    end
    local ok, base = pcall(BaseConditions, ns)
    if not ok or type(base) ~= "string" or base == "" then
        lastError = "could not read EUI paging (" .. tostring(base) .. ")"
        return false
    end
    local patched = Patch(base, idx)
    UnregisterStateDriver(bar, "page")
    RegisterStateDriver(bar, "page", patched)
    lastValues, lastError = patched, nil
    return true
end

-- EUI rebuilds the paging from its options panel through ns.RebuildBarPaging.
local hooked = false
local function HookRebuild()
    if hooked then return end
    local ns = EABns()
    if ns and type(rawget(ns, "RebuildBarPaging")) == "function" then
        hooksecurefunc(ns, "RebuildBarPaging", function(barKey)
            if barKey == "MainBar" then Apply() end
        end)
        hooked = true
    end
end
HookRebuild()

-- EUI builds its bars in OnEnable, a tick or more after PLAYER_LOGIN: wait
-- for EABBar_MainBar, then apply. Re-apply if the frame ever gets replaced.
local appliedTo
local function WatchBar()
    local tries = 0
    local t
    t = C_Timer.NewTicker(0.5, function()
        tries = tries + 1
        HookRebuild()
        local bar = _G.EABBar_MainBar
        if bar and bar ~= appliedTo then
            if Apply() then appliedTo = bar end
        end
        if (appliedTo and appliedTo == _G.EABBar_MainBar and tries >= 6) or tries >= 120 then
            t:Cancel()
        end
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        WatchBar()
    elseif event == "PLAYER_REGEN_ENABLED" and pendingRegen then
        pendingRegen = false
        if Apply() then appliedTo = _G.EABBar_MainBar end
    end
end)

-------------------------------------------------------------------------------
--  /eabtemp        status + what the game reports right now
--  /eabtemp fix    apply the Action Bar 1 paging again
-------------------------------------------------------------------------------
local function Call(name)
    local f = _G[name] or (C_ActionBar and C_ActionBar[name])
    if not f then return "n/a" end
    local ok, v = pcall(f)
    return ok and tostring(v) or "err"
end

local function SlotsUsed(page)
    local n, first = 0, nil
    for i = (page - 1) * 12 + 1, page * 12 do
        if HasAction(i) then
            n = n + 1
            if not first then
                local t, id = GetActionInfo(i)
                if t == "spell" and id then
                    first = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or tostring(id)
                else
                    first = tostring(t)
                end
            end
        end
    end
    return n, first
end

SLASH_EABTEMP1 = "/eabtemp"
SlashCmdList.EABTEMP = function(msg)
    msg = (msg or ""):lower()
    if msg == "fix" then
        if Apply() then
            appliedTo = _G.EABBar_MainBar
            print(PREFIX .. "Action Bar 1 paging applied.")
        else
            print(PREFIX .. "can't apply now: " .. (pendingRegen and "in combat, will retry after combat" or tostring(lastError)))
        end
        return
    end
    local bar = _G.EABBar_MainBar
    local idx = TempIndex()
    print(PREFIX .. "version 1.1.0, temp shapeshift page " .. tostring(idx)
        .. ", driver patched: " .. (lastValues and "|cff00ff00yes|r" or ("|cffff4040no|r (" .. tostring(lastError) .. ")"))
        .. ", Action Bar 1 page now: " .. tostring(bar and bar:GetAttribute("actionpage")))
    print("  TempShapeshift " .. Call("HasTempShapeshiftActionBar")
        .. ", Override " .. Call("HasOverrideActionBar")
        .. ", Vehicle " .. Call("HasVehicleActionBar")
        .. ", Possess " .. Call("IsPossessBarVisible")
        .. ", Bonus offset " .. Call("GetBonusBarOffset")
        .. ", Blizzard page " .. Call("GetActionBarPage"))
    local cond = SecureCmdOptionParse and SecureCmdOptionParse(
        "[shapeshift] shapeshift; [overridebar] override; [vehicleui] vehicle; [possessbar] possess; [bonusbar:5] bonus5; none")
    print("  macro conditions: " .. tostring(cond))
    if idx then
        local n, first = SlotsUsed(idx)
        print(("  temp page %d (slots %d-%d): %d action(s)%s"):format(idx, (idx - 1) * 12 + 1, idx * 12, n,
            first and (", e.g. " .. first) or ""))
    end
end
