obs          = obslua
_source_name  = ""
source_name1 = ""
source_name2 = ""
source_name3 = ""
_file_name    = ""
file_name1   = ""
file_name2   = ""
file_name3   = ""
current_t    = 0
_time        = {}
_subtitles   = {}
current_sub  = 1
displayText  = ""
last_text    = ""

activated    = false
source1_active = false
source2_active = false
source3_active = false
timer_active = false
settings_    = nil
default_path = "C:\\Tools\\Sacrament Meeting"

function file_exists(file)
	local f = io.open(file, "rb")
	if f then f:close() end
	return f ~= nil
end

function get_time(tm)
	local startTime,endTime
	local t1={}
		if string.find(tm,',') then
			for word in string.gfind(tm,'%d%d:%d%d:%d%d,%d%d%d') do
				word = word:sub(1, -3)
				word = word:gsub(",",".")
				table.insert(t1,word)
			end
		else
			for word in string.gfind(tm,'%d%d:%d%d:%d%d.%d%d%d') do
				word = word:sub(1, -3)
				table.insert(t1,word)
			end
		end
	startTime = t1[1]
	endTime = t1[2]
	return {st = startTime, nd = endTime}
end

function subtitles_from(file)
	if not file_exists(file) then 
		return {} 
	end
	_subtitles = {}
	_time = {}
	collectgarbage()
	newSub = false
	subtitle = ""
	for line in io.lines(file) do 
		repeat
			if string.find(line,'-->') then
				newSub = true
				table.insert(_time,get_time(line))
				do break end
			end
			if newSub then
				if subtitle == "" then
					subtitle = line
				else
					subtitle = subtitle.."\n"..line
				end
			end
			if line == "" then
				newSub = false
				if subtitle ~= "" then
					table.insert(_subtitles,subtitle:sub(1,-2))
					subtitle = ""
				end
			end
		until true
	end
	--catch and insert last subtitle
	table.insert(_subtitles,subtitle)
	--print("[*] Subtitles imported")
end

function update_display()
	if timer_active then
		local timeText = ""
		local tenths   = math.floor(current_t % 10)
		local seconds  = math.floor((current_t / 10) % 60)
		local minutes  = math.floor((current_t / 600) % 60)
		local hours    = math.floor((current_t / 36000) % 24)
		
		timeText = string.format("%02d:%02d:%02d.%d", hours, minutes, seconds, tenths)
		
		if #_time > 0 then
			if _time[current_sub]["st"] == timeText then
				--print(_time[current_sub]["st"].."-->".._time[current_sub]["nd"])
				--print(_subtitles[current_sub])
				displayText = _subtitles[current_sub]
			end
			if _time[current_sub]["nd"] == timeText then
				if _time[current_sub]["nd"] == _time[#_time]["nd"] then
					stop_timer()
				elseif _time[current_sub+1]["st"] == _time[current_sub]["nd"] then
					displayText = _subtitles[current_sub+1]
				else
					displayText = ""
				end
				current_sub = current_sub + 1
			end
		end
	end
	local source = obs.obs_get_source_by_name(_source_name)
	
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", displayText)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end

function timer_callback()
	current_t = current_t + 1
	update_display()
end

function start_timer()
	timer_active = true
	obs.timer_add(timer_callback, 100)
end

function stop_timer()
	timer_active = false
	current_t = 0
	current_sub  = 1
	displayText  = ""
	obs.timer_remove(timer_callback)
	update_display()
end

function activate(activating, name)
	if activated == activating then
		return
	end
	
	activated = activating

	if activating then
		if name == source_name1 then
			_source_name = name
			_file_name = file_name1
			source1_active = true
			source2_active = false
			source3_active = false
		elseif name == source_name2 then
			_source_name = name
			_file_name = file_name2
			source1_active = false
			source2_active = true
			source3_active = false
		elseif name == source_name3 then
			_source_name = name
			_file_name = file_name3
			source1_active = false
			source2_active = false
			source3_active = true
		end 
		--subtitles_from(_file_name)
		stop_timer()
		--start_timer()
	end
	if (source1_active or source2_active or source3_active) then
		return
	else
		stop_timer()
	end
end

function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name1 or name == source_name2 or name == source_name3) then
			activate(activating, name)
		end
	end
end

function source_activated(cd)
	activate_signal(cd, true)
end

function source_deactivated(cd)
	activate_signal(cd, false)
end

function reset(pressed)
	if not pressed then
		return
	end
	stop_timer()
	update_display()
end

function on_pause(pressed)
	if not pressed then
		return
	end

	if current_t == 0 then
		reset(true)
	end

	if timer_active then
		stop_timer()
	else
		stop_timer()
		start_timer()
	end
end

function pause_button_clicked(props, p)
	on_pause(true)
	return false
end

function reset_button_clicked(props, p)
	reset(true)
	return false
end

function on_event(event)
	if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
		stop_timer()
		subtitles_from(_file_name)
		start_timer()
	end
end

function script_properties()
	local props = obs.obs_properties_create()
	
	local p1 = obs.obs_properties_add_list(props, "source1", "Text source 1", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_properties_add_path(props, "file_name1", "Source File 1", obs.OBS_PATH_FILE, "Subtitle Files (*.vtt *.srt)", default_path)
	local p2 = obs.obs_properties_add_list(props, "source2", "Text source 2", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_properties_add_path(props, "file_name2", "Source File 2", obs.OBS_PATH_FILE, "Subtitle Files (*.vtt *.srt)", default_path)
	local p3 = obs.obs_properties_add_list(props, "source3", "Text source 3", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_properties_add_path(props, "file_name3", "Source File 3", obs.OBS_PATH_FILE, "Subtitle Files (*.vtt *.srt)", default_path)
	
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" or source_id == "text_gdiplus_v2" or source_id == "text_ft2_source_v2" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p1, name, name)
				obs.obs_property_list_add_string(p2, name, name)
				obs.obs_property_list_add_string(p3, name, name)
			end
		end
	end
	obs.source_list_release(sources)
	
	obs.obs_properties_add_button(props, "pause_button", "Start/Stop", pause_button_clicked)
	obs.obs_properties_add_button(props, "reset_button", "Reset", reset_button_clicked)
	
	return props
end

function script_description()
	return "Overlays subtitles from file. Supports VTT and SRT."
end

function script_update(settings)
	activate(false)
	source_name1 = obs.obs_data_get_string(settings, "source1")
	file_name1 = obs.obs_data_get_string(settings, "file_name1")
	source_name2 = obs.obs_data_get_string(settings, "source2")
	file_name2 = obs.obs_data_get_string(settings, "file_name2")
	source_name3 = obs.obs_data_get_string(settings, "source3")
	file_name3 = obs.obs_data_get_string(settings, "file_name3")
	update_display()
	reset(true)
end

function script_load(settings)
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_show", source_activated)
	obs.signal_handler_connect(sh, "source_hide", source_deactivated)

	obs.obs_frontend_add_event_callback(on_event)

	settings_ = settings

	script_update(settings)
end
