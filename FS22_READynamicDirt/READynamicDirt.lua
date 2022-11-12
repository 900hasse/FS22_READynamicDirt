--
-- READynamicDirt Script
-- author: 900Hasse
-- date: 23.11.2022
--
-- V1.1.0.1
--
-----------------------------------------
-- TO DO
---------------
-- 
-- 
-- 


-----------------------------------------
-- KNOWN ISSUES
---------------
-- 
-- 
-- 	

print("----------------------------------------")
print("----- REA Dynamic Dirt by 900Hasse -----")
print("----------------------------------------")
READirt = {};

function READirt.prerequisitesPresent(specializations)
    return true
end;

function READirt:loadMap(name)
end

function READirt:deleteMap()
end

function READirt:draw(dt)
end;

function READirt:update(dt)

	-- Parameters
	-- Maximum number of lowspots allowed to be created
	local MaxNumberOfLowspots = 500;
	-- Searchsquare +/-, size of area for low spot
	local SearchSquare = 10;
	-- Max depth and min depth to create a lowspot
	local MaxScanWaterDepth = 0.30;
	local MinScanWaterDepth = 0.10;
	-- Min level of water in lowspot when no wetness
	local MinWaterDepth = -0.2;
	-- Lowspot size
	local SearchLowSpotSize = 60;
	-- Water level change, dm/hour
	local WaterLevelChange = {};
	WaterLevelChange.RatePerHour = {};
	WaterLevelChange.RatePerHour[WeatherType.SUN] = -0.0100;
	WaterLevelChange.RatePerHour[WeatherType.CLOUDY] = -0.0075;
	WaterLevelChange.RatePerHour[WeatherType.RAIN] = 0.0750;
	WaterLevelChange.RatePerHour[WeatherType.SNOW] = 0.0000;
	-- Update timer
	if READirt.LastUpdatedLowspot == nil then
		READirt.LastUpdatedLowspot = 0;
	end;

	-----------------------------------------
	-- Scan for low spots and create fillplanes for dirt
	-- This is only done after map has been loaded and will be done over several updates
	if not LowSpot.LowspotScanCompleted then
		local NumberOffScansPerUpdate = 25;
		-- Loop to scan for lowspots after map has been loaded
		for NumberOfScans=1,NumberOffScansPerUpdate do
			-- Scan for small lowspots
			LowSpot.LowspotScanCompleted = READirt:ScanForLowSpots(SearchSquare,MinScanWaterDepth,MaxScanWaterDepth,MaxNumberOfLowspots,SearchLowSpotSize);
			-- Time used to scan and create lowspots
			LowSpot.CurrentScanTime = LowSpot.CurrentScanTime + (dt / NumberOffScansPerUpdate);
			-- If scan is finished break loop
			if LowSpot.LowspotScanCompleted then
				break;
			end;
		end;
		-- Print result of scan
		if LowSpot.LowspotScanCompleted then
			print("------------------------------------");
			print("REA Dynamic dirt");
			print("Number of lowspots created: " .. table.getn(LowSpot.LowspotRootNode));
			print("Scantime lowspots(seconds): " .. LowSpot.CurrentScanTime / 1000);
			print("------------------------------------");
			-- Set global variable for REA to use
			-- Global variable to be used in REA to determine if scan is completed
			WheelsUtil.LowspotScanCompleted = true;
			WheelsUtil.LowspotRootNode = LowSpot.LowspotRootNode;
			WheelsUtil.LowspotWaterLevelNode = LowSpot.LowspotWaterLevelNode;
			WheelsUtil.LowspotMaxDepth = LowSpot.LowspotMaxDepth;
			WheelsUtil.LowspotSize = LowSpot.LowspotSize;
		end;

		-- Show scan status if debug active
		if LowSpot.DebugActive then
			renderText(0.2, 0.1, 0.03,"Current scan X: " .. LowSpot.CurrentScanX .. " Current scan Z: " .. LowSpot.CurrentScanZ);
			renderText(0.2, 0.15, 0.03,"Map width: " .. g_currentMission.mapWidth .. " Map height: " .. g_currentMission.mapHeight);
		end;
	end;

	-----------------------------------------
	-- Start handling of lowspots and water level
	if LowSpot.LowspotScanCompleted then
		-------------------------------------
		-- Debug active
		if LowSpot.DebugActive then
			-- Get number of lowspots
			local DebugNumLowSpots = table.getn(WheelsUtil.LowspotRootNode);
			-- Render wetness status
			local TemperatureDryFactor = MathUtil.clamp(g_currentMission.environment.weather:getCurrentTemperature() / 10, 0, 1);
			renderText(0.2, 0.10, 0.03,"WaterLevel: " .. LowSpot.CurrentWaterLevel);
			renderText(0.2, 0.15, 0.03,"Temperature dry factor: " .. TemperatureDryFactor);
			renderText(0.2, 0.25, 0.03,"Current temperature: " .. g_currentMission.environment.weather:getCurrentTemperature());
			renderText(0.2, 0.30, 0.03,"Level change: " .. READirt:GetLevelChange(WaterLevelChange.RatePerHour,dt));
			renderText(0.2, 0.35, 0.03,"Rain scale: " .. g_currentMission.environment.weather:getRainFallScale());
			-- Render wether state
			local ActiveWeatherType = READirt:GetWeatherType();
			local Weather = ""
			if ActiveWeatherType == WeatherType.SUN then
				Weather = "SUN"
			elseif ActiveWeatherType == WeatherType.RAIN then
				Weather = "RAIN"
			elseif ActiveWeatherType == WeatherType.CLOUDY then
				Weather = "CLOUDY"
			elseif ActiveWeatherType == WeatherType.SNOW then
				Weather = "SNOW"
			end;
			renderText(0.2, 0.40, 0.03,"Weather: " .. Weather);
			-- Print lowspots
			for ActLowSpot=1, DebugNumLowSpots do
				-- Get current water level
				local _,CurrentWaterLevel,_ = getTranslation(WheelsUtil.LowspotWaterLevelNode[ActLowSpot]);
				CurrentWaterLevel = READirt:RoundValue(CurrentWaterLevel*1000)/1000;
				DebugUtil.drawDebugNode(WheelsUtil.LowspotRootNode[ActLowSpot], "LS: " .. ActLowSpot .. ", " .. CurrentWaterLevel, false)
			end;
			-- Get number of lowspots
			local DebugNumSearchAreas = table.getn(LowSpot.DebugSearchareaLowestSpot);
			renderText(0.2, 0.45, 0.03,"Number of search areas: " .. DebugNumSearchAreas);
			-- Draw lowest found spot in search area and search area
			for ActSearchArea=1, DebugNumSearchAreas do
				READirt:DrawSearchAreaDebug(ActSearchArea,SearchSquare);
			end;
		end;

		-------------------------------------
		-- Update water level, Current lowspot to update
		local ActLowSpot = READirt.LastUpdatedLowspot + 1;
		-- Get water level factor
		local WaterLevelFactor = 0;
		WaterLevelFactor,LowSpot.LastUpdateTime,LowSpot.CurrentWaterLevel = READirt:GetWaterLevelFactor(WaterLevelChange.RatePerHour,MaxScanWaterDepth,LowSpot.LastUpdateTime,LowSpot.CurrentWaterLevel);
		-- Calculate new water level
		local NewWaterLevel = MinWaterDepth;
		if WaterLevelFactor > 0.05 then
			NewWaterLevel = MathUtil.clamp(WheelsUtil.LowspotMaxDepth[ActLowSpot] * WaterLevelFactor, 0, WheelsUtil.LowspotMaxDepth[ActLowSpot]);
		end;
		-- Set water level of lowspot
		setTranslation(WheelsUtil.LowspotWaterLevelNode[ActLowSpot], 0, NewWaterLevel, 0);
		-- Save last updated lowspot
		if ActLowSpot >= table.getn(WheelsUtil.LowspotRootNode) then
			READirt.LastUpdatedLowspot = 0;
		else
			READirt.LastUpdatedLowspot = ActLowSpot;
		end;
	end;
