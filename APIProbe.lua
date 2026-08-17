-- Azeroth API Probe
-- A dependency-free compatibility survey for the UE5-based 1.12 client.
-- Keep this source compatible with the old Lua dialect used by 1.12 addons.

APIProbe = APIProbe or {}

local AP = APIProbe
local VERSION = "0.2.2"
local MAX_DISPLAY = 180000
local MAX_EVENT_SAMPLES = 3
local REPORT_LINE_HEIGHT = 15
local REPORT_VISIBLE_ROWS = 28
local REPORT_WRAP_COLUMNS = 105
local REPORT_MOUSEWHEEL_LINES = 3

local tinsert = table.insert
local tconcat = table.concat
local tsort = table.sort
local getn = table.getn

local expectedGlobals = {
    {
        name = "Lua core",
        values = {
            "_G", "_VERSION", "assert", "collectgarbage", "error", "gcinfo",
            "getfenv", "getmetatable", "ipairs", "loadstring", "next", "pairs",
            "pcall", "rawequal", "rawget", "rawset", "setfenv", "setmetatable",
            "tonumber", "tostring", "type", "unpack", "xpcall",
            "coroutine", "debug", "io", "math", "os", "package", "string", "table"
        },
        expectedType = nil
    },
    {
        name = "Errors and diagnostics",
        values = {
            "debugstack", "geterrorhandler", "seterrorhandler", "message", "print",
            "ScriptErrors", "ScriptErrors_Message", "DEFAULT_CHAT_FRAME", "UIErrorsFrame"
        }
    },
    {
        name = "Addon management",
        values = {
            "GetNumAddOns", "GetAddOnInfo", "GetAddOnMetadata", "GetAddOnDependencies",
            "GetAddOnEnableState", "EnableAddOn", "DisableAddOn", "EnableAllAddOns",
            "DisableAllAddOns", "IsAddOnLoaded", "LoadAddOn"
        },
        expectedType = "function"
    },
    {
        name = "UI and client",
        values = {
            "CreateFrame", "CreateFont", "EnumerateFrames", "GetFramesRegisteredForEvent",
            "GetBuildInfo", "GetLocale", "GetTime", "GetGameTime", "GetFramerate",
            "GetNetStats", "GetCursorPosition", "GetScreenWidth", "GetScreenHeight",
            "GetCurrentKeyBoardFocus", "GetMouseFocus", "IsShiftKeyDown", "IsControlKeyDown",
            "IsAltKeyDown", "IsModifiedClick", "GetCVar", "SetCVar", "GetCVarDefault",
            "RegisterCVar", "ReloadUI", "Logout", "Quit", "ResetCPUUsage",
            "UpdateAddOnCPUUsage", "GetAddOnCPUUsage", "UpdateAddOnMemoryUsage",
            "GetAddOnMemoryUsage", "Screenshot", "SetPortraitTexture"
        },
        expectedType = "function"
    },
    {
        name = "Sound",
        values = {
            "PlaySound", "PlaySoundFile", "PlayMusic", "StopMusic", "SetSoundVolume",
            "SetMusicVolume", "SetAmbienceVolume", "SetMasterVolume"
        },
        expectedType = "function"
    },
    {
        name = "Units",
        values = {
            "UnitName", "UnitExists", "UnitIsVisible", "UnitIsConnected", "UnitClass",
            "UnitRace", "UnitSex", "UnitLevel", "UnitXP", "UnitXPMax", "UnitHealth",
            "UnitHealthMax", "UnitMana", "UnitManaMax", "UnitPowerType", "UnitFactionGroup",
            "UnitCreatureType", "UnitCreatureFamily", "UnitClassification", "UnitIsPlayer",
            "UnitIsUnit", "UnitIsFriend", "UnitIsEnemy", "UnitCanAttack", "UnitCanAssist",
            "UnitIsDead", "UnitIsDeadOrGhost", "UnitIsGhost", "UnitIsPVP", "UnitIsPVPFreeForAll",
            "UnitIsTapped", "UnitIsTappedByPlayer", "UnitReaction", "UnitAffectingCombat",
            "UnitIsPartyLeader", "UnitIsCivilian", "UnitPlayerControlled", "UnitPlayerOrPetInParty",
            "UnitPlayerOrPetInRaid", "UnitInParty", "UnitInRaid", "UnitOnTaxi", "UnitIsCharmed",
            "UnitIsPossessed", "UnitIsPlusMob", "UnitStat", "UnitDefense", "UnitResistance",
            "UnitAttackSpeed", "UnitAttackPower", "UnitRangedAttackPower", "UnitDamage",
            "UnitRangedDamage", "UnitArmor", "UnitBuff", "UnitDebuff", "UnitAura", "UnitGUID"
        },
        expectedType = "function"
    },
    {
        name = "Player and character",
        values = {
            "GetRealmName", "GetMoney", "GetCoinIcon", "GetBindLocation", "GetRestState",
            "GetXPExhaustion", "GetPVPRankInfo", "GetPVPRankProgress", "GetHonorCurrency",
            "GetHonorLastWeek", "GetHonorThisWeek", "GetInspectHonorData", "RequestInspectHonorData",
            "GetPlayerMapPosition", "CheckInteractDistance", "GetCorpseMapPosition",
            "GetDeathReleasePosition", "IsResting", "IsMounted", "IsSwimming", "IsFlying",
            "IsFalling", "IsStealthed", "IsIndoors", "IsOutdoors", "IsOutOfBounds",
            "GetComboPoints", "GetWeaponEnchantInfo", "GetCritChance", "GetBlockChance",
            "GetDodgeChance", "GetParryChance", "GetShieldBlock", "GetArmorPenetration"
        },
        expectedType = "function"
    },
    {
        name = "Spells and talents",
        values = {
            "GetNumSpellTabs", "GetSpellTabInfo", "GetSpellName", "GetSpellTexture",
            "GetSpellCooldown", "GetSpellAutocast", "GetSpellLevelLearned", "GetSpellRank",
            "GetSpellInfo", "GetSpellLink", "IsSpellKnown", "IsSpellInRange", "IsUsableSpell",
            "CastSpell", "CastSpellByName", "SpellStopCasting", "SpellStopTargeting",
            "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo",
            "GetTalentPrereqs", "LearnTalent", "GetUnspentTalentPoints"
        },
        expectedType = "function"
    },
    {
        name = "Actions, cursor, and targeting",
        values = {
            "GetActionInfo", "GetActionText", "GetActionTexture", "GetActionCount",
            "GetActionCooldown", "GetActionAutocast", "IsAttackAction", "IsCurrentAction",
            "IsAutoRepeatAction", "IsUsableAction", "HasAction", "UseAction", "PickupAction",
            "PlaceAction", "GetCursorInfo", "ClearCursor", "CursorHasItem", "CursorHasSpell",
            "CursorHasMoney", "DeleteCursorItem", "PickupSpell", "PickupMacro", "PickupInventoryItem",
            "TargetUnit", "TargetByName", "TargetLastTarget", "TargetNearestEnemy", "TargetNearestFriend",
            "AssistUnit", "FollowUnit", "InteractUnit", "AttackTarget", "StartAttack", "StopAttack"
        },
        expectedType = "function"
    },
    {
        name = "Inventory and containers",
        values = {
            "GetInventorySlotInfo", "GetInventoryItemTexture", "GetInventoryItemCount",
            "GetInventoryItemQuality", "GetInventoryItemCooldown", "GetInventoryItemLink",
            "GetInventoryItemDurability", "UseInventoryItem", "PickupInventoryItem",
            "GetContainerNumBags", "GetContainerNumSlots", "GetContainerItemInfo",
            "GetContainerItemLink", "GetContainerItemCooldown", "UseContainerItem",
            "PickupContainerItem", "SplitContainerItem", "PutItemInBackpack", "PutItemInBag",
            "OpenAllBags", "CloseAllBags", "ToggleBackpack", "ToggleBag", "GetItemInfo",
            "GetItemIcon", "GetItemCount", "IsEquippableItem", "IsEquippedItem", "EquipItemByName"
        },
        expectedType = "function"
    },
    {
        name = "Chat, social, and guild",
        values = {
            "SendChatMessage", "GetChannelName", "JoinChannelByName", "LeaveChannelByName",
            "ListChannelByName", "ChannelRoster", "GetNumDisplayChannels", "GetChannelDisplayInfo",
            "GetNumFriends", "GetFriendInfo", "ShowFriends", "AddFriend", "RemoveFriend",
            "SetFriendNotes", "GetNumIgnores", "GetIgnoreName", "AddIgnore", "DelIgnore",
            "GetGuildInfo", "IsInGuild", "GetNumGuildMembers", "GetGuildRosterInfo", "GuildRoster",
            "GuildInvite", "GuildUninvite", "GuildPromote", "GuildDemote", "GuildSetLeader",
            "GuildSetMOTD", "GuildLeave", "GetGuildRosterMOTD", "GetGuildRosterSelection",
            "SetGuildRosterSelection", "SetGuildRosterShowOffline"
        },
        expectedType = "function"
    },
    {
        name = "Party and raid",
        values = {
            "GetNumPartyMembers", "GetNumRaidMembers", "GetRaidRosterInfo", "GetRaidTargetIndex",
            "SetRaidTarget", "IsPartyLeader", "IsRaidLeader", "IsRaidOfficer", "InviteByName",
            "UninviteByName", "UninviteFromParty", "PromoteToPartyLeader", "ConvertToRaid",
            "SetLootMethod", "GetLootMethod", "GetLootThreshold", "GetMasterLootCandidate"
        },
        expectedType = "function"
    },
    {
        name = "Quest and map",
        values = {
            "GetNumQuestLogEntries", "GetQuestLogTitle", "SelectQuestLogEntry", "GetQuestLogSelection",
            "GetQuestLogQuestText", "GetQuestLogLeaderBoard", "GetNumQuestLeaderBoards",
            "IsQuestWatched", "AddQuestWatch", "RemoveQuestWatch", "GetNumQuestWatches",
            "GetQuestIndexForWatch", "GetQuestLogTimeLeft", "GetQuestGreenRange", "GetQuestDifficultyColor",
            "GetMapInfo", "SetMapToCurrentZone", "GetCurrentMapContinent", "GetCurrentMapZone",
            "GetMapContinents", "GetMapZones", "GetNumMapLandmarks", "GetMapLandmarkInfo",
            "GetWorldMapTransformInfo", "UpdateMapHighlight", "GetMapOverlayInfo"
        },
        expectedType = "function"
    },
    {
        name = "Mail, trade, auction, and loot",
        values = {
            "GetInboxNumItems", "GetInboxHeaderInfo", "GetInboxText", "GetInboxItem",
            "GetInboxItemLink", "TakeInboxItem", "TakeInboxMoney", "DeleteInboxItem", "SendMail",
            "GetSendMailItem", "GetSendMailItemLink", "SetSendMailMoney", "ClearSendMail",
            "GetTradeTargetItemInfo", "GetTradePlayerItemInfo", "GetTradeTargetItemLink",
            "GetTradePlayerItemLink", "AcceptTrade", "CancelTrade", "InitiateTrade",
            "GetNumAuctionItems", "GetAuctionItemInfo", "GetAuctionItemLink", "GetAuctionItemTimeLeft",
            "QueryAuctionItems", "PlaceAuctionBid", "StartAuction", "CancelAuction", "CloseAuctionHouse",
            "GetNumLootItems", "GetLootSlotInfo", "GetLootSlotLink", "LootSlot", "CloseLoot"
        },
        expectedType = "function"
    },
    {
        name = "Pet, trade skill, and trainer",
        values = {
            "PetAttack", "PetFollow", "PetPassiveMode", "PetDefensiveMode", "PetAggressiveMode",
            "GetPetActionInfo", "GetPetActionCooldown", "PickupPetAction", "TogglePetAutocast",
            "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillIcon", "GetTradeSkillNumMade",
            "GetTradeSkillCooldown", "GetTradeSkillItemLink", "GetTradeSkillRecipeLink",
            "DoTradeSkill", "SelectTradeSkill", "GetNumCrafts", "GetCraftInfo", "DoCraft",
            "GetNumTrainerServices", "GetTrainerServiceInfo", "BuyTrainerService", "SetTrainerServiceTypeFilter"
        },
        expectedType = "function"
    },
    {
        name = "Bindings and macros",
        values = {
            "GetNumBindings", "GetBinding", "GetBindingKey", "GetBindingAction", "SetBinding",
            "SetBindingSpell", "SetBindingItem", "SetBindingMacro", "SaveBindings", "LoadBindings",
            "GetNumMacros", "GetMacroInfo", "GetMacroBody", "CreateMacro", "EditMacro", "DeleteMacro",
            "RunMacro", "RunMacroText"
        },
        expectedType = "function"
    }
}

