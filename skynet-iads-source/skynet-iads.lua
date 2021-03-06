do
--[[
SAM Sites that engage HARMs:
SA-15


SAM Sites that ignore HARMS:
SA-11 (test again)
SA-10 (didn't react)
SA-6
]]--

--[[ Compile Scripts:

echo -- BUILD Timestamp: %DATE% %TIME% > skynet-iads-compiled.lua && type sam-types-db.lua skynet-iads.lua skynet-iads-abstract-dcs-object-wrapper.lua skynet-iads-abstract-element.lua skynet-iads-abstract-radar-element.lua skynet-iads-command-center.lua skynet-iads-contact.lua skynet-iads-early-warning-radar.lua skynet-iads-jammer.lua skynet-iads-sam-search-radar.lua skynet-iads-sam-site.lua skynet-iads-sam-tracking-radar.lua skynet-iads-sam-types-db-extension.lua syknet-iads-sam-launcher.lua >> skynet-iads-compiled.lua;

--]]

SkynetIADS = {}
SkynetIADS.__index = SkynetIADS

SkynetIADS.database = samTypesDB

function SkynetIADS:create()
	local iads = {}
	setmetatable(iads, SkynetIADS)
	iads.earlyWarningRadars = {}
	iads.samSites = {}
	iads.commandCenters = {}
	iads.ewRadarScanMistTaskID = nil
	iads.coalition = nil
	iads.contacts = {}
	iads.maxTargetAge = 32
	iads.contactUpdateInterval = 5
	iads.debugOutput = {}
	iads.debugOutput.IADSStatus = false
	iads.debugOutput.samWentDark = false
	iads.debugOutput.contacts = false
	iads.debugOutput.radarWentLive = false
	iads.debugOutput.ewRadarNoConnection = false
	iads.debugOutput.samNoConnection = false
	iads.debugOutput.jammerProbability = false
	iads.debugOutput.addedEWRadar = false
	iads.debugOutput.hasNoPower = false
	iads.debugOutput.addedSAMSite = false
	iads.debugOutput.warnings = true
	return iads
end

function SkynetIADS:setCoalition(item)
	if item then
		local coalitionID = item:getCoalition()
		if self.coalitionID == nil then
			self.coalitionID = coalitionID
		end
		if self.coalitionID ~= coalitionID then
			self:printOutput("element: "..item:getName().." has a different coalition than the IADS", true)
		end
	end
end

function SkynetIADS:getCoalition()
	return self.coalitionID
end

function SkynetIADS:addEarlyWarningRadarsByPrefix(prefix)
	for unitName, unit in pairs(mist.DBs.unitsByName) do
		local pos = string.find(string.lower(unitName), string.lower(prefix))
		--somehow the MIST unit db contains StaticObject, we check to see we only add Units
		local unit = Unit.getByName(unitName)
		if pos and pos == 1 and unit then
			self:addEarlyWarningRadar(unitName)
		end
	end
end

function SkynetIADS:addEarlyWarningRadar(earlyWarningRadarUnitName, powerSource, connectionNode)
	local earlyWarningRadarUnit = Unit.getByName(earlyWarningRadarUnitName)
	if earlyWarningRadarUnit == nil then
		self:printOutput("you have added an EW Radar that does not exist, check name of Unit in Setup and Mission editor: "..earlyWarningRadarUnitName, true)
		return
	end
	self:setCoalition(earlyWarningRadarUnit)
	local ewRadar = SkynetIADSEWRadar:create(earlyWarningRadarUnit, self)
	self:addPowerAndConnectionNodeTo(earlyWarningRadarUnitName, powerSource, connectionNode)
	table.insert(self.earlyWarningRadars, ewRadar)
	if self:getDebugSettings().addedEWRadar then
			self:printOutput(ewRadar:getDescription().." added to IADS")
	end
end

function SkynetIADS:setOptionsForEarlyWarningRadar(unitName, powerSource, connectionNode)
		local update = false
		for i = 1, #self.earlyWarningRadars do
			local ewRadar = self.earlyWarningRadars[i]
			if string.lower(ewRadar:getDCSName()) == string.lower(unitName) then
				self:addPowerAndConnectionNodeTo(ewRadar, powerSource, connectionNode)
				update = true
			end
		end
		if update == false then
			self:printOutput("you tried to set options for an EW radar that does not exist: "..unitName, true)
		end
end

function SkynetIADS:getEarlyWarningRadars()
	return self.earlyWarningRadars
end

function SkynetIADS:getEarlyWarningRadarByUnitName(unitName)
	for i = 1, #self.earlyWarningRadars do
		local ewRadar = self.earlyWarningRadars[i]
		if ewRadar:getDCSName() == unitName then
			return ewRadar
		end
	end
end

function SkynetIADS:addSamSitesByPrefix(prefix, autonomousMode)
	for groupName, groupData in pairs(mist.DBs.groupsByName) do
		local pos = string.find(string.lower(groupName), string.lower(prefix))
		if pos and pos == 1 then
			self:addSamSite(groupName, nil, nil, autonomousMode)
		end
	end
end

function SkynetIADS:addSamSite(samSiteName, powerSource, connectionNode, actAsEW, autonomousMode, firingRangePercent)
	local samSiteDCS = Group.getByName(samSiteName)
	if samSiteDCS == nil then
		self:printOutput("you have added an SAM Site that does not exist, check name of Group in Setup and Mission editor", true)
		return
	end
	self:setCoalition(samSiteDCS)
	local samSite = SkynetIADSSamSite:create(samSiteDCS, self)
	if samSite:getNatoName() == "UNKNOWN" then
		self:printOutput("you have added an SAM Site that Skynet IADS can not handle: "..samSite:getDCSName(), true)
	else
		samSite:goDark()
		table.insert(self.samSites, samSite)
		if self:getDebugSettings().addedSAMSite then
			self:printOutput(samSite:getDescription().." added to IADS")
		end
	end
	self:setOptionsForSamSite(samSiteName, powerSource, connectionNode, actAsEW, autonomousMode, firingRangePercent)
end

function SkynetIADS:setOptionsForSamSite(groupName, powerSource, connectionNode, actAsEW, autonomousMode, firingRangePercent)
	local update = false
	for i = 1, #self.samSites do
		local samSite = self.samSites[i]
		if string.lower(samSite:getDCSName()) == string.lower(groupName) then
			self:addPowerAndConnectionNodeTo(samSite, powerSource, connectionNode)
			samSite:setAutonomousBehaviour(autonomousMode)
			samSite:setActAsEW(actAsEW)
			samSite:setFiringRangePercent(firingRangePercent)
			update = true
		end
	end
	if update == false then
		self:printOutput("you tried to set options for a SAM site that does not exist: "..groupName, true)
	end
end

function SkynetIADS:getUsableSamSites()
	local usableSamSites = {}
	for i = 1, #self.samSites do
		local samSite = self.samSites[i]
		if samSite:hasActiveConnectionNode() and samSite:hasWorkingPowerSource() then
			table.insert(usableSamSites, samSite)
		end
	end
	return usableSamSites
end

function SkynetIADS:getSamSites()
	return self.samSites
end

function SkynetIADS:getSamSiteByGroupName(groupName)
	for i = 1, #self.samSites do
		local samSite = self.samSites[i]
		if samSite:getDCSName() == groupName then
			return samSite
		end
	end
end

function SkynetIADS:addPowerAndConnectionNodeTo(iadsElement, powerSource, connectionNode)
	if powerSource then
		self:setCoalition(powerSource)
		iadsElement:addPowerSource(powerSource)
	end
	if connectionNode then
		self:setCoalition(connectionNode)
		iadsElement:addConnectionNode(connectionNode)
	end
end

function SkynetIADS:addCommandCenter(commandCenter, powerSource)
	self:setCoalition(commandCenter)
	if powerSource then
		self:setCoalition(powerSource)
	end
	local comCenter = SkynetIADSCommandCenter:create(commandCenter, self)
	comCenter:addPowerSource(powerSource)
	table.insert(self.commandCenters, comCenter)
end

function SkynetIADS:isCommandCenterUsable()
	local hasWorkingCommandCenter = (#self.commandCenters == 0)
	for i = 1, #self.commandCenters do
		local comCenter = self.commandCenters[i]
		if comCenter:getLife() > 0 and comCenter:hasWorkingPowerSource() then
			hasWorkingCommandCenter = true
			break
		else
			hasWorkingCommandCenter = false
		end
	end
	return hasWorkingCommandCenter
end

function SkynetIADS:getCommandCenters()
	return self.commandCenters
end

function SkynetIADS:setSamSitesToAutonomousMode()
	for i= 1, #self.samSites do
		samSite = self.samSites[i]
		samSite:goAutonomous()
	end
end

function SkynetIADS.evaluateContacts(self)
	if self:getDebugSettings().IADSStatus then
		self:printSystemStatus()
	end	
	local iadsContacts = {}
	if self:isCommandCenterUsable() == false then
		if self:getDebugSettings().noWorkingCommmandCenter then
			self:printOutput("No Working Command Center")
		end
		self:setSamSitesToAutonomousMode()
		return
	end
	for i = 1, #self.earlyWarningRadars do
		local ewRadar = self.earlyWarningRadars[i]
		if ewRadar:hasActiveConnectionNode() then
			local ewContacts = ewRadar:getDetectedTargets()
			for j = 1, #ewContacts do
				local contact = ewContacts[j]
				self:mergeContact(contact)
			end
		else
			if self:getDebugSettings().ewRadarNoConnection then
				self:printOutput(ewRadar:getDescription().." no connection to Command Center")
			end
		end
	end
	
	local usableSamSites = self:getUsableSamSites()
	
	for i = 1, #usableSamSites do
		local samSite = usableSamSites[i]
		--see if this can be written with better code. We inform SAM sites that a target update is about to happen. if they have no targets in range after the cycle they go dark
		samSite:targetCycleUpdateStart()
		local samContacts = samSite:getDetectedTargets()
		for j = 1, #samContacts do
			local contact = samContacts[j]
			self:mergeContact(contact)
		end
	end
	
	local contactsToKeep = {}
	for i = 1, #self.contacts do
		local contact = self.contacts[i]
		if contact:getAge() < self.maxTargetAge then
			table.insert(contactsToKeep, contact)
		end
	end
	self.contacts = contactsToKeep
	
	
	for i = 1, #self.contacts do
		local contact = self.contacts[i]
		if self:getDebugSettings().contacts then
			self:printOutput("CONTACT: "..contact:getName().." | TYPE: "..contact:getTypeName().."| GS: "..tostring(contact:getGroundSpeedInKnots()).." | LAST SEEN: "..contact:getAge())
		end
		--currently the DCS Radar only returns enemy aircraft, if that should change an coalition check will be required
		---Todo: currently every type of object in the air is handed of to the sam site, including bombs and missiles, shall these be removed?
		self:correlateWithSamSites(contact)
	end
	
	for i = 1, #usableSamSites do
		local samSite = usableSamSites[i]
		samSite:targetCycleUpdateEnd()
	end
end

function SkynetIADS:mergeContact(contact)
	local existingContact = false
	for i = 1, #self.contacts do
		local iadsContact = self.contacts[i]
		if iadsContact:getName() == contact:getName() then
			iadsContact:refresh()
			existingContact = true
		end
	end
	if existingContact == false then
		table.insert(self.contacts, contact)
	end
end

function SkynetIADS:getContacts()
	return self.contacts
end

function SkynetIADS:printOutput(output, typeWarning)
	if typeWarning == true and self.debugOutput.warnings or typeWarning == nil then
		if typeWarning == true then
			output = "WARNING: "..output
		end
		trigger.action.outText(output, 4)
	end
end

function SkynetIADS:getDebugSettings()
	return self.debugOutput
end

function SkynetIADS:correlateWithSamSites(detectedAircraft)	
	local usableSamSites = self:getUsableSamSites()
	for i = 1, #usableSamSites do
		local samSite = usableSamSites[i]		
		samSite:informOfContact(detectedAircraft)
	end
end

-- will start going through the Early Warning Radars and SAM sites to check what targets they have detected
function SkynetIADS:activate()
	if self.ewRadarScanMistTaskID ~= nil then
		mist.removeFunction(self.ewRadarScanMistTaskID)
	end
	self.ewRadarScanMistTaskID = mist.scheduleFunction(SkynetIADS.evaluateContacts, {self}, 1, self.contactUpdateInterval)
end

function SkynetIADS:printSystemStatus()	
	local numComCenters = #self.commandCenters
	local numIntactComCenters = 0
	local numDestroyedComCenters = 0
	local numComCentersNoPower = 0
	local numComCentersServingIADS = 0
	for i = 1, #self.commandCenters do
		local commandCenter = self.commandCenters[i]
		if commandCenter:hasWorkingPowerSource() == false then
			numComCentersNoPower = numComCentersNoPower + 1
		end
		if commandCenter:getLife() > 0 then
			numIntactComCenters = numIntactComCenters + 1
		end
		if commandCenter:getLife() > 0 and commandCenter:hasWorkingPowerSource() then
			numComCentersServingIADS = numComCentersServingIADS + 1
		end
	end
	
	numDestroyedComCenters = numComCenters - numIntactComCenters
	
	self:printOutput("COMMAND CENTERS: Serving IADS: "..numComCentersServingIADS.." | Total: "..numComCenters.." | Intact: "..numIntactComCenters.." | Destroyed: "..numDestroyedComCenters.." | No Power: "..numComCentersNoPower)
	
	local ewNoPower = 0
	local ewTotal = #self.earlyWarningRadars
	local ewNoConnectionNode = 0
	local ewActive = 0
	local ewRadarsInactive = 0

	for i = 1, #self.earlyWarningRadars do
		local ewRadar = self.earlyWarningRadars[i]
		if ewRadar:hasWorkingPowerSource() == false then
			ewNoPower = ewNoPower + 1
		end
		if ewRadar:hasActiveConnectionNode() == false then
			ewNoConnectionNode = ewNoConnectionNode + 1
		end
		if ewRadar:isActive() then
			ewActive = ewActive + 1
		end
	end
	
	ewRadarsInactive = ewTotal - ewActive
	
	self:printOutput("EW SITES: "..ewTotal.." | Active: "..ewActive.." | Inactive: "..ewRadarsInactive.." | No Power: "..ewNoPower.." | No Connection: "..ewNoConnectionNode)
	
	local samSitesInactive = 0
	local samSitesActive = 0
	local samSitesTotal = #self.samSites
	local samSitesNoPower = 0
	local samSitesNoConnectionNode = 0
	for i = 1, #self.samSites do
		local samSite = self.samSites[i]
		if samSite:hasWorkingPowerSource() == false then
			samSitesNoPower = samSitesNoPower + 1
		end
		if samSite:hasActiveConnectionNode() == false then
			samSitesNoConnectionNode = samSitesNoConnectionNode + 1
		end
		if samSite:isActive() then
			samSitesActive = samSitesActive + 1
		end
	end
	samSitesInactive = samSitesTotal - samSitesActive
	self:printOutput("SAM SITES: "..samSitesTotal.." | Active: "..samSitesActive.." | Inactive: "..samSitesInactive.." | No Power: "..samSitesNoPower.." | No Connection: "..samSitesNoConnectionNode)
end

end