end


-----------------------------------------------------------------------------------	
-- Function to scan map for low spots and adding water in low spots
-----------------------------------------------------------------------------------
function READirt:ScanForLowSpots(SearchSquare,MinWaterDepth,MaxWaterDepth,MaxNumberOfLowSpots,SearchLowSpotSize)
	-----------------------------------------
	-- How far from edge should the search for low spots start and end
	local EdgeMargin = READirt:RoundValue(SearchSquare);
	local ScanSteps = READirt:RoundValue(SearchSquare*2);
	-- Start and end of search
	local ScanStartX = ((g_currentMission.mapWidth / 2) - EdgeMargin) * (-1);
	local ScanEndX = ((g_currentMission.mapWidth / 2) - EdgeMargin);
	local ScanStartZ = ((g_currentMission.mapHeight / 2) - EdgeMargin) * (-1);
	local ScanEndZ = ((g_currentMission.mapHeight / 2) - EdgeMargin);
	-- If no scan active load start values and set scan active
	if not LowSpot.ScanActive then
		LowSpot.CurrentScanX = ScanStartX;
		LowSpot.CurrentScanZ = ScanStartZ;
		LowSpot.ScanActive = true;
	end;
	-- Max and min values for coordinates
	LowSpot.CurrentScanX = math.max(LowSpot.CurrentScanX,ScanStartX);
	LowSpot.CurrentScanX = math.min(LowSpot.CurrentScanX,ScanEndX);
	LowSpot.CurrentScanZ = math.max(LowSpot.CurrentScanZ,ScanStartZ);
	LowSpot.CurrentScanZ = math.min(LowSpot.CurrentScanZ,ScanEndZ);

	-----------------------------------------
	-- Search the coordinates for low spot
	READirt:GetIsLowSpots(LowSpot.CurrentScanX,0,LowSpot.CurrentScanZ,SearchSquare,MinWaterDepth,MaxWaterDepth,SearchLowSpotSize);

	-----------------------------------------
	-- No more lowspots allowed to be created
	if table.getn(LowSpot.LowspotRootNode) >= MaxNumberOfLowSpots then
		return true;
	end;
	-- If scan is not completed count to next
	if LowSpot.CurrentScanX >= ScanEndX and LowSpot.CurrentScanZ >= ScanEndZ then
		LowSpot.CurrentScanX = 0;
		LowSpot.CurrentScanZ = 0;
		LowSpot.ScanActive = false;
		return true;
	else
		-- Count to next Z coordinate
		if LowSpot.CurrentScanZ < ScanEndZ then
			LowSpot.CurrentScanZ = LowSpot.CurrentScanZ + ScanSteps;
		-- Count to next X coordinate
		else
			LowSpot.CurrentScanX = LowSpot.CurrentScanX + ScanSteps;
			LowSpot.CurrentScanZ = ScanStartZ;
		end;
	end;
	return false;