local objectMethodSets = {
    Region = {
        "GetAlpha", "SetAlpha", "GetDrawLayer", "SetDrawLayer", "GetHeight", "SetHeight",
        "GetWidth", "SetWidth", "GetScale", "SetScale", "GetEffectiveScale", "GetPoint",
        "SetPoint", "GetNumPoints", "ClearAllPoints", "SetAllPoints", "IsVisible", "IsShown",
        "Show", "Hide", "GetParent", "SetParent", "GetLeft", "GetRight", "GetTop", "GetBottom",
        "GetCenter", "GetName", "GetObjectType", "IsObjectType"
    },
    Frame = {
        "EnableMouse", "IsMouseEnabled", "EnableMouseWheel", "IsMouseWheelEnabled", "GetFrameLevel",
        "SetFrameLevel", "GetFrameStrata", "SetFrameStrata", "GetID", "SetID", "RegisterEvent",
        "UnregisterEvent", "UnregisterAllEvents", "IsEventRegistered", "SetScript", "GetScript",
        "HasScript", "HookScript", "SetBackdrop", "GetBackdrop", "SetBackdropColor", "GetBackdropColor",
        "SetBackdropBorderColor", "GetBackdropBorderColor", "SetClampedToScreen", "IsClampedToScreen",
        "SetMovable", "IsMovable", "SetResizable", "IsResizable", "SetMinResize", "SetMaxResize",
        "StartMoving", "StopMovingOrSizing", "RegisterForDrag", "Raise", "Lower", "SetToplevel",
        "IsToplevel", "SetUserPlaced", "IsUserPlaced", "SetHitRectInsets", "GetHitRectInsets",
        "GetChildren", "GetNumChildren", "GetRegions", "GetNumRegions", "SetAttribute", "GetAttribute"
    },
    Button = {
        "Click", "RegisterForClicks", "SetButtonState", "GetButtonState", "SetText", "GetText",
        "SetNormalTexture", "GetNormalTexture", "SetPushedTexture", "GetPushedTexture",
        "SetDisabledTexture", "GetDisabledTexture", "SetHighlightTexture", "GetHighlightTexture",
        "SetNormalFontObject", "GetNormalFontObject", "SetDisabledFontObject", "GetDisabledFontObject",
        "SetHighlightFontObject", "GetHighlightFontObject", "LockHighlight", "UnlockHighlight",
        "GetFontString", "SetFontString", "IsEnabled", "Enable", "Disable"
    },
    CheckButton = {
        "SetChecked", "GetChecked", "SetCheckedTexture", "GetCheckedTexture",
        "SetDisabledCheckedTexture", "GetDisabledCheckedTexture"
    },
    EditBox = {
        "SetText", "GetText", "Insert", "SetCursorPosition", "GetCursorPosition", "HighlightText",
        "SetTextInsets", "GetTextInsets", "SetMaxLetters", "GetMaxLetters", "SetMaxBytes", "GetMaxBytes",
        "SetMultiLine", "IsMultiLine", "SetAutoFocus", "IsAutoFocus", "SetNumeric", "IsNumeric",
        "SetPassword", "IsPassword", "SetNumber", "GetNumber", "SetFocus", "ClearFocus",
        "HasFocus", "SetFontObject", "GetFontObject", "SetFont", "GetFont", "GetStringHeight"
    },
    ScrollFrame = {
        "SetScrollChild", "GetScrollChild", "SetHorizontalScroll", "GetHorizontalScroll",
        "GetHorizontalScrollRange", "SetVerticalScroll", "GetVerticalScroll", "GetVerticalScrollRange",
        "UpdateScrollChildRect"
    },
    Slider = {
        "SetMinMaxValues", "GetMinMaxValues", "SetValue", "GetValue", "SetValueStep", "GetValueStep",
        "SetThumbTexture", "GetThumbTexture", "SetOrientation", "GetOrientation"
    },
    StatusBar = {
        "SetMinMaxValues", "GetMinMaxValues", "SetValue", "GetValue", "SetStatusBarColor",
        "GetStatusBarColor", "SetStatusBarTexture", "GetStatusBarTexture", "SetOrientation", "GetOrientation"
    },
    FontString = {
        "SetText", "GetText", "SetFormattedText", "SetFont", "GetFont", "SetFontObject", "GetFontObject",
        "SetTextColor", "GetTextColor", "SetJustifyH", "GetJustifyH", "SetJustifyV", "GetJustifyV",
        "SetSpacing", "GetSpacing", "SetShadowColor", "GetShadowColor", "SetShadowOffset",
        "GetShadowOffset", "GetStringWidth", "GetStringHeight", "SetNonSpaceWrap", "CanNonSpaceWrap",
        "SetIndentedWordWrap", "GetIndentedWordWrap"
    },
    Texture = {
        "SetTexture", "GetTexture", "SetTexCoord", "GetTexCoord", "SetVertexColor", "GetVertexColor",
        "SetBlendMode", "GetBlendMode", "SetGradient", "SetGradientAlpha"
    }
}

local watchedEvents = {
    "ADDON_LOADED", "VARIABLES_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "CVAR_UPDATE", "CHAT_MSG_SYSTEM", "CHAT_MSG_ADDON",
    "BAG_UPDATE", "ITEM_LOCK_CHANGED", "UNIT_INVENTORY_CHANGED", "ACTIONBAR_SLOT_CHANGED",
    "SPELLS_CHANGED", "PLAYER_TARGET_CHANGED", "CURSOR_UPDATE", "UPDATE_MOUSEOVER_UNIT",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_HEALTH", "UNIT_MANA",
    "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_MONEY", "QUEST_LOG_UPDATE", "UPDATE_BINDINGS",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN"
}

local function EnsureDB()
    if type(APIProbeDB) ~= "table" then
        APIProbeDB = {}
    end
    if APIProbeDB.version and APIProbeDB.version ~= VERSION then
        -- Event samples are cumulative by design, but carrying them across a
        -- probe-version change makes a supposedly clean run misleading.
        APIProbeDB.events = {}
        APIProbeDB.eventRegistrations = {}
    end
    if type(APIProbeDB.events) ~= "table" then
        APIProbeDB.events = {}
    end
    if type(APIProbeDB.eventRegistrations) ~= "table" then
        APIProbeDB.eventRegistrations = {}
    end
    if APIProbeDB.captureEvents == nil then
        APIProbeDB.captureEvents = true
    end
    APIProbeDB.version = VERSION
end

local function Chat(text)
    local msg = "APIProbe: " .. tostring(text)
    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    elseif UIErrorsFrame and type(UIErrorsFrame.AddMessage) == "function" then
        UIErrorsFrame:AddMessage(msg)
    end
end

local function Trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function OneLine(value)
    local valueType = type(value)
    local ok, text = pcall(tostring, value)
    if not ok then
        text = "<tostring failed>"
    end
    text = string.gsub(text or "", "\r", "\\r")
    text = string.gsub(text, "\n", "\\n")
    if string.len(text) > 180 then
        text = string.sub(text, 1, 177) .. "..."
    end
    return valueType .. ":" .. text
end

local function ReturnValues(a, b, c, d, e, f, g)
    local values = {a, b, c, d, e, f, g}
    local last = 0
    local i
    for i = 1, 7 do
        if values[i] ~= nil then
            last = i
        end
    end
    if last == 0 then
        return "(no non-nil return values)"
    end
    local parts = {}
    for i = 1, last do
        tinsert(parts, tostring(i) .. "=" .. OneLine(values[i]))
    end
    return tconcat(parts, "  ")
end

local function CaptureCall(func)
    local ok, a, b, c, d, e, f, g = pcall(func)
    if not ok then
        return "ERROR", OneLine(a)
    end
    return "OK", ReturnValues(a, b, c, d, e, f, g)
end

local function AddCall(lines, label, func)
    local status, detail = CaptureCall(func)
    tinsert(lines, label .. " = " .. status .. " | " .. detail)
    return status, detail
end

local function SortCaseInsensitive(a, b)
    return string.lower(a) < string.lower(b)
end

