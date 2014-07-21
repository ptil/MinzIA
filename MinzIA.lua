-----------------------------------------------------------------------------------------------
-- Client Lua Script for MinzIA
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- MinzIA Module Definition
-----------------------------------------------------------------------------------------------
local MinzIA = {} 
local ChatSystemLib = ChatSystemLib 
local GroupLib = GroupLib
local GameLib = GameLib

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
local mathfloor, mathpow, mathabs = math.floor, math.pow, math.abs
local tremove, tinsert = table.remove, table.insert
local strformat = string.format
local osclock = os.clock
function MinzIA:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end



function MinzIA:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
	self:PrepareTable()
end
 
function MinzIA:PrepareTable()
	self.activeCooldowns = {}
	self.recentlyEndedCooldowns = {}
	self.cooldownListeners = {}
	self.skillused = {}
	self.skillIA = {}
	self.time = nil
	self.totalIA = 0
	self.currentIA = 0
	self.party = {}
	self.retry = 0
end

-----------------------------------------------------------------------------------------------
-- MinzIA OnLoad
-----------------------------------------------------------------------------------------------
function MinzIA:OnLoad()
	self.prefixNo = "CRB_CritNumberFloaters:sprCritNumber_Physical"
	self.prefixClass = "IconSprites:Icon_Windows_UI_CRB_"

	
	--Print("Test");
	self.xmlDoc = XmlDoc.CreateFromFile("MinzIA.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
    if (GameLib.GetPlayerUnit()) then
		self:OnCharacterCreated()
	else
		Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
	end
	Apollo.RegisterSlashCommand("mia", "OnMinzIAOn", self)
	---self:Output("OnLoad() done")
	
end

-----------------------------------------------------------------------------------------------
-- MinzIA OnDocLoaded
-----------------------------------------------------------------------------------------------
function MinzIA:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "Form", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		self.wndMain:Show(true, true)
		self:ClearForm()
		self:UpdateFormClass()
	    

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)322
		


		-- Do additional Addon initialization here
	end
end

function MinzIA:OnMinzIAOn()
	if self.wndMain:IsShown() then
		self:OnGroupLeft()
	else 
		self:OnGroupJoin()
	end
end

function MinzIA:ClearForm()
	self.wndMain:FindChild("Member1"):Show(false,true)
	self.wndMain:FindChild("Member2"):Show(false,true)
	self.wndMain:FindChild("Member3"):Show(false,true)
	self.wndMain:FindChild("Member4"):Show(false,true)
	self.wndMain:FindChild("Member5"):Show(false,true)
end