end;


-----------------------------------------------------------------------------------	
-- Function to determine if there is a low spot near given coordinates
-----------------------------------------------------------------------------------
function READirt:GetIsLowSpots(wX,wY,wZ,SearchSquare,MinWaterDepth,MaxWaterDepth,SearchLowSpotSize)

	-----------------------------------------
	local DebugRejectReason = ".";

	-----------------------------------------
	-- Smallest size of lowspot
	local MinSize = 3;

	-----------------------------------------
	-- Get lowest point in search region
	local PointIsALowSpot = false;
	-- Result of search
	local LowestSpotX = 0;
	local LowestSpotY = 0;
	local LowestSpotZ = 0;
	local LowestSpotLastHeight;
	-- Get lowest point in the search region to use as reference point
	for OffsX=SearchSquare*(-1), SearchSquare, 1 do
		for OffsZ=SearchSquare*(-1), SearchSquare, 1 do
			-- X, Y and Z position
			local SearchLowestSpotX = wX+OffsX;
			local SearchLowestSpotY = wY;
			local SearchLowestSpotZ = wZ+OffsZ;
			local SearchLowestSpotHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, SearchLowestSpotX, SearchLowestSpotY, SearchLowestSpotZ);
			-- Check if this is the first position or if this position is lower than the last one
			if LowestSpotLastHeight == nil then
				LowestSpotLastHeight = SearchLowestSpotHeight;
				LowestSpotX = SearchLowestSpotX;
				LowestSpotY = SearchLowestSpotHeight;
				LowestSpotZ = SearchLowestSpotZ;
			elseif SearchLowestSpotHeight < LowestSpotLastHeight then
				LowestSpotLastHeight = SearchLowestSpotHeight;
				LowestSpotX = SearchLowestSpotX;
				LowestSpotY = SearchLowestSpotHeight;
				LowestSpotZ = SearchLowestSpotZ;
			end;				
		end;
	end;


	-----------------------------------------
	-- Check if there is lower land close of lowest found spot
	local MinDistanceToLowerLand = READirt:RoundValue(MinSize+1);
	for OffsX=MinDistanceToLowerLand*(-1), MinDistanceToLowerLand, 1 do
		for OffsZ=MinDistanceToLowerLand*(-1), MinDistanceToLowerLand, 1 do
			-- X, Y and Z position
			local SearchLowerSpotX = LowestSpotX+OffsX;
			local SearchLowerSpotZ = LowestSpotZ+OffsZ;
			local SearchLowerSpotHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, SearchLowerSpotX, 0, SearchLowerSpotZ);
			-- Check if this is lower the lowest point in search region
			if SearchLowerSpotHeight < (LowestSpotY - 0.001) then
				PointIsALowSpot = false;
				DebugRejectReason = "Low land to close";
				break;
			else
				PointIsALowSpot = true;
			end;
		end;
		-- If lower point found skip further check
		if not PointIsALowSpot then
			break;
		end;
	end;

	-----------------------------------------
	-- Check if below another object
	if PointIsALowSpot then
		local Offset = 0.1;
		local MaxDistance = 20.0;
		-- Check if there is another object 
		local NumberOfOjects = raycastClosest(LowestSpotX, LowestSpotY + Offset, LowestSpotZ, 0.0, 1.0, 0.0, "groundRaycastCallback", MaxDistance);
		-- Object found, do not create a lowspot
		if NumberOfOjects ~= nil then
			if NumberOfOjects > 0 then
				DebugRejectReason = "Object above";
				PointIsALowSpot = false;
			end;
		end;
	end;

	-----------------------------------------
	-- Check all around if this point is lower then all other
	local FoundLowSpotSize = 0;
	local FoundLowSpotDepth = 0;
	if PointIsALowSpot then
		local FoundLowSpotX = false;
		local FoundLowSpotZ = false;
		for Depth=MaxWaterDepth,MinWaterDepth,-0.05 do
			-- Min depth of low spot
			local MinDepth = Depth + 0.02;
			for Size=MinSize,SearchLowSpotSize,1 do
				-- X
				FoundLowSpotX = true;
				for OffsX=-Size, Size do
					if READirt:IsPointHigher(LowestSpotX+OffsX, 0, LowestSpotZ+Size, MinDepth, LowestSpotLastHeight) and READirt:IsPointHigher(LowestSpotX+OffsX, 0, LowestSpotZ-Size, MinDepth, LowestSpotLastHeight) then
						-- Point is higher then reference point, do not change status
					else
						-- Point is lower
						FoundLowSpotX = false;
						break;
					end;
				end;
				-- Z
				FoundLowSpotZ = true;
				for OffsZ=-Size, Size do
					if READirt:IsPointHigher(LowestSpotX+Size, 0, LowestSpotZ+OffsZ, MinDepth, LowestSpotLastHeight) and READirt:IsPointHigher(LowestSpotX-Size, 0, LowestSpotZ+OffsZ, MinDepth, LowestSpotLastHeight) then
						-- Point is higher then reference point, do not change status
					else
						-- Point is lower
						FoundLowSpotZ = false;
						break;
					end;
				end;
				-- if lowspot found save size and depth and exit
				if FoundLowSpotX and FoundLowSpotZ then
					-- Save size and depth
					FoundLowSpotSize = Size;
					FoundLowSpotDepth = Depth;
					break;
				end;			
			end;
			-- if lowspot found save size and exit
			if FoundLowSpotX and FoundLowSpotZ then
				break;
			end;			
		end;
		-- Low spot found
		if FoundLowSpotX and FoundLowSpotZ then
			--Do nothing
		else
			PointIsALowSpot = false;
			DebugRejectReason = "Not a low spot";
		end;
	end;

	-----------------------------------------
	-- Check if below water level
	if PointIsALowSpot then
		if LowestSpotY + FoundLowSpotDepth <= g_currentMission.waterY then
			DebugRejectReason = "Below water";
			PointIsALowSpot = false;
		end;
	end;

	-----------------------------------------
	-- Check if there is a low spot near
	if PointIsALowSpot then
		local NumLowSpots = table.getn(LowSpot.LowspotRootNode);
		if NumLowSpots > 0 then
			for ActLowSpot=1, NumLowSpots do
				-- Get distance to closest spot
				local x, y, z=getTranslation(LowSpot.LowspotRootNode[ActLowSpot]);
				local DiffX = math.abs(LowestSpotX - x)
				local DiffZ = math.abs(LowestSpotZ - z)
				local MinDistanceToNextLowSpot = (LowSpot.LowspotSize[ActLowSpot] + FoundLowSpotSize) + 1;
				-- Check if to close to another low spot
				if DiffX < MinDistanceToNextLowSpot and DiffZ < MinDistanceToNextLowSpot then
					PointIsALowSpot = false;
					DebugRejectReason = "Low spot to close";
					break;
				end;
			end;
		elseif NumLowSpots == 0 then
			-- If no low spots has been created there is no other low spot to compare with
			PointIsALowSpot = true;
		end;
	end;

	-----------------------------------------
	-- If Debug active save lowest spot
	if LowSpot.DebugActive then
		-- Create node for lowest spot
		local LowestNode = createTransformGroup("NodeName");
		-- Create nodes for search region
		setTranslation(LowestNode, LowestSpotX, LowestSpotY, LowestSpotZ);
		-- Add data to debug tables
		table.insert(LowSpot.DebugSearchareaLowestSpot,LowestNode);
		table.insert(LowSpot.DebugSearchareaReason,DebugRejectReason);
	end;

	-----------------------------------------
	-- Create a fillplane if this is a low spot
	-- Check if this is a low spot
	if PointIsALowSpot then
		-- Create node for low spot
		local RootNode = createTransformGroup("LowSpotRootNode");
		setTranslation(RootNode, LowestSpotX, LowestSpotY, LowestSpotZ);
		setRotation(RootNode, 0, 0, 0);
		setScale(RootNode, 1, 1, 1);
		setVisibility(RootNode, true);

		-- Load I3D for water
		local FileName = "water.i3d";
		local WaterRootNode = g_i3DManager:loadSharedI3DFile(LowSpot.FilePath .. FileName, false, false, false);
		local WaterLevelNode = getChildAt(WaterRootNode, 0)

		-- If Debug active print found low spots
		if LowSpot.DebugActive then
			print("------------------------------------");
			print("Low spot created by REA Dynamic dirt");
			print("Size(radius): " .. FoundLowSpotSize .. " meter");
			print("Depth: " .. FoundLowSpotDepth .. " meter");
			print("Number: " .. table.getn(LowSpot.LowspotRootNode)+1 .. " X: " .. LowestSpotX .. " Z: " .. LowestSpotZ .. " Height: " .. LowestSpotY)
			print("------------------------------------");
		end;

		link(getRootNode(), WaterLevelNode)
		delete(WaterRootNode)

		-- Get original scale of waterplane
		local Wx,Wy,Wz = getScale(WaterLevelNode);
		-- Real size of plane 
		local RealSize = 42;
		-- Calculate scale factors
		local ScaleX = Wx/RealSize;
		local ScaleZ = Wz/RealSize;

		-- Set new scale of waterplane
		setScale(WaterLevelNode,((FoundLowSpotSize*2)+0.5)*ScaleX,Wy,((FoundLowSpotSize*2)+0.5)*ScaleZ);

		-- Add data to lowspot table
		table.insert(LowSpot.LowspotRootNode,RootNode);
		table.insert(LowSpot.LowspotWaterLevelNode,WaterLevelNode);
		table.insert(LowSpot.LowspotMaxDepth,FoundLowSpotDepth);
		table.insert(LowSpot.LowspotSize,FoundLowSpotSize);

		-- Get number of lowspots
		local NextLowSpot = table.getn(LowSpot.LowspotRootNode);

		-- Link waterlevel to lowspot
		link(g_currentMission.terrainRootNode, LowSpot.LowspotRootNode[NextLowSpot]);
		link(LowSpot.LowspotRootNode[NextLowSpot], LowSpot.LowspotWaterLevelNode[NextLowSpot]);
		-- Set default level of water
		setTranslation(LowSpot.LowspotWaterLevelNode[NextLowSpot], 0, -0.2, 0);

	end;
