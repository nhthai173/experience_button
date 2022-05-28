do -- globals
	PROXY_CMDS = {}
	EX_CMDS = {}
	ON_PROPERTY_CHANGED = {}
	TOGGLE_STATE = TOGGLE_STATE or false
	
	STATE_PROPERTIES = {
		on_normal = 'On Normal Name',
		on_warning = 'On Warning Name',
		on_danger = 'On Danger Name',
		off_normal = 'Off Normal Name',
		off_warning = 'Off Warning Name',
		off_danger = 'Off Danger Name'
	}
	STATE_NAME = STATE_NAME or {}
	STATE_DEFAULT = 'off_normal'
end

function OnDriverInit ()
	C4:UpdateProperty ('Driver Version', C4:GetDriverConfigInfo ("version"))
	STATE_NAME[STATE_PROPERTIES['on_normal']] = Properties[STATE_PROPERTIES['on_normal']] or 'On'
	STATE_NAME[STATE_PROPERTIES['on_warning']] = Properties[STATE_PROPERTIES['on_warning']] or 'Warning'
	STATE_NAME[STATE_PROPERTIES['on_danger']] = Properties[STATE_PROPERTIES['on_danger']] or 'Danger'
	STATE_NAME[STATE_PROPERTIES['off_normal']] = Properties[STATE_PROPERTIES['off_normal']] or 'Off'
	STATE_NAME[STATE_PROPERTIES['off_warning']] = Properties[STATE_PROPERTIES['off_warning']] or 'Warning'
	STATE_NAME[STATE_PROPERTIES['off_danger']] = Properties[STATE_PROPERTIES['off_danger']] or 'Danger'
	OnPropertyChanged('Toggle State Each Time Selected')
end


function OnDriverLateInit ()
	local state = PersistGetValue('state') or ''
	local initializing = true
	DisplayState(state, initializing)
end


function OnPropertyChanged(sProperty)

	local propertyValue = Properties[sProperty]

	-- Remove any spaces (trim the property)
	local trimmedProperty = string.gsub(sProperty, " ", "")

	for _, value in pairs(STATE_PROPERTIES) do
		if sProperty == value then
			STATE_NAME[value] = propertyValue
			return
		end
	end

	-- if function exists then execute (non-stripped)
	if (ON_PROPERTY_CHANGED[sProperty] ~= nil and type(ON_PROPERTY_CHANGED[sProperty]) == "function") then
		ON_PROPERTY_CHANGED[sProperty](propertyValue)
		return
	-- elseif trimmed function exists then execute
	elseif (ON_PROPERTY_CHANGED[trimmedProperty] ~= nil and type(ON_PROPERTY_CHANGED[trimmedProperty]) == "function") then
		ON_PROPERTY_CHANGED[trimmedProperty](propertyValue)
		return
	end
end

function ON_PROPERTY_CHANGED.ToggleStateEachTimeSelected (value)
	TOGGLE_STATE = (value == 'Yes')
end



function ExecuteCommand (strCommand, tParams)
    if EX_CMDS and type(EX_CMDS[strCommand]) == "function" then
            EX_CMDS[strCommand](tParams)
    elseif strCommand == "LUA_ACTION" then
        if tParams ~= nil then
            for cmd, cmdv in pairs(tParams) do
                print (cmd,cmdv)
                if cmd == "ACTION" then
                    if ACTIONS and type(ACTIONS[cmdv]) == "function" then
                        ACTIONS[cmdv](tParams)
                    else
                        print("From ExecuteCommand Function - Undefined Action")
                        print("Key: " .. cmd .. " Value: " .. cmdv)
                    end
                else
                    print("From ExecuteCommand Function - Undefined ACTION")
                    print("Key: " .. cmd .. " Value: " .. cmdv)
                end
            end
        end
    end
end

function ReceivedFromProxy (idBinding, strCommand, tParams)
    if type(PROXY_CMDS[strCommand]) == "function" then
        local success, retVal = pcall(PROXY_CMDS[strCommand], tParams, idBinding)
        if success then
            return retVal
        end
    end
    return nil
end

function PROXY_CMDS.SELECT (tParams, idBinding)
	print('PROXY_CMDS.SELECT')
	if TOGGLE_STATE then
		ToggleState()
	end
end

function EX_CMDS.SetState (tParams)
	DisplayState(tParams.State)
end

function EX_CMDS.ToggleState (tParams)
  PROXY_CMDS.SELECT (tParams)
end

function IsValidState(state)
	for key, _ in pairs(STATE_PROPERTIES) do
		if key == state then
			return true
		end
	end
	return false
end

function ToggleState()
	local state = PersistGetValue('state') or ''
	local index = 0
	for key, _ in pairs(STATE_PROPERTIES) do
		if index > 0 then
			state = key
			index = -1
			break
		end
		if key == state then
			index = index + 1
		end
	end
	if index > 0 then
		for key, _ in pairs(STATE_PROPERTIES) do
			if key then
				state = key
				index = -1
				break
			end
		end
	end

	-- any changes
	if index < 0 then
		DisplayState(state)
	end
end

function DisplayState (state, initializing)

	if state == '' then
		state = STATE_DEFAULT
	end

	if IsValidState(state) == true then
		PersistSetValue('state', state)
		local curState = STATE_NAME[STATE_PROPERTIES[state]]
		C4:SendToProxy(5001, "ICON_CHANGED", { icon = state, icon_description = curState })
		if (not initializing) then -- Don't fire the event if the driver is initializing
			C4:FireEvent(state)
		end

		C4:UpdateProperty('Current State', curState)
	else
		print('!Invalid State: ' .. state)
	end

end


function PersistSetValue (key, value, encrypted)
	if (encrypted == nil) then
		encrypted = false
	end

	if (C4.PersistSetValue) then
		C4:PersistSetValue (key, value, encrypted)
	else
		PersistData = PersistData or {}
		PersistData.LibValueStore = PersistData.LibValueStore or {}
		PersistData.LibValueStore [key] = value
	end
end

function PersistGetValue (key, encrypted)
	if (encrypted == nil) then
		encrypted = false
	end

	local value

	if (C4.PersistGetValue) then
		value = C4:PersistGetValue (key, encrypted)
		if (value == nil and encrypted == true) then
			value = C4:PersistGetValue (key, false)
			if (value ~= nil) then
				PersistSetValue (key, value, encrypted)
			end
		end
		if (value == nil) then
			if (PersistData and PersistData.LibValueStore and PersistData.LibValueStore [key]) then
				value = PersistData.LibValueStore [key]
				PersistSetValue (key, value, encrypted)
				PersistData.LibValueStore [key] = nil
				if (next (PersistData.LibValueStore) == nil) then
					PersistData.LibValueStore = nil
				end
			end
		end
	elseif (PersistData and PersistData.LibValueStore and PersistData.LibValueStore [key]) then
		value = PersistData.LibValueStore [key]
	end
	return value
end

function PersistDeleteValue (key)
	if (C4.PersistDeleteValue) then
		C4:PersistDeleteValue (key)
	else
		if (PersistData and PersistData.LibValueStore) then
			PersistData.LibValueStore [key] = nil
			if (next (PersistData.LibValueStore) == nil) then
				PersistData.LibValueStore = nil
			end
		end
	end
end