local function ScanGlobals()
    EnsureDB()
    local allRows = {}
    local functionRows = {}
    local nativeRows = {}
    local luaRows = {}
    local unknownOriginRows = {}
    local origins = {}
    local types = {}
    local counts = {}
    local key, value, kind, row, origin
    for key, value in pairs(_G) do
        if type(key) == "string" then
            kind = type(value)
            types[key] = kind
            counts[kind] = (counts[kind] or 0) + 1
            row = key .. "\t" .. kind
            tinsert(allRows, row)
            if kind == "function" then
                tinsert(functionRows, key)
                origin = "unknown"
                if type(debug) == "table" and type(debug.getinfo) == "function" then
                    local infoOK, info = pcall(debug.getinfo, value, "S")
                    if infoOK and type(info) == "table" then
                        local what = tostring(info.what or "unknown")
                        local source = tostring(info.source or "unknown")
                        source = string.gsub(source, "\r", "")
                        source = string.gsub(source, "\n", " ")
                        origin = what .. "\t" .. source .. "\t" .. tostring(info.linedefined or 0)
                        if what == "C" or source == "=[C]" or source == "[C]" then
                            tinsert(nativeRows, key)
                        else
                            tinsert(luaRows, key .. "\t" .. source .. ":" .. tostring(info.linedefined or 0))
                        end
                    else
                        tinsert(unknownOriginRows, key)
                    end
                else
                    tinsert(unknownOriginRows, key)
                end
                origins[key] = origin
            end
        end
    end
    tsort(allRows, SortCaseInsensitive)
    tsort(functionRows, SortCaseInsensitive)
    tsort(nativeRows, SortCaseInsensitive)
    tsort(luaRows, SortCaseInsensitive)
    tsort(unknownOriginRows, SortCaseInsensitive)
    APIProbeDB.globalTypes = types
    APIProbeDB.globalCounts = counts
    APIProbeDB.functionOrigins = origins
    APIProbeDB.globalInventory = tconcat(allRows, "\n")
    APIProbeDB.functionInventory = tconcat(functionRows, "\n")
    APIProbeDB.nativeFunctionInventory = tconcat(nativeRows, "\n")
    APIProbeDB.luaFunctionInventory = tconcat(luaRows, "\n")
    APIProbeDB.unknownOriginInventory = tconcat(unknownOriginRows, "\n")
    APIProbeDB.originCounts = {
        native = getn(nativeRows),
        lua = getn(luaRows),
        unknown = getn(unknownOriginRows)
    }
end

local function ExpectedTypeFor(category, globalName)
    if category.expectedType then
        return category.expectedType
    end
    if globalName == "_VERSION" then
        return "string"
    end
    if globalName == "_G" or globalName == "coroutine" or globalName == "debug" or
       globalName == "io" or globalName == "math" or globalName == "os" or
       globalName == "package" or globalName == "string" or globalName == "table" or
       globalName == "ScriptErrors" or globalName == "ScriptErrors_Message" or
       globalName == "DEFAULT_CHAT_FRAME" or globalName == "UIErrorsFrame" then
        return nil
    end
    return "function"
end

local function ProbeExpectedGlobals()
    local lines = {}
    local missingLines = {}
    local total = 0
    local present = 0
    local missing = 0
    local wrong = 0
    local categoryIndex, nameIndex, category, globalName, actual, expected

    tinsert(lines, "EXPECTED GLOBAL API SURVEY")
    tinsert(lines, "Existence/type checks only; no potentially disruptive global API is invoked.")
    tinsert(lines, "")

    for categoryIndex = 1, getn(expectedGlobals) do
        category = expectedGlobals[categoryIndex]
        local categoryTotal = getn(category.values)
        local categoryPresent = 0
        local categoryMissing = 0
        local categoryWrong = 0
        local categoryProblems = {}
        for nameIndex = 1, categoryTotal do
            globalName = category.values[nameIndex]
            actual = type(_G[globalName])
            expected = ExpectedTypeFor(category, globalName)
            total = total + 1
            if actual == "nil" then
                missing = missing + 1
                categoryMissing = categoryMissing + 1
                tinsert(categoryProblems, "  MISSING     " .. globalName)
                tinsert(missingLines, category.name .. "\tMISSING\t" .. globalName)
            elseif expected and actual ~= expected then
                wrong = wrong + 1
                categoryWrong = categoryWrong + 1
                tinsert(categoryProblems, "  WRONG TYPE  " .. globalName .. " (expected " .. expected .. ", got " .. actual .. ")")
                tinsert(missingLines, category.name .. "\tWRONG TYPE " .. actual .. "\t" .. globalName)
            else
                present = present + 1
                categoryPresent = categoryPresent + 1
            end
        end
        tinsert(lines, category.name .. ": " .. categoryPresent .. "/" .. categoryTotal ..
            " present; " .. categoryMissing .. " missing; " .. categoryWrong .. " wrong type")
        for nameIndex = 1, getn(categoryProblems) do
            tinsert(lines, categoryProblems[nameIndex])
        end
        tinsert(lines, "")
    end

    APIProbeDB.expectedSummary = {
        total = total,
        present = present,
        missing = missing,
        wrongType = wrong
    }
    APIProbeDB.expectedReport = tconcat(lines, "\n")
    if getn(missingLines) == 0 then
        APIProbeDB.missingReport = "No expected globals were missing or the wrong type."
    else
        APIProbeDB.missingReport = "Category\tStatus\tGlobal\n" .. tconcat(missingLines, "\n")
    end
end

local function SyntaxProbe(lines, label, source, executeResult)
    if type(loadstring) ~= "function" then
        tinsert(lines, label .. " = UNAVAILABLE | loadstring is missing")
        return
    end
    local ok, chunkOrError = pcall(loadstring, source)
    if not ok then
        tinsert(lines, label .. " = ERROR | loadstring call failed: " .. OneLine(chunkOrError))
        return
    end
    if type(chunkOrError) ~= "function" then
        tinsert(lines, label .. " = REJECTED | " .. OneLine(chunkOrError))
        return
    end
    if not executeResult then
        tinsert(lines, label .. " = COMPILES ONLY | this does not prove referenced globals work")
        return
    end
    local status, detail = CaptureCall(chunkOrError)
    tinsert(lines, label .. " = " .. status .. " | " .. detail)
end

local function ProbeLuaAndClient()
    local lines = {}
    tinsert(lines, "LUA AND CLIENT PROBES")
    tinsert(lines, "")
    tinsert(lines, "_VERSION = " .. OneLine(_VERSION))
    tinsert(lines, "Lua library types:")
    local libraries = {"coroutine", "debug", "io", "math", "os", "package", "string", "table"}
    local i
    for i = 1, getn(libraries) do
        tinsert(lines, "  " .. libraries[i] .. " = " .. type(_G[libraries[i]]))
    end
    tinsert(lines, "")
    tinsert(lines, "Syntax/runtime feature probes:")
    SyntaxProbe(lines, "  length operator #", "return #({10, 20, 30})", true)
    SyntaxProbe(lines, "  modulo operator %", "return 7 % 4", true)
    SyntaxProbe(lines, "  modern vararg expression", "return function(...) return ... end", false)
    SyntaxProbe(lines, "  legacy vararg table", "return function(...) return table.getn(arg) end", false)
    SyntaxProbe(lines, "  source referencing select", "return function(...) return select('#', ...) end", false)
    SyntaxProbe(lines, "  local function closure", "local x = 17; return function() return x end", true)
    tinsert(lines, "")
    tinsert(lines, "Client calls:")
    if type(GetBuildInfo) == "function" then
        AddCall(lines, "  GetBuildInfo()", function() return GetBuildInfo() end)
    end
    if type(GetLocale) == "function" then
        AddCall(lines, "  GetLocale()", function() return GetLocale() end)
    end
    if type(GetTime) == "function" then
        AddCall(lines, "  GetTime()", function() return GetTime() end)
    end
    if type(GetGameTime) == "function" then
        AddCall(lines, "  GetGameTime()", function() return GetGameTime() end)
    end
    if type(GetScreenWidth) == "function" then
        AddCall(lines, "  GetScreenWidth()", function() return GetScreenWidth() end)
    end
    if type(GetScreenHeight) == "function" then
        AddCall(lines, "  GetScreenHeight()", function() return GetScreenHeight() end)
    end
    if type(GetNetStats) == "function" then
        AddCall(lines, "  GetNetStats()", function() return GetNetStats() end)
    end
    tinsert(lines, "")
    tinsert(lines, "Known compatibility-sensitive globals:")
    local critical = {"geterrorhandler", "seterrorhandler", "debugstack", "PlaySound", "PlaySoundFile", "GetAddOnEnableState"}
    for i = 1, getn(critical) do
        tinsert(lines, "  " .. critical[i] .. " = " .. type(_G[critical[i]]))
    end
    APIProbeDB.luaClientReport = tconcat(lines, "\n")
end

local function ProbeLibrarySurface()
    local lines = {}
    local libraries = {"string", "table", "math", "coroutine", "debug", "bit"}
    local libraryIndex, key, value, kind
    local memberCount = 0
    local functionCount = 0
    local inventory = {}

    tinsert(lines, "LUA 5.1 AND EXTENSION LIBRARY SURFACE")
    tinsert(lines, "This enumerates table members; it does not assume that callable members are functional.")
    tinsert(lines, "")
    tinsert(lines, "Lua 5.1 top-level globals not covered by the original 1.12 checklist:")
    local extraGlobals = {"load", "loadfile", "dofile", "module", "require", "select", "newproxy", "jit", "bit", "bit32"}
    for libraryIndex = 1, getn(extraGlobals) do
        key = extraGlobals[libraryIndex]
        tinsert(lines, "  " .. key .. " = " .. type(_G[key]))
    end
    tinsert(lines, "")

    for libraryIndex = 1, getn(libraries) do
        local libraryName = libraries[libraryIndex]
        local library = _G[libraryName]
        local rows = {}
        if type(library) ~= "table" then
            tinsert(lines, libraryName .. " = " .. type(library))
        else
            for key, value in pairs(library) do
                if type(key) == "string" then
                    kind = type(value)
                    tinsert(rows, "  " .. libraryName .. "." .. key .. " = " .. kind)
                    tinsert(inventory, libraryName .. "." .. key .. "\t" .. kind)
                    memberCount = memberCount + 1
                    if kind == "function" then
                        functionCount = functionCount + 1
                    end
                end
            end
            tsort(rows, SortCaseInsensitive)
            tinsert(lines, libraryName .. ": " .. tostring(getn(rows)) .. " members")
            local rowIndex
            for rowIndex = 1, getn(rows) do
                tinsert(lines, rows[rowIndex])
            end
        end
        tinsert(lines, "")
    end

    tsort(inventory, SortCaseInsensitive)
    APIProbeDB.libraryInventory = tconcat(inventory, "\n")
    APIProbeDB.libraryCounts = {members = memberCount, functions = functionCount}
    APIProbeDB.libraryReport = tconcat(lines, "\n")
end

