local tooltipInfo = {}
local customframes;
local linkURL, hash
local frame = CreateFrame("Frame")
local gotoLink = ""

local GetSpellInfo = _G.GetSpellInfo
local GetSpellLink = _G.GetSpellLink
local GetSpellName = _G.GetSpellName
local GetSpellTabInfo = _G.GetSpellTabInfo

local function GetQuestID(index)
  if not index then return end
  if GetQuestLink(index) then
    return tonumber(string.match(GetQuestLink(index), '|Hquest:(%d+):'))
  end
end

local function GetQuestLogIndexByQuestName(name)
	local numEntries = GetNumQuestLogEntries();
	local questLogTitleText;
	for i=1, numEntries, 1 do
		questLogTitleText = GetQuestLogTitle(i);
		if string.find(questLogTitleText, name) or string.find(name, questLogTitleText) then
			return i;
		end
	end
	return nil;
end

local function GetUnitID(unit)
  local id = UnitGUID(unit)  
  if id then
    return (string.sub(id, 5, 5) == "3") and tonumber(string.sub(id, 6, 12), 16) or nil
  end  
  return nil
end

local validfounds = {
    npc = "",
    spell = "",
    quest = "",
    item = GetItemInfo
}

local function clearTooltipInfo(tooltip)
    wipe(tooltipInfo[tooltip])
end

local function setTooltipHyperkink(tooltip, hyperlink)
    local ttable = tooltipInfo[tooltip];
    ttable.name = _G[tooltip:GetName().."TextLeft1"]:GetText();
    ttable.hl = hyperlink;
end

local function GetSpellIDByNameAndRank(name, rank)
	if not name then return end
	local spellLink = GetSpellLink(name, rank)
	if spellLink then
		return tonumber(spellLink:match("spell:(%d+)"))
	end
	return nil
end

local function GetDirtySpellID(name, rank)
  -- VERY VERY dirty methode to find Buff/Debuff SpellID if not found by spellLink
  for i=1, 50000 do
    local sn, sr = GetSpellInfo(i);
    if name == sn and rank == sr then
      return i;
    end
  end
  return nil;
end

local function setTooltipUnitAura(tooltip, unit, index, filter)
  local ttable = tooltipInfo[tooltip];
  local name, rank, id
  if ( filter == "HELPFUL" ) then
    name, rank = UnitBuff(unit, index, filter)
  else
    name, rank = UnitDebuff(unit, index, filter)
  end
  
  if name then
    id = GetSpellIDByNameAndRank(name, rank)
    if not id then
      if not FUBA_LINKGRABBER_UPDATETOOLTIP then return end
      id = GetDirtySpellID(name, rank)
    end
  end
  
  ttable.aura = id
  ttable.name = name
end

local function hookTooltip(tooltip)
    tooltipInfo[tooltip] = {}
    hooksecurefunc(tooltip, "SetHyperlink", setTooltipHyperkink)
    hooksecurefunc(tooltip, "SetUnitBuff", setTooltipUnitAura)
    hooksecurefunc(tooltip, "SetUnitDebuff", setTooltipUnitAura)
    --hooksecurefunc(tooltip, "SetPlayerBuff", setTooltipPlayerBuff)
    tooltip:HookScript("OnTooltipCleared", clearTooltipInfo)
end

local function onEvent(frame, event)
    if event == "PLAYER_ENTERING_WORLD" then
        hookTooltip(GameTooltip)
        hookTooltip(ItemRefTooltip)
    end
end

local function onUpdate()
    StaticPopup_Show("FUBA_LINKGRABBER")
    frame:Hide();
end

local function found(ftype, id, name)
    local foundAccept = validfounds[ftype];
    if foundAccept then
        name = name or foundAccept;
        if type(name) == 'function' then
            name = name(id);
        end
        name = name or ftype;
				local strType;
				strType = strType or ftype;
        --print("Found "..type.." "..id)
        -- Show frame to recieve OnUpdate next frame
        -- So pressed hotkey doesnt erase text field
        gotoLink = linkURL .. ftype .. "=" .. id .. hash;
        --StaticPopupDialogs["FUBA_LINKGRABBER"].text = firstToUpper(ftype) .. ": " .. name .. "\n|cff808080id="..id.."\n|cff00ff00CTRL+C to copy!";
        StaticPopupDialogs["FUBA_LINKGRABBER"].text = "|cffffff00"..firstToUpper(strType) .. ":\n|r" .. name .. "\n|cff00ff00CTRL+C to copy!|r";
        frame:Show();
        return true;
    end
end

local function foundplayer(name)
    return true;
end

local function getUnitInfo(unit, name)
    if UnitIsPlayer(unit) then
        return foundplayer(name)
    else
        id = GetUnitID(unit)
        if id then return found("npc",id,name) end
    end
end

local function getFocusInfo()
    local focus = GetMouseFocus()
    local current = focus;
    local focusname;
    --__LASTFRAME = focus;
    while current and not focusname do
        focusname = current:GetName()
        current = current:GetParent()
    end
    if not focusname then return end
    local focuslen = string.len(focusname);
    
    --print(focusname)
    
    for name,func in pairs(customframes) do
        local customlen = string.len(name)
        if customlen <= focuslen and name == string.sub(focusname,1,customlen) then
            if func(focus, focusname) then return true end
        end
    end
end

local function parseLink(link, text)
  local linkstart = string.find(link,"|H")
  local _,lastfound,type,id = string.find(link,"(%a+):(%d+):",linkstart and linkstart + 2)
  local _,_,name = string.find(link,"%[([^%[%]]*)%]",lastfound)
  
  name = name or text
  return found(type,id,name)