end;


-----------------------------------------------------------------------------------	
-- Function to determine if this point is lower then reference point
-----------------------------------------------------------------------------------
function READirt:IsPointHigher(wX, wY, wZ, MinDepth, ReferenceHeight)
	-- Get height of point
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wX, wY, wZ);
	-- Determine if point is heigher then reference point
	if terrainHeight >= (ReferenceHeight + MinDepth) then
		return true;
	else
		return false;
	end;
end


-----------------------------------------------------------------------------------	
-- Raycast callback function
-----------------------------------------------------------------------------------
function READirt:groundRaycastCallback(hitObjectId, x, y, z, distance)
	if hitObjectId ~= nil then
		return false
	end;
end


-----------------------------------------------------------------------------------	
-- Get weather type
-----------------------------------------------------------------------------------
function READirt:GetWeatherType()
	local ActiveWeatherType = WeatherType.SUN;
	if g_currentMission ~= nil and g_currentMission.environment ~= nil then
		local CurrentWeather = g_currentMission.environment.weather:getCurrentWeatherType();
		if CurrentWeather >= WeatherType.SUN and CurrentWeather <= WeatherType.SNOW then
			ActiveWeatherType = CurrentWeather;
		end;
	end;
	return ActiveWeatherType;
end


-----------------------------------------------------------------------------------	
-- Get level change
-----------------------------------------------------------------------------------
function READirt:GetLevelChange(RatePerHour,ElapsedTimeMS)
	-- Get rate per hour for current weather
	local CurrentWeatherType = READirt:GetWeatherType();
	local LevelChange = RatePerHour[CurrentWeatherType];
	-- If rain, get rain scale
	if CurrentWeatherType == WeatherType.RAIN then
		LevelChange = LevelChange * g_currentMission.environment.weather:getRainFallScale();
	end;
	-- If drying, get temperature
	if LevelChange < 0 then
		local TemperatureDryFactor = MathUtil.clamp(g_currentMission.environment.weather:getCurrentTemperature() / 10, 0, 1);
		LevelChange = LevelChange * TemperatureDryFactor;
	end;
	-- Calculate hour/change
	local SecondsPerHour = 3600;
	local MsPerSecond = 1000;
	return ((ElapsedTimeMS/MsPerSecond)/SecondsPerHour)*LevelChange;