local function ProbeBehavior()
    local lines = {}
    local stats = {verified = 0, failed = 0, error = 0, unavailable = 0, unverified = 0, manual = 0, notCalled = 0}

    local function AddResult(label, status, detail)
        if status == "VERIFIED" then
            stats.verified = stats.verified + 1
        elseif status == "FAILED" then
            stats.failed = stats.failed + 1
        elseif status == "ERROR" then
            stats.error = stats.error + 1
        elseif status == "UNAVAILABLE" then
            stats.unavailable = stats.unavailable + 1
        elseif status == "CALL SUCCEEDED; OUTPUT UNVERIFIED" then
            stats.unverified = stats.unverified + 1
        elseif status == "MANUAL ONLY" then
            stats.manual = stats.manual + 1
        elseif status == "NOT CALLED" then
            stats.notCalled = stats.notCalled + 1
        end
        tinsert(lines, label .. " = " .. status .. (detail and (" | " .. detail) or ""))
    end

    local function RunTest(label, func, validator)
        local ok, a, b, c, d, e, f, g = pcall(func)
        if not ok then
            AddResult(label, "ERROR", OneLine(a))
            return
        end
        local validateOK, passed, note = pcall(validator, a, b, c, d, e, f, g)
        if not validateOK then
            AddResult(label, "ERROR", "validator failed: " .. OneLine(passed))
        elseif passed then
            AddResult(label, "VERIFIED", note or ReturnValues(a, b, c, d, e, f, g))
        else
            AddResult(label, "FAILED", note or ReturnValues(a, b, c, d, e, f, g))
        end
    end

    local function Unavailable(label, dependency)
        AddResult(label, "UNAVAILABLE", dependency)
    end

    local function CallOnly(label, func)
        local status, detail = CaptureCall(func)
        if status == "OK" then
            AddResult(label, "CALL SUCCEEDED; OUTPUT UNVERIFIED", detail)
        else
            AddResult(label, "ERROR", detail)
        end
    end

    tinsert(lines, "OBSERVABLE BEHAVIOUR PROBES")
    tinsert(lines, "VERIFIED requires a deterministic return value or an independently readable state change.")
    tinsert(lines, "A successful call alone is explicitly not treated as proof of implementation.")
    tinsert(lines, "")
    tinsert(lines, "Lua execution and error handling")

    if type(loadstring) == "function" then
        RunTest("loadstring executes a chunk", function()
            local chunk = loadstring("return 6 * 7")
            if type(chunk) ~= "function" then return nil end
            return chunk()
        end, function(a) return a == 42, "expected 42; got " .. OneLine(a) end)

        RunTest("modern varargs preserve a nil middle value", function()
            local chunk = loadstring("local f=function(...) return ... end; return f(11,nil,33)")
            if type(chunk) ~= "function" then return nil end
            return chunk()
        end, function(a, b, c)
            return a == 11 and b == nil and c == 33,
                "expected number:11, nil, number:33; got " .. ReturnValues(a, b, c)
        end)

        RunTest("legacy implicit arg table and arg.n", function()
            local chunk = loadstring("local f=function(...) return type(arg),arg and arg.n,arg and arg[1],arg and arg[2],arg and arg[3] end; return f(11,nil,33)")
            if type(chunk) ~= "function" then return nil end
            return chunk()
        end, function(a, b, c, d, e)
            return a == "table" and b == 3 and c == 11 and d == nil and e == 33,
                "expected table,3,11,nil,33; got " .. ReturnValues(a, b, c, d, e)
        end)
    else
        Unavailable("loadstring executes a chunk", "loadstring is missing")
        Unavailable("modern varargs preserve a nil middle value", "loadstring is missing")
        Unavailable("legacy implicit arg table and arg.n", "loadstring is missing")
    end

    if type(select) == "function" then
        RunTest("select handles count and nil values", function()
            return select("#", 11, nil, 33), select(2, 11, nil, 33)
        end, function(a, b, c)
            return a == 3 and b == nil and c == 33,
                "expected 3,nil,33; got " .. ReturnValues(a, b, c)
        end)
    else
        Unavailable("select handles count and nil values", "select is " .. type(select))
    end

    if type(pcall) == "function" then
        RunTest("pcall catches an error", function()
            return pcall(function() error("APIProbe sentinel") end)
        end, function(a, b)
            return a == false and type(b) == "string" and string.find(b, "APIProbe sentinel", 1, true) ~= nil,
                "expected false and sentinel text; got " .. ReturnValues(a, b)
        end)
    end
    if type(xpcall) == "function" then
        RunTest("xpcall invokes its handler", function()
            return xpcall(function() error("APIProbe xpcall sentinel") end,
                function(err) return "handled:" .. tostring(err) end)
        end, function(a, b)
            return a == false and type(b) == "string" and string.find(b, "handled:", 1, true) ~= nil,
                "expected false and handled text; got " .. ReturnValues(a, b)
        end)
    end
    if type(collectgarbage) == "function" then
        RunTest("collectgarbage('count') uses Lua 5.1 calling convention", function()
            return collectgarbage("count")
        end, function(a)
            return type(a) == "number" and a >= 0, "expected non-negative number; got " .. OneLine(a)
        end)
    else
        Unavailable("collectgarbage('count') uses Lua 5.1 calling convention", "collectgarbage is missing")
    end

    tinsert(lines, "")
    tinsert(lines, "Lua libraries")
    if type(string.match) == "function" then
        RunTest("string.match captures digits", function() return string.match("abc123", "(%d+)") end,
            function(a) return a == "123", "expected string:123; got " .. OneLine(a) end)
    else
        Unavailable("string.match captures digits", "string.match is missing")
    end
    if type(string.gmatch) == "function" then
        RunTest("string.gmatch iterates captures", function()
            local iterator = string.gmatch("a1 b2", "(%a)%d")
            local first = iterator()
            local second = iterator()
            local third = iterator()
            return first, second, third
        end, function(a, b, c)
            return a == "a" and b == "b" and c == nil,
                "expected a,b,nil; got " .. ReturnValues(a, b, c)
        end)
    else
        Unavailable("string.gmatch iterates captures", "string.gmatch is missing")
    end
    if type(table.maxn) == "function" then
        RunTest("table.maxn finds sparse numeric key", function() return table.maxn({[2] = true, [7] = true}) end,
            function(a) return a == 7, "expected number:7; got " .. OneLine(a) end)
    else
        Unavailable("table.maxn finds sparse numeric key", "table.maxn is missing")
    end
    if type(math.fmod) == "function" then
        RunTest("math.fmod computes remainder", function() return math.fmod(7, 4) end,
            function(a) return a == 3, "expected number:3; got " .. OneLine(a) end)
    else
        Unavailable("math.fmod computes remainder", "math.fmod is missing")
    end
    if type(coroutine) == "table" and type(coroutine.create) == "function" and type(coroutine.resume) == "function" then
        RunTest("coroutine create/resume/yield", function()
            local thread = coroutine.create(function()
                coroutine.yield(7)
                return 9
            end)
            local ok1, first = coroutine.resume(thread)
            local state = coroutine.status(thread)
            local ok2, second = coroutine.resume(thread)
            return ok1, first, state, ok2, second, coroutine.status(thread)
        end, function(a, b, c, d, e, f)
            return a == true and b == 7 and c == "suspended" and d == true and e == 9 and f == "dead",
                "expected true,7,suspended,true,9,dead; got " .. ReturnValues(a, b, c, d, e, f)
        end)
    else
        Unavailable("coroutine create/resume/yield", "coroutine functions are incomplete")
    end
    if type(debug) == "table" and type(debug.getinfo) == "function" then
        RunTest("debug.getinfo identifies a Lua function", function()
            local info = debug.getinfo(function() return true end, "S")
            return type(info), info and info.what, info and type(info.source)
        end, function(a, b, c)
            return a == "table" and b == "Lua" and c == "string",
                "expected table,Lua,string; got " .. ReturnValues(a, b, c)
        end)
    else
        Unavailable("debug.getinfo identifies a Lua function", "debug.getinfo is missing")
    end

    if type(bit) == "table" and type(bit.band) == "function" then
        RunTest("bit.band performs bitwise AND", function() return bit.band(240, 204) end,
            function(a) return a == 192, "expected number:192; got " .. OneLine(a) end)
    else
        Unavailable("bit.band performs bitwise AND", "bit.band is missing")
    end
    if type(bit) == "table" and type(bit.bxor) == "function" then
        RunTest("bit.bxor performs bitwise XOR", function() return bit.bxor(240, 204) end,
            function(a) return a == 60, "expected number:60; got " .. OneLine(a) end)
    else
        Unavailable("bit.bxor performs bitwise XOR", "bit.bxor is missing")
    end
    if type(bit) == "table" and type(bit.lshift) == "function" then
        RunTest("bit.lshift shifts left", function() return bit.lshift(1, 4) end,
            function(a) return a == 16, "expected number:16; got " .. OneLine(a) end)
    else
        Unavailable("bit.lshift shifts left", "bit.lshift is missing")
    end

    tinsert(lines, "")
    tinsert(lines, "WoW/client API with deterministic observations")
    if type(GetBuildInfo) == "function" then
        RunTest("GetBuildInfo returns client identity", function() return GetBuildInfo() end,
        function(a, b, c, d, e, f, g)
            local standardShape = type(a) == "string" and (type(b) == "string" or type(b) == "number") and
                type(c) == "string" and type(d) == "number" and e == nil
            local customShape = type(a) == "string" and type(b) == "string" and type(c) == "string" and
                type(d) == "number" and type(e) == "string" and f ~= nil and type(g) == "string"
            return standardShape or customShape, "got " .. ReturnValues(a, b, c, d, e, f, g)
        end)
    else
        Unavailable("GetBuildInfo returns client identity", "GetBuildInfo is missing")
    end
    if type(GetTime) == "function" then
        RunTest("GetTime returns a non-negative clock", function() return GetTime() end,
            function(a) return type(a) == "number" and a >= 0, "got " .. OneLine(a) end)
    end
    if type(GetGameTime) == "function" then
        RunTest("GetGameTime returns valid hour/minute", function() return GetGameTime() end,
            function(a, b)
                return type(a) == "number" and a >= 0 and a <= 23 and type(b) == "number" and b >= 0 and b <= 59,
                    "got " .. ReturnValues(a, b)
            end)
    end
    if type(GetScreenWidth) == "function" and type(GetScreenHeight) == "function" then
        RunTest("screen dimensions are positive", function() return GetScreenWidth(), GetScreenHeight() end,
            function(a, b)
                return type(a) == "number" and a > 0 and type(b) == "number" and b > 0,
                    "got " .. ReturnValues(a, b)
            end)
    end
    if type(GetCursorPosition) == "function" then
        RunTest("GetCursorPosition returns coordinates", function() return GetCursorPosition() end,
            function(a, b)
                return type(a) == "number" and type(b) == "number", "got " .. ReturnValues(a, b)
            end)
    end
    if type(GetNumAddOns) == "function" then
        RunTest("GetNumAddOns returns a positive count", function() return GetNumAddOns() end,
            function(a) return type(a) == "number" and a >= 1, "got " .. OneLine(a) end)
    end
    if type(IsAddOnLoaded) == "function" then
        RunTest("IsAddOnLoaded confirms APIProbe", function() return IsAddOnLoaded("APIProbe") end,
            function(a) return a == true or a == 1, "got " .. OneLine(a) end)
    end
    if type(GetCVar) == "function" then
        RunTest("GetCVar reads a known graphics CVar", function() return GetCVar("gxResolution") end,
            function(a) return a ~= nil and type(a) ~= "function", "got " .. OneLine(a) end)
    end
    if type(UnitExists) == "function" then
        RunTest("UnitExists recognises player", function() return UnitExists("player") end,
            function(a) return a == true or a == 1, "got " .. OneLine(a) end)
    end
    if type(UnitName) == "function" then
        RunTest("UnitName returns a player name", function() return type(UnitName("player")) end,
            function(a) return a == "string", "returned value type=" .. OneLine(a) end)
    end
    if type(UnitHealth) == "function" and type(UnitHealthMax) == "function" then
        RunTest("UnitHealth values are coherent", function() return UnitHealth("player"), UnitHealthMax("player") end,
            function(a, b)
                return type(a) == "number" and type(b) == "number" and a >= 0 and b >= 1 and a <= b,
                    "got " .. ReturnValues(a, b)
            end)
    end
    if type(GetMoney) == "function" then
        RunTest("GetMoney returns a non-negative amount", function() return GetMoney() end,
            function(a) return type(a) == "number" and a >= 0, "got " .. OneLine(a) end)
    end
    if type(GetContainerNumSlots) == "function" then
        RunTest("GetContainerNumSlots returns backpack capacity", function() return GetContainerNumSlots(0) end,
            function(a) return type(a) == "number" and a >= 0, "got " .. OneLine(a) end)
    end
    if type(IsInInstance) == "function" then
        CallOnly("IsInInstance()", function() return IsInInstance() end)
    end

    if type(RunScript) == "function" then
        RunTest("RunScript changes the global environment", function()
            APIProbe_RunScriptSentinel = nil
            RunScript("APIProbe_RunScriptSentinel = 24681357")
            local value = APIProbe_RunScriptSentinel
            APIProbe_RunScriptSentinel = nil
            return value
        end, function(a) return a == 24681357, "expected 24681357; got " .. OneLine(a) end)
    else
        Unavailable("RunScript changes the global environment", "RunScript is missing")
    end

    if type(GetScriptMemory) == "function" then
        RunTest("GetScriptMemory returns a measurement", function() return GetScriptMemory() end,
            function(a) return type(a) == "number" and a >= 0, "got " .. OneLine(a) end)
    else
        Unavailable("GetScriptMemory returns a measurement", "GetScriptMemory is missing")
    end
    if type(GetDebugStats) == "function" then
        CallOnly("GetDebugStats()", function() return GetDebugStats() end)
    end

    tinsert(lines, "")
    tinsert(lines, "Functions requiring manual observation or deliberately not called")
    if type(print) == "function" then
        AddResult("print", "MANUAL ONLY", "use /apitestprint; output may target an invisible UE log")
    else
        Unavailable("print", "print is missing")
    end
    if type(PlaySound) == "function" then
        AddResult("PlaySound", "MANUAL ONLY", "use /apitestsound and listen for a UI sound")
    else
        Unavailable("PlaySound", "PlaySound is missing")
    end
    AddResult("seterrorhandler", "NOT CALLED", "changing the process-wide handler would alter subsequent diagnostics")
    AddResult("ConsoleExec", "NOT CALLED", "arbitrary console commands may change client state")
    AddResult("SetScriptMemory", "NOT CALLED", "unknown process-wide memory effect")
    AddResult("debug_break/debugger_attach", "NOT CALLED", "may pause or attach to the Shipping process")

    APIProbeDB.behaviorStats = stats
    APIProbeDB.behaviorReport = tconcat(lines, "\n")