function MinzIA:UpdateFormClass()
	--self:Output("UpdateFormClass begin inGroup?"..tostring(GroupLib.InGroup()).." inRaid?"..tostring(GroupLib.InRaid()))
	self.party = {}
	if not GroupLib.InGroup() and not GroupLib.InRaid() then 
		if self.timerUpdateFormClass ~= nil then 
			self.timerUpdateFormClass:Stop()
		end
		self.wndMain:Show(false, true)
		return 
	end
	self.wndMain:Show(true, true)
	local player = {}
	local members = GroupLib.GetMemberCount()
	--self:Output(members.." players found")
	for i=1, members do
		local member = GroupLib.GetGroupMember(i)
		--for k,v in pairs(member) do
		--	self:Output(k.." "..tostring(v))
		--end
		--self:Output(member["Name"])
		if(member ~= nil) then
			player = {}
			player["Name"] = member["strCharacterName"]
			player["Class"] = member["strClassName"]
			player["IA"] = 0
			--self:Output(player["Class"])
			self.party[#self.party+1] = player
		else 
			--self:Output("Player "..i.." is null")
		end
	end
	for k,v in pairs(self.party) do
		self.wndMain:FindChild("Member"..k):SetSprite(self.prefixClass..v["Class"])
		self.wndMain:FindChild("Member"..k):Show(true, true)
		self.wndMain:FindChild("Member"..k):FindChild("CD"):SetSprite(self.prefixNo.."9")
		--self:Output(v["Name"]..":"..v["Class"].." loaded ")
	end
	--self:Output(tostring(GroupLib.InGroup()).." "..#self.party)
	if self.timerUpdateFormClass ~= nil and GroupLib.InGroup() and #self.party > 0 then
		--self:Output("UpdateFormClass stop")
		self.timerUpdateFormClass:Stop()
	end
end

function MinzIA:UpdateForm()
	if GroupLib.InGroup and not GroupLib.InRaid() then
		for k,v in pairs(self.party) do
			self.wndMain:FindChild("Member"..k):FindChild("CD"):SetSprite(self.prefixNo..v["IA"])
		end
	end
end


-----------------------------------------------------------------------------------------------
-- MinzIA Instance
-----------------------------------------------------------------------------------------------
local MinzIAInst = MinzIA:new()
MinzIAInst:Init()



function MinzIA:OnCharacterCreated()
	if (not self.variablesLoaded) then
		self.timerGetPlayerUnit = ApolloTimer.Create(0.5, false, "OnCharacterCreated", self)
		self.variablesLoaded = true
		return
	elseif (self.timerGetPlayerUnit ~= nil) then
		self.timerGetPlayerUnit:Stop()
	end

	self.timerUpdateTracker = ApolloTimer.Create(0.5, true, "UpdateTrackedItems", self)
	self.timerUpdateLas = ApolloTimer.Create(1, true, "GetLasAbilities", self)
	self.timerUpdateFormClass = ApolloTimer.Create(1, true, "UpdateFormClass", self)
	self.timerUpdateForm = ApolloTimer.Create(0.3, true, "UpdateForm", self)
	self.timerUpdateLocalIA = ApolloTimer.Create(0.3, true, "UpdateLocalIA", self)

	
	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnUnitEnteredCombat", self)
	Apollo.RegisterEventHandler("AbilityBookChange", "ScheduleLasUpdate", self)
	Apollo.RegisterEventHandler("Group_Left", "OnGroupLeft", self)
	Apollo.RegisterEventHandler("Group_Join", "OnGroupJoin", self)
	Apollo.RegisterEventHandler("Group_Remove", "OnGroupUpdate", self)
	Apollo.RegisterEventHandler("Group_Add", "OnGroupUpdate", self)


	
	self.comm = ICCommLib.JoinChannel("MinzIAChannel", "OnMinzIAMessage", self)

	self.playerUnit = GameLib.GetPlayerUnit():GetName()
	self.classId = GameLib.GetPlayerUnit():GetClassId()
	self:GetLasAbilities()
	
	self.timerUpdateLas:Stop()
	--If we're playing a spellslinger, load up our database of spellsurged spellIds
	--if (self.classId == 7) then
	--	self.spellslingerSurgedAbilities = QtSpellslinger:LoadSpells()
	--end
	--QtSpellslinger = nil
end

function MinzIA:OnGroupUpdate()
	--self:Output("OnGroupUpdate()")
	self:ClearForm()
	self:UpdateFormClass()
end

function MinzIA:OnGroupJoin()
	if not GroupLib.InRaid() then 
		self.wndMain:Show(true, true)
		self:UpdateFormClass()
		self.timerUpdateForm:Start()
		self.timerUpdateLocalIA:Start()
	end
end

function MinzIA:OnGroupLeft()
	--self:Output("OnGroupLeft()")
	self.timerUpdateForm:Stop()
	self.timerUpdateLocalIA:Stop()
	self.wndMain:Show(false, true)
end

function MinzIA:OnMinzIAMessage(channel, tMsg)
	--self:Output(tMsg.name.." "..tMsg.IA)
	if tMsg ~= nil then
		if tMsg.type == "update" then
			local idx = -1
			for k,v in pairs(self.party) do
				if v["Name"] == tMsg.name then
					idx = k
				end
			end
			if(self.party[idx] == nil) then return end
			self.party[idx]["IA"] = tMsg.IA
		end
	end
end

function MinzIA:Echo(tMsg)
	if(GroupLib.InGroup and not GroupLib.InRaid() and #self.party > 1) then
		self.comm:SendMessage(tMsg)
		self:OnMinzIAMessage(nil, tMsg)
	end
end


function MinzIA:CreateMsg(type, name, ia) 
	local tMsg = {}
	tMsg["type"] = type
	tMsg["name"] = name
	tMsg["IA"] = ia
	return tMsg
end

function MinzIA:ScheduleLasUpdate()
	self.retry = 0
	self.timerUpdateLas:Start()
end

function MinzIA:Output(string)
	if GroupLib.InGroup() then
		ChatSystemLib.Command("/p "..string)
	else 
		Print(string)
	end
end


function MinzIA:UpdateTrackedItems()
	if (self.trackedCooldowns ~= nil and #self.trackedCooldowns> 0) then
		self:UpdateCooldowns()
	end
end


function MinzIA:GetIA(splObj, tier)
	local splName = splObj:GetName()
	--self:Output(splName)
	if splName == "Flash" then return 0 end
	if (string.match("Crush,Paralytic Surge,Kick,Zap,Gate", splName)) then 
		if tier >= 5 then
			return 2
		else 
			return 1
		end
	end
	if(string.match("Stagger,Collapse,Flash Bang,Grapple,Obstruct Vision,Incapacitate,Shockwave,Arcane Shock", splName)) then
		return 1
	end
	
	return 0
end

function MinzIA:SkillUse(splName)
	local time = osclock()
	self.skillused[#self.skillused+1] = splName
	if (self.time == nil) then
		self.time = time;
	end
end

function MinzIA:CheckPrintSkillUse()
	if (self.time ~= nil) then
		if(self.time-osclock() < -1) then
			local count = 0
			for k,v in pairs(self.skillused) do
				count = count + tonumber(self.skillIA[v])
			end
			self:Output(self.playerUnit..' used '..count..' IA')
			self.skillused = {}
			self.time = nil
		end
	end
end


function MinzIA:UpdateLocalIA()
	local count = self.totalIA
	for k,v in pairs(self.activeCooldowns) do
		count = count - self.skillIA[v.splObj:GetName()]
	end
	self:Echo(self:CreateMsg("update", self.playerUnit, count))
end

function MinzIA:UpdateCooldowns()
	--self:Output(self.playerUnit)
	if (self.trackedCooldowns == nil) then
		self:GetLasAbilities()
		return
	end
	
	self:CheckPrintSkillUse()

	for i = 1, #self.trackedCooldowns do
		local spl = self.trackedCooldowns[i]
		local id = spl:GetId()
		local time = osclock()

		if (spl:GetAbilityCharges().nChargesMax > 0) then 
			--Handle abilities with charges
			local chargeObj = spl:GetAbilityCharges()
			if (chargeObj.nChargesRemaining < chargeObj.nChargesMax) then
				--Add new active cooldown or update existing active cooldown
				if (self.activeCooldowns[id] == nil) then
					self:AddActiveCooldown(id, spl, (chargeObj.fRechargeTime * chargeObj.fRechargePercentRemaining), chargeObj.nChargesRemaining, chargeObj.nChargesMax)
					self:SkillUse(spl:GetName())
					--self:Output(self.playerUnit.." uses "..spl:GetName())
				else
					self.activeCooldowns[id].charges = chargeObj.nChargesRemaining
					self.activeCooldowns[id].timer = (chargeObj.fRechargeTime * chargeObj.fRechargePercentRemaining)
					self.activeCooldowns[id].lastTimerUpdate = time
				end
			else
				--Set expired flag for cleanup
				if (self.activeCooldowns[id] ~= nil) then 
					self.activeCooldowns[id].expired = true
				end
			end
		else 
			--Handle abilities with cooldowns
			local fCooldown = spl:GetCooldownRemaining()

			if (self.activeCooldowns[id] == nil) then
				if (fCooldown > 0) then
					self:AddActiveCooldown(id, spl, fCooldown, -1, -1)
					self:SkillUse(spl:GetName())

					--self:Output(self.playerUnit.." uses "..spl:GetName())
				end
			elseif (fCooldown > 0) then
				self.activeCooldowns[id].lastTimerUpdate = time
			
				--Sometimes GetSpellCooldown will return a spell's full cooldown for a quick moment as
				--it comes off cooldown, instead of returning 0.  To handle this, ignore increases in
				--fCooldown if the spell is about to expire.
				if (not(self.activeCooldowns[id].timer < 1 and fCooldown > self.activeCooldowns[id].timer)) then
					self.activeCooldowns[id].timer = fCooldown
					self.activeCooldowns[id].timerFinished = fCooldown + time
				else
					self.activeCooldowns[id].timer = self.activeCooldowns[id].timerFinished - time
				end
			end

			--TODO: Fix issues with Warrior CD reset and Stalker stealth combat cooldown reset
			if (self.activeCooldowns[id] ~= nil and fCooldown <= 0) then
				self.activeCooldowns[id].expired = true
			end
		end

		--Handle expired cooldowns
		if (self.activeCooldowns[id] ~= nil and self.activeCooldowns[id].expired) then
			--self:Output(self.playerUnit.."'s "..spl:GetName().." is ready")
			self:ExpireActiveCooldown(id)
		end
	end
end


function MinzIA:AddActiveCooldown(argId, argSpl, argCooldown, argCharges, argMaxCharges)
	local time = osclock()

	--Workaround for GetCooldownRemaining() bug that sometimes returns a spell's max cooldown if it has just come off CD
	if (self.recentlyEndedCooldowns[argId] ~= nil and self.recentlyEndedCooldowns[argId] > osclock()) then
		return
	end

	self.activeCooldowns[argId] = {
		splObj = argSpl,
	 	timer = argCooldown,
	 	maxTimer = argCooldown,
	 	lastTimerUpdate = time,
	 	timerFinished = time + argCooldown,
	 	charges = argCharges,
	 	maxCharges = argMaxCharges,
	}

	for i = 1, #self.cooldownListeners do
		--Print("AddActiveCooldown: "..argSpl:GetName()..", filtered="..tostring(skip))

		if (not self:TestFilter(argSpl:GetName(), self.cooldownListeners[i].index, 1, argCooldown)) then
			self.cooldownListeners[i].icons[argId] = {
				wnd = nil,
				loc = -1,
				data = self.activeCooldowns[argId],
				overlayColor = self.currentProfile.bars[self.cooldownListeners[i].index].settings.cooldownColor
			}
		end
	end
end

function MinzIA:ExpireActiveCooldown(id)
	self.recentlyEndedCooldowns[id] = osclock() + 0.10
	self.activeCooldowns[id] = nil
	
end

function MinzIA:GetLasAbilities()
	self.trackedCooldowns = {}
	local las = ActionSetLib.GetCurrentActionSet()
	local abilities = AbilityBook.GetAbilitiesList()
	local innates = GameLib.GetClassInnateAbilitySpells()

	--Print("GetLas "..#abilities)
	if (abilities == nil) then 
		return 
	end
	self.totalIA = 0
	self.currentIA = 0
	--GetCurrentActionSet returns the base spellId for each spell on our LAS.
	--GetAbilitiesList returns the base spellId for all the valid spells for our class.
	--We loop through the abilitybook looking for base spells that are on our LAS,
	--and then get the appropriately tiered spellId, which is added to our trackedCooldowns table.
	for i = 1, #abilities do
		if (abilities[i].bIsActive) then
			for j = 1,8 do
				if (abilities[i].nId == las[j]) then
					local splObj = abilities[i].tTiers[abilities[i].nCurrentTier].splObject
					local nIA = self:GetIA(splObj, abilities[i].nCurrentTier)
					if(nIA > 0) then
						self.skillIA[splObj:GetName()] = nIA
						self.totalIA = self.totalIA + nIA
						if (splObj:GetCooldownTime() > 0 or splObj:GetAbilityCharges().nChargesMax > 0) then
							tinsert(self.trackedCooldowns, splObj)
						end
						--The surged version of each tier of each spellslinger spell has a different spellId, so we have to find those.
						--if (self.classId == 7) then
					--		local surged = self.spellslingerSurgedAbilities[abilities[i].nId]
				--			if (surged ~= nil) then
			---				local idTable = surged.tiers["t"..abilities[i].nCurrentTier]
			---					for k=1,#idTable do
			--						tinsert(self.trackedCooldowns, GameLib.GetSpell(idTable[k]))
		--						end
					--		end
						--end
					end
				end
			end
		end
	end
	self:Echo(self:CreateMsg("update", self.playerUnit, self.totalIA-self.currentIA))
	self.retry  = self.retry + 1
	if self.retry > 2 then
		self.timerUpdateLas:Stop()
	end
end