end


-----------------------------------------------------------------------------------	
-- Get water level factor
-----------------------------------------------------------------------------------
function READirt:GetWaterLevelFactor(RatePerHour,MaxWaterLevel,LastUpdateTime,CurrentWaterLevel)
	-- Read current time
	local currentTime = g_currentMission.environment.dayTime;
	-- Get in game time differance since last update
	local TimeDiff = math.max(0,currentTime - LastUpdateTime);
	-- Level change
	local LevelChange = 0;
	if TimeDiff > 0 and LastUpdateTime ~= 0 then
		LevelChange = READirt:GetLevelChange(RatePerHour,TimeDiff);
	end;
	-- New water level
	local NewCurrentWaterLevel = MathUtil.clamp(CurrentWaterLevel + LevelChange, 0, MaxWaterLevel);
	-- Return water level factor
	return MathUtil.clamp(NewCurrentWaterLevel / MaxWaterLevel, 0, 1),currentTime,NewCurrentWaterLevel;
end


-----------------------------------------------------------------------------------	
-- Function to round value, delete decimals
-----------------------------------------------------------------------------------
function READirt:RoundValue(x)
	return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end


-----------------------------------------------------------------------------------	
-- Function to draw text at node within set distance
-----------------------------------------------------------------------------------
function READirt:DrawSearchAreaDebug(ActSearchArea,SearchSquare)
	local x, y, z = getTranslation(LowSpot.DebugSearchareaLowestSpot[ActSearchArea])
	local x1, y1, z1 = getWorldTranslation(getCamera())
	local diffX = x - x1
	local diffY = y - y1
	local diffZ = z - z1
	local dist = MathUtil.vector3LengthSq(diffX, diffY, diffZ)
	-- If within distance to draw debug
	if dist <= 100 * 100 then
		-- Draw lowest point
		DebugUtil.drawDebugNode(LowSpot.DebugSearchareaLowestSpot[ActSearchArea],"X " .. LowSpot.DebugSearchareaReason[ActSearchArea], false)
		-- Draw outside of search region
		drawDebugLine(x-SearchSquare, y+1, z, 255, 255, 153, x+SearchSquare, y+1, z, 255, 255, 153);
		drawDebugLine(x, y+1, z-SearchSquare, 255, 255, 153, x, y+1, z+SearchSquare, 255, 255, 153);
	end