end

local function BuildManualReport()
    local lines = {}
    tinsert(lines, "MANUAL OBSERVATION TESTS")
    tinsert(lines, "")
    tinsert(lines, "Some effects have no independent Lua-readable state, so APIProbe cannot honestly mark them verified.")
    tinsert(lines, "")
    tinsert(lines, "PRINT")
    tinsert(lines, "  Run /apitestprint")
    tinsert(lines, "  APIProbe calls print() with a recognisable sentence, then confirms separately through AddMessage.")
    tinsert(lines, "  If only the AddMessage confirmation appears, print did not target visible chat.")
    tinsert(lines, "  It may still be writing to an unavailable UE development log rather than being a no-op.")
    tinsert(lines, "")
    tinsert(lines, "SOUND")
    tinsert(lines, "  Run /apitestsound")
    tinsert(lines, "  Each use directly calls PlaySound() with a different standard sound name.")
    tinsert(lines, "  The chat message identifies the name used; hearing any one verifies the effect.")
    tinsert(lines, "")
    tinsert(lines, "The SavedVariables behaviour report records only what can be established programmatically.")
    APIProbeDB.manualReport = tconcat(lines, "\n")
end

local function ProbeAddonAPI()
    local lines = {}
    local addonCount
    local playerName
    tinsert(lines, "ADDON API RETURN-SHAPE PROBES")
    tinsert(lines, "")

    if type(GetNumAddOns) ~= "function" then
        tinsert(lines, "GetNumAddOns = MISSING")
        APIProbeDB.addonReport = tconcat(lines, "\n")
        return
    end

    local ok, count = pcall(GetNumAddOns)
    if not ok or type(count) ~= "number" then
        tinsert(lines, "GetNumAddOns() = ERROR | " .. OneLine(count))
        APIProbeDB.addonReport = tconcat(lines, "\n")
        return
    end
    addonCount = count
    tinsert(lines, "GetNumAddOns() = " .. tostring(addonCount))

    if type(UnitName) == "function" then
        local nameOk, nameValue = pcall(UnitName, "player")
        if nameOk then
            playerName = nameValue
        end
    end

    if type(GetAddOnInfo) == "function" then
        local selfIndex = nil
        local i
        for i = 1, addonCount do
            local infoOk, name = pcall(GetAddOnInfo, i)
            if infoOk and name == "APIProbe" then
                selfIndex = i
                break
            end
        end
        if not selfIndex then
            tinsert(lines, "APIProbe could not find itself by GetAddOnInfo name.")
        else
            tinsert(lines, "APIProbe index = " .. tostring(selfIndex))
            AddCall(lines, "GetAddOnInfo(APIProbe index)", function() return GetAddOnInfo(selfIndex) end)
            if type(GetAddOnEnableState) == "function" then
                AddCall(lines, "GetAddOnEnableState(nil, self index)", function() return GetAddOnEnableState(nil, selfIndex) end)
                if playerName then
                    AddCall(lines, "GetAddOnEnableState(player, self index)", function() return GetAddOnEnableState(playerName, selfIndex) end)
                end
            end
        end
    end

    if type(IsAddOnLoaded) == "function" then
        AddCall(lines, "IsAddOnLoaded('APIProbe')", function() return IsAddOnLoaded("APIProbe") end)
    end
    if type(GetAddOnMetadata) == "function" then
        AddCall(lines, "GetAddOnMetadata('APIProbe','Title')", function() return GetAddOnMetadata("APIProbe", "Title") end)
        AddCall(lines, "GetAddOnMetadata('APIProbe','Version')", function() return GetAddOnMetadata("APIProbe", "Version") end)
    end
    APIProbeDB.addonReport = tconcat(lines, "\n")
end

local function ObjectMethodSurvey(lines, objectLabel, object, methodSetNames)
    local present = 0
    local missing = 0
    local nameIndex, setIndex, setName, methodName, actual
    local problems = {}
    for setIndex = 1, getn(methodSetNames) do
        setName = methodSetNames[setIndex]
        local methods = objectMethodSets[setName]
        for nameIndex = 1, getn(methods) do
            methodName = methods[nameIndex]
            local lookupOK, methodValue = pcall(function() return object[methodName] end)
            if lookupOK then
                actual = type(methodValue)
            else
                actual = "lookup error: " .. OneLine(methodValue)
            end
            if lookupOK and actual == "function" then
                present = present + 1
            else
                missing = missing + 1
                tinsert(problems, "  MISSING " .. methodName .. " (got " .. actual .. ")")
            end
        end
    end
    tinsert(lines, objectLabel .. ": " .. present .. " methods present; " .. missing .. " absent from survey")
    for nameIndex = 1, getn(problems) do
        tinsert(lines, problems[nameIndex])
    end
end

local function ProbeNoArgMethod(lines, label, object, methodName)
    if not object then
        tinsert(lines, label .. " = MISSING")
        return
    end
    local lookupOK, methodValue = pcall(function() return object[methodName] end)
    if not lookupOK then
        tinsert(lines, label .. " = LOOKUP ERROR | " .. OneLine(methodValue))
        return
    end
    if type(methodValue) ~= "function" then
        tinsert(lines, label .. " = MISSING")
        return
    end
    AddCall(lines, label, function() return methodValue(object) end)
end

local function CreateProbeObject(lines, frameType, parent)
    if type(CreateFrame) ~= "function" then
        tinsert(lines, "CreateFrame('" .. frameType .. "') = MISSING CreateFrame")
        return nil
    end
    local ok, object = pcall(CreateFrame, frameType, nil, parent)
    if not ok then
        tinsert(lines, "CreateFrame('" .. frameType .. "') = ERROR | " .. OneLine(object))
        return nil
    end
    tinsert(lines, "CreateFrame('" .. frameType .. "') = OK | " .. OneLine(object))
    return object
end

