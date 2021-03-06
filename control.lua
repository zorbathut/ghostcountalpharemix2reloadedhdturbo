local mod_gui = require("mod-gui")

function init_gui(player)
	if mod_gui.get_button_flow(player).ghostCountGUI~=nil then
		mod_gui.get_button_flow(player).ghostCountGUI.destroy()
	end
	mod_gui.get_button_flow(player).add
	{
	type = "sprite-button",
	name = "ghostCountGUI",
	sprite = "ghostCountSprite",
	tooltip="Count ghosts on the map",
	style = mod_gui.button_style
	}
end

function count_ghosts(player)
	local count={}
	for key, ent in pairs(game.surfaces[1].find_entities_filtered({type="entity-ghost"})) do
		count[ent.ghost_name]=(count[ent.ghost_name] or 0) + 1
	end
	for key, ent in pairs(game.surfaces[1].find_entities_filtered({to_be_upgraded=true})) do
		local target = ent.get_upgrade_target().name
		count[target]=(count[target] or 0) + 1
	end
	return count
end

function accumulate_examples(player, gname)
	-- I'm legit surprised that performance runs well up to 5000. Test with more later, I guess?
	local maxexamples = 5000
	local count = 0
	local examples = {}
	
	local function process(ent, name)
		if name == gname then
			count = count + 1
			
			if #examples < maxexamples then
				table.insert(examples, ent)
			else
				rnd = math.random(1, count)
				if rnd < maxexamples then
					examples[rnd] = ent
				end
			end
		end
	end
	
	for key, ent in pairs(game.surfaces[1].find_entities_filtered({type="entity-ghost"})) do
		process(ent, ent.ghost_name)
	end
	for key, ent in pairs(game.surfaces[1].find_entities_filtered({to_be_upgraded=true})) do
		process(ent, ent.get_upgrade_target().name)
	end
	
	return examples
end

function main_button(player)
	if player.gui.left.gcFrame~=nil then
		player.gui.left.gcFrame.destroy()
	else
		gcFrame=player.gui.left.add({type = "frame", name = "gcFrame", direction = "horizontal"})
		gcScroll=gcFrame.add({type = "scroll-pane", name = "gcScroll", vertical_scroll_policy = "auto"})
		gcScroll.style.maximal_height = 400
		gcTable=gcScroll.add({type = "table", column_count = 3, name = "gcTable", direction = "vertical"})
		updateGUI(player)
	end
end

function updateGUI(player)
	gcTable=player.gui.left.gcFrame.gcScroll.gcTable
	gcTable.clear()
	gcTable.add({type="label",name="col1",caption="Item"})
	gcTable.add({type="label",name="col2",caption="Have"})
	gcTable.add({type="label",name="col3",caption="Need"})
	c=count_ghosts(player)
	
	for ent, need in spairs(c, function(t,a,b) return t[b] < t[a] end) do
		-- get the entity prototype so we can find out what item corresponds to this
		local have = 0
		local entproto = game.entity_prototypes[ent]
		if entproto.items_to_place_this ~= nil then
			have = player.get_main_inventory().get_item_count(entproto.items_to_place_this[1].name)
		end
		
		gcTable.add({type="sprite",name="gc-request-"..ent,sprite="entity/"..ent, caption=ent})
		gcTable.add({type="label",name=ent.."-have", caption=have})
		
		if have >= need then
			gcTable.add({type="label",name=ent.."-need", caption={"", "[color=#666666]", need, "[/color]"}})
		else
			gcTable.add({type="label",name=ent.."-need", caption=need})
		end
	end
end

function spairs(t, order)
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

script.on_event(defines.events.on_player_created, function(event)
    init_gui(game.players[event.player_index])
end)
script.on_event(defines.events.on_gui_click, function(event)
 	if event.element.name == "ghostCountGUI" then
    	main_button(game.players[event.player_index])
    elseif event.element.name:find("gc-request-", 1, true) == 1 then
		-- see if we can get a useful item out of this
		local signal = {type = "signal", name = "signal-info"}
		local name = event.element.name:sub(12, -1)
		local entproto = game.entity_prototypes[name]
		if entproto.items_to_place_this ~= nil then
			signal = {type = "item", name = entproto.items_to_place_this[1].name}
		end
		
		local e = accumulate_examples(game.players[event.player_index], name)
		for _, v in ipairs(e) do
			game.players[event.player_index].add_custom_alert(v, signal, {"item-name."..name}, true)
		end
	end	
end)
script.on_event(defines.events.on_tick, function(event)
    if event.tick % (60*settings.global["ghost-count-refresh"].value) == 0  then
        for index,player in pairs(game.players) do
			if player.gui.left.gcFrame~=nil then
				updateGUI(player)
			end
        end
    end
end)
script.on_init(function()
	for _,player in pairs(game.players) do
        init_gui(player)
    end
end)