end


-----------------------------------------------------------------------------------	
-- deep dumps the contents of the table and it's contents' contents
-----------------------------------------------------------------------------------	
function READirt:deepdump(tbl)
    local checklist = {}
    local function innerdump( tbl, indent )
        checklist[ tostring(tbl) ] = true
        for k,v in pairs(tbl) do
            print(indent..k,v,type(v),checklist[ tostring(tbl) ])
            if (type(v) == "table" and not checklist[ tostring(v) ]) then innerdump(v,indent.."    ") end
        end
    end
    print("=== DEEPDUMP -----")
    checklist[ tostring(tbl) ] = true
    innerdump( tbl, "" )
    print("------------------")
end


-----------------------------------------------------------------------------------	
-- Load ground wetness  
-----------------------------------------------------------------------------------
function READirt.loadedMission(mission, node)
    if mission:getIsServer() then
        if mission.missionInfo.savegameDirectory ~= nil and fileExists(mission.missionInfo.savegameDirectory .. "/READirt.xml") then
            local xmlFile = XMLFile.load("READirtXML", mission.missionInfo.savegameDirectory .. "/READirt.xml")
            if xmlFile ~= nil then
				LowSpot.CurrentWaterLevel = xmlFile:getFloat("READirt.CurrentWaterLevel", LowSpot.CurrentWaterLevel)
				print("------------------------------------")
				print("REA Dynamic Dirt")
				print("loaded current water level from XML")
				print("File: " .. mission.missionInfo.savegameDirectory .. "/READirt.xml")
				print("Value: " .. LowSpot.CurrentWaterLevel)
				print("------------------------------------")
                xmlFile:delete()
            end
        end
    end
    if mission.cancelLoading then
        return
    end