local function ProbeObjects()
    local lines = {}
    tinsert(lines, "UI OBJECT AND METHOD PROBES")
    tinsert(lines, "Objects are private, hidden test objects owned by APIProbe.")
    tinsert(lines, "A missing surveyed method may be a version difference; call errors are stronger evidence.")
    tinsert(lines, "OK means a call was accepted; only setter/getter round trips verify a state change.")
    tinsert(lines, "")

    if type(CreateFrame) ~= "function" then
        tinsert(lines, "CreateFrame is missing; no UI object probes can run.")
        APIProbeDB.objectReport = tconcat(lines, "\n")
        return
    end

    local sandbox = AP.sandbox
    if not sandbox then
        local ok, value = pcall(CreateFrame, "Frame", "APIProbeSandbox", UIParent)
        if ok then
            sandbox = value
            AP.sandbox = sandbox
            if type(sandbox.Hide) == "function" then
                sandbox:Hide()
            end
        else
            tinsert(lines, "Sandbox frame creation failed: " .. OneLine(value))
            APIProbeDB.objectReport = tconcat(lines, "\n")
            return
        end
    end

    local frame = CreateProbeObject(lines, "Frame", sandbox)
    if frame then
        ObjectMethodSurvey(lines, "Frame", frame, {"Region", "Frame"})
        ProbeNoArgMethod(lines, "Frame:GetObjectType()", frame, "GetObjectType")
        ProbeNoArgMethod(lines, "Frame:GetBackdrop()", frame, "GetBackdrop")
        ProbeNoArgMethod(lines, "Frame:GetBackdropColor()", frame, "GetBackdropColor")
        ProbeNoArgMethod(lines, "Frame:GetBackdropBorderColor()", frame, "GetBackdropBorderColor")
        if type(frame.SetBackdrop) == "function" then
            AddCall(lines, "Frame:SetBackdrop(test backdrop)", function()
                return frame:SetBackdrop({
                    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 16,
                    insets = {left = 4, right = 4, top = 4, bottom = 4}
                })
            end)
            ProbeNoArgMethod(lines, "Frame:GetBackdrop() after SetBackdrop", frame, "GetBackdrop")
        end
        if type(frame.SetBackdropColor) == "function" then
            AddCall(lines, "Frame:SetBackdropColor(0.1,0.2,0.3,0.4)", function() return frame:SetBackdropColor(0.1, 0.2, 0.3, 0.4) end)
            ProbeNoArgMethod(lines, "Frame:GetBackdropColor() after setter", frame, "GetBackdropColor")
        end
        if type(frame.SetBackdropBorderColor) == "function" then
            AddCall(lines, "Frame:SetBackdropBorderColor(0.2,0.4,0.6,0.8)", function() return frame:SetBackdropBorderColor(0.2, 0.4, 0.6, 0.8) end)
            ProbeNoArgMethod(lines, "Frame:GetBackdropBorderColor() after setter", frame, "GetBackdropBorderColor")
        end
        if type(frame.SetAlpha) == "function" and type(frame.GetAlpha) == "function" then
            AddCall(lines, "Frame:SetAlpha(0.75)", function() return frame:SetAlpha(0.75) end)
            ProbeNoArgMethod(lines, "Frame:GetAlpha() after setter", frame, "GetAlpha")
        end
        if type(frame.SetWidth) == "function" and type(frame.GetWidth) == "function" then
            AddCall(lines, "Frame:SetWidth(123)", function() return frame:SetWidth(123) end)
            ProbeNoArgMethod(lines, "Frame:GetWidth() after setter", frame, "GetWidth")
        end
        if type(frame.SetHeight) == "function" and type(frame.GetHeight) == "function" then
            AddCall(lines, "Frame:SetHeight(45)", function() return frame:SetHeight(45) end)
            ProbeNoArgMethod(lines, "Frame:GetHeight() after setter", frame, "GetHeight")
        end
        if type(frame.Show) == "function" and type(frame.Hide) == "function" and type(frame.IsShown) == "function" then
            frame:Show()
            ProbeNoArgMethod(lines, "Frame:IsShown() after Show", frame, "IsShown")
            frame:Hide()
            ProbeNoArgMethod(lines, "Frame:IsShown() after Hide", frame, "IsShown")
        end
    end
    tinsert(lines, "")

    local button = CreateProbeObject(lines, "Button", sandbox)
    if button then
        ObjectMethodSurvey(lines, "Button", button, {"Region", "Frame", "Button"})
        if type(button.SetText) == "function" then
            AddCall(lines, "Button:SetText('APIProbe')", function() return button:SetText("APIProbe") end)
        end
        ProbeNoArgMethod(lines, "Button:GetText()", button, "GetText")
    end
    tinsert(lines, "")

    local check = CreateProbeObject(lines, "CheckButton", sandbox)
    if check then
        ObjectMethodSurvey(lines, "CheckButton", check, {"Region", "Frame", "Button", "CheckButton"})
        if type(check.SetChecked) == "function" then
            AddCall(lines, "CheckButton:SetChecked(1)", function() return check:SetChecked(1) end)
        end
        ProbeNoArgMethod(lines, "CheckButton:GetChecked() after setter", check, "GetChecked")
    end
    tinsert(lines, "")

    local edit = CreateProbeObject(lines, "EditBox", sandbox)
    if edit then
        ObjectMethodSurvey(lines, "EditBox", edit, {"Region", "Frame", "EditBox"})
        if type(edit.SetText) == "function" then
            AddCall(lines, "EditBox:SetText('APIProbe plain text')", function() return edit:SetText("APIProbe plain text") end)
        end
        ProbeNoArgMethod(lines, "EditBox:GetText()", edit, "GetText")
        ProbeNoArgMethod(lines, "EditBox:GetTextInsets()", edit, "GetTextInsets")
        ProbeNoArgMethod(lines, "EditBox:GetMaxLetters()", edit, "GetMaxLetters")
    end
    tinsert(lines, "")

    local scroll = CreateProbeObject(lines, "ScrollFrame", sandbox)
    if scroll then
        ObjectMethodSurvey(lines, "ScrollFrame", scroll, {"Region", "Frame", "ScrollFrame"})
        local child = CreateProbeObject(lines, "Frame", sandbox)
        if child and type(scroll.SetScrollChild) == "function" then
            AddCall(lines, "ScrollFrame:SetScrollChild(test child)", function() return scroll:SetScrollChild(child) end)
        end
        ProbeNoArgMethod(lines, "ScrollFrame:GetScrollChild()", scroll, "GetScrollChild")
        ProbeNoArgMethod(lines, "ScrollFrame:GetVerticalScrollRange()", scroll, "GetVerticalScrollRange")
    end
    tinsert(lines, "")

    local slider = CreateProbeObject(lines, "Slider", sandbox)
    if slider then
        ObjectMethodSurvey(lines, "Slider", slider, {"Region", "Frame", "Slider"})
        if type(slider.SetMinMaxValues) == "function" then
            AddCall(lines, "Slider:SetMinMaxValues(1,10)", function() return slider:SetMinMaxValues(1, 10) end)
        end
        if type(slider.SetValue) == "function" then
            AddCall(lines, "Slider:SetValue(4)", function() return slider:SetValue(4) end)
        end
        ProbeNoArgMethod(lines, "Slider:GetMinMaxValues()", slider, "GetMinMaxValues")
        ProbeNoArgMethod(lines, "Slider:GetValue()", slider, "GetValue")
    end
    tinsert(lines, "")

    local statusBar = CreateProbeObject(lines, "StatusBar", sandbox)
    if statusBar then
        ObjectMethodSurvey(lines, "StatusBar", statusBar, {"Region", "Frame", "StatusBar"})
        if type(statusBar.SetMinMaxValues) == "function" then
            AddCall(lines, "StatusBar:SetMinMaxValues(0,100)", function() return statusBar:SetMinMaxValues(0, 100) end)
        end
        if type(statusBar.SetValue) == "function" then
            AddCall(lines, "StatusBar:SetValue(33)", function() return statusBar:SetValue(33) end)
        end
        ProbeNoArgMethod(lines, "StatusBar:GetMinMaxValues()", statusBar, "GetMinMaxValues")
        ProbeNoArgMethod(lines, "StatusBar:GetValue()", statusBar, "GetValue")
        ProbeNoArgMethod(lines, "StatusBar:GetStatusBarColor()", statusBar, "GetStatusBarColor")
    end
    tinsert(lines, "")

    if frame and type(frame.CreateFontString) == "function" then
        local ok, fontString = pcall(frame.CreateFontString, frame, nil, "ARTWORK", "GameFontNormal")
        if ok then
            tinsert(lines, "Frame:CreateFontString() = OK | " .. OneLine(fontString))
            ObjectMethodSurvey(lines, "FontString", fontString, {"Region", "FontString"})
            if type(fontString.SetText) == "function" then
                AddCall(lines, "FontString:SetText('APIProbe')", function() return fontString:SetText("APIProbe") end)
            end
            ProbeNoArgMethod(lines, "FontString:GetText()", fontString, "GetText")
            ProbeNoArgMethod(lines, "FontString:GetStringWidth()", fontString, "GetStringWidth")
        else
            tinsert(lines, "Frame:CreateFontString() = ERROR | " .. OneLine(fontString))
        end
    end
    tinsert(lines, "")

    if frame and type(frame.CreateTexture) == "function" then
        local ok, texture = pcall(frame.CreateTexture, frame, nil, "ARTWORK")
        if ok then
            tinsert(lines, "Frame:CreateTexture() = OK | " .. OneLine(texture))
            ObjectMethodSurvey(lines, "Texture", texture, {"Region", "Texture"})
            if type(texture.SetTexture) == "function" then
                AddCall(lines, "Texture:SetTexture(1,0,0,1)", function() return texture:SetTexture(1, 0, 0, 1) end)
            end
            ProbeNoArgMethod(lines, "Texture:GetTexture()", texture, "GetTexture")
            ProbeNoArgMethod(lines, "Texture:GetTexCoord()", texture, "GetTexCoord")
            ProbeNoArgMethod(lines, "Texture:GetVertexColor()", texture, "GetVertexColor")
        else
            tinsert(lines, "Frame:CreateTexture() = ERROR | " .. OneLine(texture))
        end
    end

    APIProbeDB.objectReport = tconcat(lines, "\n")
end

local function BuildEventReport()
    EnsureDB()
    local lines = {}
    local names = {}
    local eventName, data, i
    tinsert(lines, "EVENT REGISTRATION AND ARGUMENT PROBES")
    tinsert(lines, "Capture enabled = " .. tostring(APIProbeDB.captureEvents))
    tinsert(lines, "Each event keeps only its first " .. tostring(MAX_EVENT_SAMPLES) .. " samples.")
    tinsert(lines, "old.* values are vanilla global event/argN values; param.* values are callback parameters.")
    tinsert(lines, "")
    tinsert(lines, "Registration results:")
    for i = 1, getn(watchedEvents) do
        eventName = watchedEvents[i]
        tinsert(lines, "  " .. eventName .. " = " .. tostring(APIProbeDB.eventRegistrations[eventName] or "not attempted"))
    end
    tinsert(lines, "")
    tinsert(lines, "Captured events:")
    for eventName, data in pairs(APIProbeDB.events) do
        tinsert(names, eventName)
    end
    tsort(names, SortCaseInsensitive)
    if getn(names) == 0 then
        tinsert(lines, "  (none yet)")
    end
    for i = 1, getn(names) do
        eventName = names[i]
        data = APIProbeDB.events[eventName]
        tinsert(lines, "")
        tinsert(lines, eventName .. " count=" .. tostring(data.count or 0))
        if type(data.samples) == "table" then
            local sampleIndex
            for sampleIndex = 1, getn(data.samples) do
                tinsert(lines, "  sample " .. tostring(sampleIndex) .. ": " .. data.samples[sampleIndex])
            end
        end
    end
    APIProbeDB.eventReport = tconcat(lines, "\n")
