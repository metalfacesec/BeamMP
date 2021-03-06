--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("MPModManager initialising...")



local timer = 0
local serverMods = {}
local mods = {"multiplayerbeammp", "beammp"}
local backupAllowed = true



local function IsModAllowed(n)
	for k,v in pairs(mods) do
		if string.lower(v) == string.lower(n) then
			return true
		end
	end
	for k,v in pairs(serverMods) do
		if string.lower(v) == string.lower(n) then
			return true
		end
	end
	return false
end



local function checkMod(mod)
	local modname = mod.modname
	local modAllowed = IsModAllowed(modname)
	if not modAllowed and mod.active then -- This mod is not allowed to be running
		print("This mod should not be running: "..modname)
		core_modmanager.deactivateMod(modname)
		if string.match(string.lower(modname), 'multiplayer') then
			core_modmanager.deleteMod(modname)
		end
	elseif modAllowed and not mod.active then
		print("Inactive Mod but Should be Active: "..modname)
		core_modmanager.activateMod(modname)--'/mods/'..string.lower(v)..'.zip')
		MPCoreNetwork.modLoaded(modname)
	end
end



local function checkAllMods()
	for modname, mod in pairs(core_modmanager.getModList()) do
		checkMod(mod)
		print("Checking mod "..mod.modname)
	end
end



local function cleanUpSessionMods()
	-- At this point isMPSession is false so we disable mods backup so that
	-- the call doesn't backup when it shouldn't
	backupAllowed = false
	for k,v in pairs(serverMods) do
		core_modmanager.deactivateMod(string.lower(v))
		if string.match(string.lower(v), 'multiplayer') then
			core_modmanager.deleteMod(string.lower(v))
		end
	end
	backupAllowed = true
	Lua:requestReload() -- reload Lua to make sure we don't have any leftover GE files
end



local function setServerMods(receivedMods)
	print("Server Mods Set:")
	dump(mods)
	serverMods = receivedMods
	for k,v in pairs(serverMods) do
		serverMods[k] = 'multiplayer'..v
	end
end



local function showServerMods()
	print(serverMods)
	dump(serverMods)
end



local function backupLoadedMods()
	-- Backup the current mods before joining the server
	local modsDB = jsonReadFile("mods/db.json")
	if modsDB then
		os.remove("settings/db-backup.json")
		jsonWriteFile("settings/db-backup.json", modsDB, true)
		print("Backed up db.json file")
	else
		print("No db.json file found")
	end
end



local function restoreLoadedMods()
	-- Backup the current mods before joining the server
	local modsDBBackup = jsonReadFile("settings/db-backup.json")
	if modsDBBackup then
		os.remove("mods/db.json")
		jsonWriteFile("mods/db.json", modsDBBackup, true)
		-- And delete the backup file because we don't need it anymore
		os.remove("settings/db-backup.json")
		print("Restored db.json backup")
	else
		print("No db.json backup found")
	end
end



-- Called from beammp\lua\ge\extensions\core
local function onModStateChanged(mod)
	-- The function makes two calls, one with a table and one with the mod name
	-- We only want the table not the mod name call
	if type(mod) ~= "table" then return end
	if MPCoreNetwork.isGoingMPSession() or MPCoreNetwork.isMPSession() then
		checkMod(mod)
	end
end



local function onInit()
	-- When the game inits we restore the db.json which deletes it and then back it up.
	-- If the game was closed correctly, there should be no db-backup.json file which mean
	-- that restoreLoadedMods won't do anything. Therefor not restoring a wrong backup
	restoreLoadedMods()
	backupLoadedMods()
end



local function onExit() -- Called when the user exits the game
	restoreLoadedMods() -- Restore the mods and delete db-backup.json when we quit the game
	-- Don't add isMPSession checking because onClientEndMission is called before!
end



local function onClientStartMission(mission)
	if MPCoreNetwork.isMPSession() then
		checkAllMods() -- Checking all the mods
	end
	-- Checking all the mods again because BeamNG.drive have a bug with mods not deactivating
end



local function onClientEndMission(mission)
	-- We restore the db.json before lua reloads because on reload the db.json get backup up
	-- if we were connected to a server this would cause a backup of the db.json with all mods disabled
	-- By doing this, lua activate itself the mods after the reload so we don't even need
	-- to enable the mods ourself.
	restoreLoadedMods()
end



local function modsDatabaseChanged()
	if not MPCoreNetwork.isMPSession() then
		backupLoadedMods()
	end
end



M.modsDatabaseChanged = modsDatabaseChanged
M.onClientEndMission = onClientEndMission
M.onClientStartMission = onClientStartMission
M.modsDatabaseChanged = modsDatabaseChanged
M.onModStateChanged = onModStateChanged
M.backupLoadedMods = backupLoadedMods
M.cleanUpSessionMods = cleanUpSessionMods
M.showServerMods = showServerMods
M.setServerMods = setServerMods
M.checkAllMods = checkAllMods
M.onExit = onExit
M.onInit = onInit



return M