end


-----------------------------------------------------------------------------------	
-- Save ground wetness  
-----------------------------------------------------------------------------------
function READirt.saveToXMLFile(missionInfo)
    if missionInfo.isValid then
        local xmlFile = XMLFile.create("READirtXML", missionInfo.savegameDirectory .. "/READirt.xml", "READirt")
        if xmlFile ~= nil then
			xmlFile:setFloat("READirt.CurrentWaterLevel", LowSpot.CurrentWaterLevel)
            xmlFile:save()
            xmlFile:delete()
        end
    end
end


if READirt.ModActivated == nil then
	addModEventListener(READirt);
	READirt.ModActivated = true;
	print("REA Dynamic dirt mod activated")

	LowSpot = {};

	-- Connect saving and loading functions
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, READirt.loadedMission);
    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, READirt.saveToXMLFile);

	-- Declare variables for low spots
	LowSpot.FilePath = g_currentModDirectory;
	LowSpot.DebugSearchareaLowestSpot = {};
	LowSpot.DebugSearchareaReason = {};
	LowSpot.LowspotRootNode = {};
	LowSpot.LowspotWaterLevelNode = {};
	LowSpot.LowspotMaxDepth = {};
	LowSpot.LowspotSize = {};
	LowSpot.LastUpdateTime = 0;
	LowSpot.CurrentWaterLevel = 0;
	LowSpot.CurrentScanX = 0;
	LowSpot.CurrentScanZ = 0;
	LowSpot.CurrentScanTime = 0;
	LowSpot.LowspotScanCompleted = false;
	LowSpot.ScanActive = false;
	LowSpot.ScanCompleted = false;
	LowSpot.DebugActive = false;
end;