end

local function ValueForEvent(value)
    if value == nil then
        return "nil"
    end
    return OneLine(value)
end

local function CaptureEvent(p1, p2, p3, p4, p5, p6, p7, p8)
    EnsureDB()
    if not APIProbeDB.captureEvents then
        return
    end
    local oldEvent = event
    local eventName
    if type(oldEvent) == "string" then
        eventName = oldEvent
    elseif type(p2) == "string" then
        eventName = p2
    elseif type(p1) == "string" then
        eventName = p1
    else
        eventName = "<unknown event>"
    end
    local data = APIProbeDB.events[eventName]
    if type(data) ~= "table" then
        data = {count = 0, samples = {}}
        APIProbeDB.events[eventName] = data
    end
    data.count = (data.count or 0) + 1
    if type(data.samples) ~= "table" then
        data.samples = {}
    end
    if getn(data.samples) < MAX_EVENT_SAMPLES then
        local sample = "old.event=" .. ValueForEvent(oldEvent) ..
            " old.arg1=" .. ValueForEvent(arg1) ..
            " old.arg2=" .. ValueForEvent(arg2) ..
            " old.arg3=" .. ValueForEvent(arg3) ..
            " | param1=" .. ValueForEvent(p1) ..
            " param2=" .. ValueForEvent(p2) ..
            " param3=" .. ValueForEvent(p3) ..
            " param4=" .. ValueForEvent(p4) ..
            " param5=" .. ValueForEvent(p5) ..
            " param6=" .. ValueForEvent(p6) ..
            " param7=" .. ValueForEvent(p7) ..
            " param8=" .. ValueForEvent(p8)
        tinsert(data.samples, sample)
    end
end

local function ComposeSummary()
    local lines = {}
    local summary = APIProbeDB.expectedSummary or {}
    tinsert(lines, "AZEROTH API PROBE " .. VERSION)
    tinsert(lines, "Safe compatibility survey for the UE5 client")
    tinsert(lines, "")
    tinsert(lines, "Expected globals: " .. tostring(summary.present or 0) .. "/" .. tostring(summary.total or 0) ..
        " present; " .. tostring(summary.missing or 0) .. " missing; " .. tostring(summary.wrongType or 0) .. " wrong type")
    local counts = APIProbeDB.globalCounts or {}
    tinsert(lines, "Global inventory: " .. tostring(counts["function"] or 0) .. " functions, " ..
        tostring(counts["table"] or 0) .. " tables, " .. tostring(counts["userdata"] or 0) .. " userdata, " ..
        tostring(counts["string"] or 0) .. " strings, " .. tostring(counts["number"] or 0) .. " numbers")
    local origins = APIProbeDB.originCounts or {}
    tinsert(lines, "Function origins: " .. tostring(origins.native or 0) .. " native/C, " ..
        tostring(origins.lua or 0) .. " Lua, " .. tostring(origins.unknown or 0) .. " unknown")
    local behavior = APIProbeDB.behaviorStats or {}
    tinsert(lines, "Behaviour tests: " .. tostring(behavior.verified or 0) .. " verified, " ..
        tostring(behavior.failed or 0) .. " failed, " .. tostring(behavior.error or 0) .. " errored, " ..
        tostring(behavior.unavailable or 0) .. " unavailable, " .. tostring(behavior.unverified or 0) ..
        " call-only, " .. tostring(behavior.manual or 0) .. " manual")
    tinsert(lines, "")
    tinsert(lines, APIProbeDB.luaClientReport or "Lua/client probes have not run.")
    tinsert(lines, "")
    tinsert(lines, APIProbeDB.addonReport or "Addon probes have not run.")
    tinsert(lines, "")
    tinsert(lines, "Use the buttons or independent /api... commands for Behaviour, Native, Libraries, Objects and Events.")
    tinsert(lines, "Complete copyable output remains in APIProbe.lua SavedVariables because this client lacks EditBox selection methods.")
    APIProbeDB.summaryReport = tconcat(lines, "\n")
end

function AP.RunAll(quiet)
    EnsureDB()
    ScanGlobals()
    ProbeExpectedGlobals()
    ProbeLuaAndClient()
    ProbeLibrarySurface()
    ProbeBehavior()
    ProbeAddonAPI()
    ProbeObjects()
    BuildManualReport()
    BuildEventReport()
    ComposeSummary()
    APIProbeDB.runCount = (APIProbeDB.runCount or 0) + 1
    if type(date) == "function" then
        local ok, timestamp = pcall(date, "%Y-%m-%d %H:%M:%S")
        if ok then
            APIProbeDB.lastRun = timestamp
        end
    elseif type(GetTime) == "function" then
        local ok, elapsed = pcall(GetTime)
        if ok then
            APIProbeDB.lastRun = "GetTime=" .. tostring(elapsed)
        end
    end
    if not quiet then
        Chat("safe probe complete: " .. tostring(APIProbeDB.expectedSummary.present or 0) .. "/" ..
            tostring(APIProbeDB.expectedSummary.total or 0) .. " expected globals present")
    end
end

local function AppendWrappedReportLine(lines, sourceLine)
    local remaining = sourceLine or ""
    if remaining == "" then
        tinsert(lines, "")
        return
    end
    while string.len(remaining) > REPORT_WRAP_COLUMNS do
        local cut = REPORT_WRAP_COLUMNS
        local minimum = math.floor(REPORT_WRAP_COLUMNS * 0.65)
        local position
        for position = REPORT_WRAP_COLUMNS, minimum, -1 do
            local character = string.sub(remaining, position, position)
            if character == " " or character == "\t" then
                cut = position
                break
            end
        end
        tinsert(lines, string.sub(remaining, 1, cut))
        remaining = string.sub(remaining, cut + 1)
        while string.sub(remaining, 1, 1) == " " do
            remaining = string.sub(remaining, 2)
        end
    end
    tinsert(lines, remaining)
end

local function BuildReportLines(text)
    local lines = {}
    local line
    local eachLine = string.gmatch or string.gfind
    for line in eachLine((text or "") .. "\n", "(.-)\n") do
        AppendWrappedReportLine(lines, line)
    end
    if getn(lines) == 0 then
        tinsert(lines, "")
    end
    return lines
end

local function RefreshReportRows()
    if not AP.scroll or not AP.reportRows then return end
    local lines = AP.reportLines or {}
    local offset = FauxScrollFrame_GetOffset(AP.scroll)
    FauxScrollFrame_Update(AP.scroll, getn(lines), REPORT_VISIBLE_ROWS, REPORT_LINE_HEIGHT)
    local rowIndex
    for rowIndex = 1, REPORT_VISIBLE_ROWS do
        local row = AP.reportRows[rowIndex]
        local text = lines[offset + rowIndex]
        if text ~= nil then
            row:SetText(text)
            row:Show()
        else
            row:SetText("")
            row:Hide()
        end
    end
end

AP.RefreshReportRows = RefreshReportRows

local function ResetReportScroll()
    if not AP.scroll then return end
    FauxScrollFrame_SetOffset(AP.scroll, 0)
    local scrollbar = AP.scrollbar or getglobal(AP.scroll:GetName() .. "ScrollBar")
    AP.scrollbar = scrollbar
    if scrollbar and type(scrollbar.SetValue) == "function" then
        scrollbar:SetValue(0)
    end
    RefreshReportRows()
end

local function CreateButton(parent, text, width, point, relative, relativePoint, x, y, handler)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(22)
    button:SetPoint(point, relative, relativePoint, x, y)
    button:SetText(text)
    button:SetScript("OnClick", handler)
    return button
end

local function EnsureWindow()
    if AP.window then
        return AP.window
    end
    local frame = CreateFrame("Frame", "APIProbeFrame", UIParent)
    AP.window = frame
    frame:SetWidth(790)
    frame:SetHeight(590)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    if type(frame.SetBackdrop) == "function" then
        pcall(function()
            frame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = {left = 11, right = 12, top = 12, bottom = 11}
            })
        end)
    end

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -15)
    title:SetText("Azeroth API Probe " .. VERSION)
    AP.title = title

    local viewLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    viewLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -18)
    viewLabel:SetText("Summary")
    AP.viewLabel = viewLabel

    -- MCP's working addon list proves that this client's FauxScrollFrame
    -- implementation functions correctly. Use its fixed-row model rather than
    -- an ordinary ScrollFrame with one tall EditBox, which the client does not
    -- actually move even when its reported scroll range looks valid.
    local scroll = CreateFrame("ScrollFrame", "APIProbeReportScrollFrame", frame, "FauxScrollFrameTemplate")
    scroll:SetWidth(744)
    scroll:SetHeight(REPORT_VISIBLE_ROWS * REPORT_LINE_HEIGHT)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -49)
    AP.scroll = scroll

    AP.reportRows = {}
    local rowIndex
    for rowIndex = 1, REPORT_VISIBLE_ROWS do
        local row = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        row:SetWidth(700)
        row:SetHeight(REPORT_LINE_HEIGHT)
        row:SetJustifyH("LEFT")
        row:SetJustifyV("MIDDLE")
        if rowIndex == 1 then
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -49)
        else
            row:SetPoint("TOPLEFT", AP.reportRows[rowIndex - 1], "BOTTOMLEFT", 0, 0)
        end
        row:SetText("")
        AP.reportRows[rowIndex] = row
    end

    scroll:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(REPORT_LINE_HEIGHT, RefreshReportRows)
    end)

    if type(scroll.EnableMouseWheel) == "function" then
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function()
            local value = arg1 or 0
            local scrollbar = AP.scrollbar or getglobal(scroll:GetName() .. "ScrollBar")
            AP.scrollbar = scrollbar
            if scrollbar and type(scrollbar.GetValue) == "function" and type(scrollbar.SetValue) == "function" then
                local distance = REPORT_LINE_HEIGHT * REPORT_MOUSEWHEEL_LINES
                if value > 0 then
                    scrollbar:SetValue(scrollbar:GetValue() - distance)
                elseif value < 0 then
                    scrollbar:SetValue(scrollbar:GetValue() + distance)
                end
            end
        end)
    end

    local summaryButton = CreateButton(frame, "Summary", 72, "BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 46,
        function() AP.ShowReport("summary") end)
    local behaviorButton = CreateButton(frame, "Behaviour", 78, "LEFT", summaryButton, "RIGHT", 4, 0,
        function() AP.ShowReport("behavior") end)
    local nativeButton = CreateButton(frame, "Native", 72, "LEFT", behaviorButton, "RIGHT", 4, 0,
        function() AP.ShowReport("native") end)
    local librariesButton = CreateButton(frame, "Libraries", 76, "LEFT", nativeButton, "RIGHT", 4, 0,
        function() AP.ShowReport("libraries") end)
    local objectsButton = CreateButton(frame, "Objects", 72, "LEFT", librariesButton, "RIGHT", 4, 0,
        function() AP.ShowReport("objects") end)
    local missingButton = CreateButton(frame, "Missing", 72, "LEFT", objectsButton, "RIGHT", 4, 0,
        function() AP.ShowReport("missing") end)
    local eventsButton = CreateButton(frame, "Events", 72, "LEFT", missingButton, "RIGHT", 4, 0,
        function() BuildEventReport(); AP.ShowReport("events") end)
    CreateButton(frame, "Manual", 72, "LEFT", eventsButton, "RIGHT", 4, 0,
        function() AP.ShowReport("manual") end)

    local globalsButton = CreateButton(frame, "Globals", 72, "BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 20,
        function() AP.ShowReport("globals") end)
    local runButton = CreateButton(frame, "Run Again", 82, "LEFT", globalsButton, "RIGHT", 4, 0,
        function()
            AP.RunAll(false)
            AP.ShowReport("summary")
        end)
    local savedButton = CreateButton(frame, "Saved File", 82, "LEFT", runButton, "RIGHT", 4, 0,
        function() Chat("complete reports are in WTF\\Account\\<account>\\SavedVariables\\APIProbe.lua after logout/reload") end)
    CreateButton(frame, "Close", 64, "LEFT", savedButton, "RIGHT", 4, 0, function() frame:Hide() end)

    frame:Hide()
    return frame