end

local function parseTooltip(tooltip)
    local name, link = tooltip:GetItem()
    if name then return parseLink(link) end

    local name, rank = tooltip:GetSpell();
    if name then
      local spellLink = GetSpellLink(name, rank)
        if spellLink then
          id = tonumber(spellLink:match("spell:(%d+)"));
          return found("spell",id,name);
        end
    end
    
    local name, unit = tooltip:GetUnit()
    if unit then return getUnitInfo(unit, name) end
       
    local ttdata = tooltipInfo[tooltip];    
    if ttdata.hl then return parseLink(ttdata.hl, ttdata.name) end
    if ttdata.aura then return found("spell",ttdata.aura,ttdata.name) end
end

local function linkGrabberRunInternal()
    return parseTooltip(ItemRefTooltip)
            or parseTooltip(GameTooltip)
            or getFocusInfo()
end


linkGrabberRun = function()
    linkGrabberRunInternal()
    --pcall(linkGrabberRunInternal);
end

-- Formatting

function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

-- Custom frames mouseover

local function QuestLogTitleFunc(widget)
	if not widget then return end
	local questName = widget:GetText()
	if questName then
		local QLIndex = GetQuestLogIndexByQuestName(questName)
		if QLIndex then
			local name = GetQuestLogTitle(QLIndex)
			local id = GetQuestID(QLIndex)
			if name and id then
				found("quest", id, name);
			end
		end
	end
end

local function GetBuff(widget)
	if not widget then return end
  local i = tonumber(widget:GetName():match("BuffButton(%d+)"))
  if i ~= 0 then
    local name, rank = UnitBuff("player", i)
    if name then
      id = GetSpellIDByNameAndRank(name, rank) or GetDirtySpellID(name, rank) or nil;
      found("spell", id, name);
    end
  end
end

local function GetDebuff(widget)
	if not widget then return end
  local i = tonumber(widget:GetName():match("DebuffButton(%d+)"))
  if i ~= 0 then
    local name, rank = UnitDebuff("player", i)
    if name then
      id = GetSpellIDByNameAndRank(name, rank) or GetDirtySpellID(name, rank) or nil;
      found("spell", id, name);
    end
  end
end

local function GetQuestItem(widget)
	if not widget then return end
  if widget.type and widget:GetID() then   
    parseLink(GetQuestItemLink(widget.type, widget:GetID()))
  end
end

local function GetQuestHelperQuest(widget)
	if not widget then return end
	local questName = widget.quest
	if questName then
		local QLIndex = GetQuestLogIndexByQuestName(questName)
		if QLIndex then
			local name = GetQuestLogTitle(QLIndex)
			local id = GetQuestID(QLIndex)
			if name and id then
				found("quest", id, name);
			end
		end
	end
	
end

customframes = {
    ["QuestLogTitle"] = QuestLogTitleFunc, 											-- Get Quest directly from QuestLog (Mouseover Quest)
    ["BuffButton"] = GetBuff,																		-- Get Buff
    ["DebuffButton"] = GetDebuff,																-- Get Debuff
    ["QuestProgressItem"] = GetQuestItem,												-- Get Quest Item from NPC
    ["QuestHelperQuestWatchFrame"] = GetQuestHelperQuest,				-- Get Quest from QuestHelper Watchframe
}

frame:Hide()
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", onEvent)
frame:SetScript("OnUpdate", onUpdate)

local locale = string.sub(GetLocale(),1,2)
if locale == "de" then
	linkURL = "https://tbcdb.rising-gods.de/?"
	hash = ""
else
	linkURL = "https://tbc-twinhead.twinstar.cz/?"
	hash = ""
end

FUBA_LINKGRABBER_UPDATETOOLTIP = false

local function bumpFrameLevels(frame, amount)
  frame:SetFrameLevel(frame:GetFrameLevel()+amount)
  for _,v in ipairs(frame:GetChildren()) do
    bumpFrameLevels(v, amount)
  end
end

StaticPopupDialogs["FUBA_LINKGRABBER"] = {
		text = "",
		button2 = OKAY,
		hasEditBox = 1,
		hasWideEditBox = 1,
		showAlert = 1, -- HACK : it's the only way I found to make de StaticPopup have sufficient width to show WideEditBox :(

		OnShow = function()
			local editBox = _G[this:GetName() .. "WideEditBox"]
      editBox:SetText(gotoLink)
			editBox:SetFocus()
			editBox:HighlightText(0)
			editBox:SetScript("OnTextChanged", function() StaticPopup_EditBoxOnTextChanged() end)

			local button = _G[this:GetName() .. "Button2"]
			button:ClearAllPoints()
			button:SetWidth(200)
			button:SetPoint("CENTER", editBox, "CENTER", 0, -30)

			_G[this:GetName() .. "AlertIcon"]:Hide()  -- HACK : we hide the false AlertIcon
			this:SetFrameStrata("FULLSCREEN_DIALOG")
			bumpFrameLevels(this, 30)
		end,
		OnHide = function()
			local editBox = _G[this:GetName() .. "WideEditBox"]
			editBox:SetScript("OnTextChanged", nil)
			this:SetFrameStrata("DIALOG")
			bumpFrameLevels(this, -30)
		end,
		OnAccept = function() end,
		OnCancel = function() end,
		EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
		EditBoxOnTextChanged = function()
			this:SetText(gotoLink)
			this:SetFocus()
			this:HighlightText(0)
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1
	}