end

local viewNames = {
    summary = "Summary",
    behavior = "Observable behaviour",
    native = "Native/C functions",
    libraries = "Lua libraries",
    missing = "Missing / wrong type globals",
    objects = "UI object methods",
    globals = "Global functions",
    events = "Events",
    manual = "Manual observation"
}

local function ReportForView(view)
    if view == "missing" then
        return APIProbeDB.missingReport or "No missing-global report yet."
    elseif view == "behavior" then
        return APIProbeDB.behaviorReport or "No behaviour report yet."
    elseif view == "native" then
        local counts = APIProbeDB.originCounts or {}
        return "NATIVE/C GLOBAL FUNCTIONS\n" ..
            "debug.getinfo classified " .. tostring(counts.native or 0) .. " functions as native/C.\n" ..
            "Native origin proves a binding exists, not that its implementation has an observable effect.\n\n" ..
            (APIProbeDB.nativeFunctionInventory or "No native-function scan yet.")
    elseif view == "libraries" then
        return APIProbeDB.libraryReport or "No library report yet."
    elseif view == "objects" then
        return APIProbeDB.objectReport or "No object report yet."
    elseif view == "globals" then
        return "GLOBAL FUNCTIONS EXPOSED BY THE CLIENT\n" ..
            "One name per line. APIProbeDB.globalTypes contains every global and its type.\n\n" ..
            (APIProbeDB.functionInventory or "No global scan yet.")
    elseif view == "events" then
        return APIProbeDB.eventReport or "No event report yet."
    elseif view == "manual" then
        return APIProbeDB.manualReport or "No manual-test report yet."
    end
    return APIProbeDB.summaryReport or "No summary report yet."
end

function AP.ShowReport(view)
    EnsureDB()
    if not APIProbeDB.summaryReport then
        AP.RunAll(true)
    end
    if view == "events" then
        BuildEventReport()
    end
    local frame = EnsureWindow()
    local text = ReportForView(view)
    if string.len(text) > MAX_DISPLAY then
        text = string.sub(text, 1, MAX_DISPLAY - 120) ..
            "\n\n[Display truncated. The complete data remains in APIProbeDB SavedVariables.]"
    end
    AP.viewLabel:SetText(viewNames[view] or viewNames.summary)
    AP.reportLines = BuildReportLines(text)
    frame:Show()
    ResetReportScroll()
end

local function Help()
    Chat("/apiprobe [run|show|behavior|native|libraries|missing|objects|globals|events|manual|help]")
    Chat("/apiprobe events on|off|clear")
    Chat("independent commands: /apirun /apishow /apibehavior /apinative /apilibraries /apiobjects /apimissing /apiglobals /apievents /apimanual")
end

function AP.Slash(messageText)
    EnsureDB()
    local msg = string.lower(Trim(messageText))
    if msg == "" or msg == "show" or msg == "summary" then
        AP.ShowReport("summary")
    elseif msg == "run" then
        AP.RunAll(false)
        AP.ShowReport("summary")
    elseif msg == "behavior" or msg == "behaviour" then
        AP.ShowReport("behavior")
    elseif msg == "native" then
        AP.ShowReport("native")
    elseif msg == "libraries" or msg == "library" or msg == "lua" then
        AP.ShowReport("libraries")
    elseif msg == "missing" then
        AP.ShowReport("missing")
    elseif msg == "objects" or msg == "object" then
        AP.ShowReport("objects")
    elseif msg == "globals" or msg == "global" or msg == "functions" then
        AP.ShowReport("globals")
    elseif msg == "events" or msg == "events show" then
        BuildEventReport()
        AP.ShowReport("events")
    elseif msg == "events on" then
        APIProbeDB.captureEvents = true
        Chat("event capture enabled")
    elseif msg == "events off" then
        APIProbeDB.captureEvents = false
        Chat("event capture disabled")
    elseif msg == "events clear" then
        APIProbeDB.events = {}
        BuildEventReport()
        Chat("captured event samples cleared")
    elseif msg == "manual" then
        AP.ShowReport("manual")
    else
        Help()
    end
end

function AP.TestPrint()
    if type(print) ~= "function" then
        Chat("print is missing")
        return
    end
    local ok, errorText = pcall(function()
        print("APIProbe PRINT TEST: this line came from print()")
    end)
    if ok then
        Chat("print() returned without an error. Did a separate 'APIProbe PRINT TEST' line appear?")
    else
        Chat("print() raised: " .. OneLine(errorText))
    end
end

function AP.TestSound()
    if type(PlaySound) ~= "function" then
        Chat("PlaySound is missing")
        return
    end
    local soundTests = {
        {"TellMessage", "whisper notification"},
        {"igMainMenuOpen", "main-menu opening"},
        {"igQuestListOpen", "quest-list opening"},
        {"QUESTADDED", "quest added"},
        {"LOOTWINDOWCOINSOUND", "loot coins"},
        {"igMainMenuOptionCheckBoxOn", "checkbox"}
    }
    AP.soundTestIndex = (AP.soundTestIndex or 0) + 1
    if AP.soundTestIndex > getn(soundTests) then
        AP.soundTestIndex = 1
    end
    local soundName = soundTests[AP.soundTestIndex][1]
    local description = soundTests[AP.soundTestIndex][2]
    -- Call the binding directly inside the protected Lua closure. Passing the
    -- native binding itself as pcall's first argument may be another client bug.
    local ok, errorText = pcall(function() PlaySound(soundName) end)
    if ok then
        Chat("PlaySound('" .. soundName .. "') returned; listen for " .. description ..
            ". Run /apitestsound again for the next name.")
    else
        Chat("PlaySound('" .. soundName .. "') raised: " .. OneLine(errorText))
    end
end

EnsureDB()

SLASH_APIPROBE1 = "/apiprobe"
SLASH_APIPROBE2 = "/apip"
SlashCmdList["APIPROBE"] = AP.Slash

SLASH_APIRUN1 = "/apirun"
SlashCmdList["APIRUN"] = function() AP.RunAll(false); AP.ShowReport("summary") end
SLASH_APISHOW1 = "/apishow"
SlashCmdList["APISHOW"] = function() AP.ShowReport("summary") end
SLASH_APIBEHAVIOR1 = "/apibehavior"
SlashCmdList["APIBEHAVIOR"] = function() AP.ShowReport("behavior") end
SLASH_APINATIVE1 = "/apinative"
SlashCmdList["APINATIVE"] = function() AP.ShowReport("native") end
SLASH_APILIBRARIES1 = "/apilibraries"
SlashCmdList["APILIBRARIES"] = function() AP.ShowReport("libraries") end
SLASH_APIOBJECTS1 = "/apiobjects"
SlashCmdList["APIOBJECTS"] = function() AP.ShowReport("objects") end
SLASH_APIMISSING1 = "/apimissing"
SlashCmdList["APIMISSING"] = function() AP.ShowReport("missing") end
SLASH_APIGLOBALS1 = "/apiglobals"
SlashCmdList["APIGLOBALS"] = function() AP.ShowReport("globals") end
SLASH_APIEVENTS1 = "/apievents"
SlashCmdList["APIEVENTS"] = function() BuildEventReport(); AP.ShowReport("events") end
SLASH_APIMANUAL1 = "/apimanual"
SlashCmdList["APIMANUAL"] = function() AP.ShowReport("manual") end
SLASH_APITESTPRINT1 = "/apitestprint"
SlashCmdList["APITESTPRINT"] = AP.TestPrint
SLASH_APITESTSOUND1 = "/apitestsound"
SlashCmdList["APITESTSOUND"] = AP.TestSound

local eventFrame = CreateFrame("Frame", "APIProbeEventFrame", UIParent)
AP.eventFrame = eventFrame

local eventIndex
for eventIndex = 1, getn(watchedEvents) do
    local eventName = watchedEvents[eventIndex]
    local ok, errorText = pcall(eventFrame.RegisterEvent, eventFrame, eventName)
    if ok then
        APIProbeDB.eventRegistrations[eventName] = "registered"
    else
        APIProbeDB.eventRegistrations[eventName] = "ERROR " .. OneLine(errorText)
    end
end

eventFrame:SetScript("OnEvent", function(p1, p2, p3, p4, p5, p6, p7, p8)
    local eventName = event
    if type(eventName) ~= "string" and type(p2) == "string" then
        eventName = p2
    end
    if type(eventName) ~= "string" and type(p1) == "string" then
        eventName = p1
    end
    CaptureEvent(p1, p2, p3, p4, p5, p6, p7, p8)
    if eventName == "PLAYER_LOGIN" and not AP.ranAtLogin then
        AP.ranAtLogin = true
        AP.RunAll(true)
        Chat("loaded. Type /apiprobe to view the compatibility report.")
    elseif eventName == "VARIABLES_LOADED" then
        EnsureDB()
    end
end)

-- Also make a report immediately. This covers clients that omit PLAYER_LOGIN,
-- or load/reload this addon after the event has already fired.
AP.RunAll(true)
