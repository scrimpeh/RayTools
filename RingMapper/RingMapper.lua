-- Ring Heatmap Visualizer
-- For BizHawk 2.9 / PSX Rayman

-- Select a ring in the level and display the ringboost heatmap
-- Adapted in large parts from the Map Viewer script initially developed by fuerchter and markusa4 (https://github.com/fuerchter/RaymanMap)

-- Definitions

BORDER_L = 18
BORDER_R = 13
ADDR_OFFSET = 0x80000000
EVENT_SIZE = 112

HEATMAP_VISALIZER_EXEC_NAME = "RingMapper\\HeatmapVisualizer\\bin\\Debug\\net7.0\\HeatmapVisualizer.exe"

-- Because Rayman's origin is skewed from where he is, apply an offset to both rayman's position and the ring heatmap

RAY_OFFS_X = 80
RAY_OFFS_Y = 52

-- Functions

function draw_mask()
	gui.drawRectangle(-1, 0, BORDER_L, client.bufferheight(), 0x00000000, 0xFF000000)
	gui.drawRectangle(client.bufferwidth() - BORDER_R, 0, BORDER_R, client.bufferheight(), 0x00000000, 0xFF000000)
end

function screen_space(x, y)
	return { 
		x = BORDER_L + x - cam_x, 
		y = y - cam_y 
	}
end

function world_space(x, y)
	return { 
		x = x + cam_x - BORDER_L, 
		y = y + cam_y 
	}
end

function draw_rayman_pos()
	local ray_pos = screen_space(
		memory.read_s16_le(0x1F61BC),
		memory.read_s16_le(0x1F61BE)
	)
	ray_pos.x = ray_pos.x + RAY_OFFS_X
	ray_pos.y = ray_pos.y + RAY_OFFS_Y
	gui.drawLine(ray_pos.x - 2, ray_pos.y, ray_pos.x + 2, ray_pos.y, 0xFFFFFFFF)
	gui.drawLine(ray_pos.x, ray_pos.y - 2, ray_pos.x, ray_pos.y + 2, 0xFFFFFFFF)
end

function get_hitbox(current)
	local current_x = memory.read_s16_le(current + 0x1C)
	local current_y = memory.read_s16_le(current + 0x1E)
	local animation_mem = memory.read_u32_le(current + 4) - ADDR_OFFSET
	local animation_frame  = memory.readbyte(current + 0x54)
	local animation_counter = memory.readbyte(current + 0x55)
	local animation_base = animation_mem + (((animation_frame << 1) + animation_frame) << 2)
	local hitbox_addr = memory.read_u32_le(animation_base + 4) - ADDR_OFFSET + (animation_counter << 2)
	local hitbox_offset_x = memory.readbyte(hitbox_addr)
	local hitbox_offset_y = memory.readbyte(hitbox_addr + 1)
	local width = memory.readbyte(hitbox_addr + 2)
	local height = memory.readbyte(hitbox_addr + 3)
	local flipped = memory.readbyte(current + 0x6D) & 0x40
	local x = current_x + hitbox_offset_x
	if flipped == 0x40 then
		x = current_x + (memory.readbyte(current + 0x52) << 1) - hitbox_offset_x - width
	end
	local y = current_y + hitbox_offset_y

	return { 
		l = x, 
		u = y, 
		r = x + width,
		d = y + height 
	}
end

function hover_ring_info(current, index)
	local current_x = memory.read_s16_le(current + 0x1C)
	local current_y = memory.read_s16_le(current + 0x1E)

	-- Draw info about the current event
	local cur = screen_space(current_x, current_y)
	local cur_screen = client.transformPoint(cur.x, cur.y)
	gui.text(cur_screen.x, cur_screen.y, index, "lightgreen")
	gui.text(cur_screen.x, cur_screen.y + 16, current_x, "lightgreen")
	gui.text(cur_screen.x, cur_screen.y + 32, current_y, "lightgreen")

	gui.drawLine(cur.x - 2, cur.y, cur.x + 2, cur.y, 0xFFFFFFFF)
	gui.drawLine(cur.x, cur.y - 2, cur.x, cur.y + 2, 0xFFFFFFFF)

	-- Does the user mouseover the hitbox?
	local hitbox = get_hitbox(current)
	if hitbox ~= nil then
		local mouse_world = world_space(mouse_x, mouse_y)
		if mouse_world.x >= hitbox.l and mouse_world.x <= hitbox.r and mouse_world.y >= hitbox.u and mouse_world.y <= hitbox.d then
			-- Draw Hitbox
			local hitbox_lu = screen_space(hitbox.l, hitbox.u)
			local hitbox_rd = screen_space(hitbox.r, hitbox.d)
			gui.drawBox(hitbox_lu.x, hitbox_lu.y, hitbox_rd.x, hitbox_rd.y, 0x00000000, 0x40FFFFFF)
			current_hitbox_event = index
		end	
	end
end

function find_ring_mouseover()
	local event_mem_start = memory.read_u32_le(0x1D7AE0) - ADDR_OFFSET
	local event_count = memory.readbyte(0x1D7AE4)
	local current_event = 0x1E5428
	local index = memory.read_s16_le(current_event)
	while index ~= -1 do
		local current = event_mem_start + EVENT_SIZE * index
		local event_type = memory.read_u8(current + 0x63)
		if event_type == 140 then
			hover_ring_info(current, index)
		end

		current_event = current_event + 2
		index = memory.read_s16_le(current_event)
	end
end

function read_mouse()
	local mouse = input.getmouse()
	mouse_x = mouse["X"]
	mouse_y = mouse["Y"]
	mouse_l = mouse["Left"]
	mouse_l_cur = mouse_l
	if mouse_l_last then
		mouse_l_cur = false
	end
	mouse_l_last = mouse_l
end

heatmap_offset = nil

function find_heatmap_offset()
	if heatmap_offset == nil then
		local x_min = 99999
		local y_min = 99999
		for offset, _ in pairs(get_heatmap_table()) do
			x_min = math.min(x_min, offset.x)
			y_min = math.min(y_min, offset.y)
		end
		heatmap_offset = {
			x = x_min,
			y = y_min
		}
	end
	return heatmap_offset
end

function get_heatmap_table()
	if ring_heatmap == nil then
		print("Reading ringboost heatmap...")
		ring_heatmap = {}
		for line in io.lines(heatmap_data) do
			local x, y, xs, ys = line:match("(.+),(.+),(.+),(.+)")
			local offset = {
				x = tonumber(x),
				y = tonumber(y)
			}
			local speed = {
				xs = tonumber(xs),
				ys = tonumber(ys)
			}
			ring_heatmap[offset] = speed
		end
	end
	return ring_heatmap
end

function heatmap_lookup_key(offset)
	return offset.x .. "/" .. offset.y
end

function get_heatmap_lookup()
	if heatmap_lookup == nil then
		heatmap_lookup = {}
		for offset, speed in pairs(get_heatmap_table()) do
			heatmap_lookup[heatmap_lookup_key(offset)] = speed
		end
	end
	return heatmap_lookup
end

function draw_ring_heatmap(ring_index)
	if not ring_index then
		return
	end
	
	local event_mem_start = memory.read_u32_le(0x1D7AE0) - ADDR_OFFSET
	local current_event = event_mem_start + EVENT_SIZE * ring_index
	local ring_x = memory.read_s16_le(current_event + 0x1C)
	local ring_y = memory.read_s16_le(current_event + 0x1E)

	local offset = find_heatmap_offset()
	local screen_pos = screen_space(ring_x + offset.x, ring_y + offset.y)
	gui.drawImage(heatmap_img, screen_pos.x + RAY_OFFS_X, screen_pos.y + RAY_OFFS_Y)

	local mouse_screen = client.transformPoint(mouse_x, mouse_y)
	local mouse_world = world_space(mouse_x, mouse_y)
	local heatmap_lookup = get_heatmap_lookup()
	local mouse_world_offset = {
		 x = mouse_world.x - RAY_OFFS_X - ring_x,
		 y = mouse_world.y - RAY_OFFS_Y - ring_y
	}
	local speed_at_mouse = heatmap_lookup[heatmap_lookup_key(mouse_world_offset)]

	gui.drawLine(mouse_x - 2, mouse_y, mouse_x + 2, mouse_y, "white")
	gui.drawLine(mouse_x, mouse_y - 2, mouse_x, mouse_y + 2, "white")
	gui.drawPixel(mouse_x, mouse_y, "red")
	local heatmap_pos_x
	local heatmap_pos_y
	if show_relative_positions then
		heatmap_pos_x = mouse_world_offset.x
		heatmap_pos_y = mouse_world_offset.y
	else
		heatmap_pos_x = mouse_world.x - RAY_OFFS_X
		heatmap_pos_y = mouse_world.y - RAY_OFFS_Y
	end
	
	if speed_at_mouse ~= nil and math.abs(speed_at_mouse.xs) > 3 then
		gui.text(mouse_screen.x + 12, mouse_screen.y, heatmap_pos_x .. " / " .. heatmap_pos_y .. " -> (" .. speed_at_mouse.xs .. " / " .. speed_at_mouse.ys .. ")", "white")
	else
		gui.text(mouse_screen.x + 12, mouse_screen.y, heatmap_pos_x .. " / " .. heatmap_pos_y, "gray")
	end
end

function file_exists(path)
	local file = io.open(path)
	return file ~= nil and io.close(file)
end

-- Configuration

heatmap_data = "ring_heatmap.csv"
heatmap_img = "ring_heatmap.png"
heatmap_visualizer_args = ""

show_relative_positions = false
regenerate_heatmap = false

-- Start script

console.clear()
console.log("Starting Rayman Ring Heatmap Script...")
gui.clearImageCache()
gui.clearGraphics()
gui.cleartext()
gui.use_surface("emucore")

-- Prepare heatmap

console.log("Preparing heatmap...")

if regenerate_heatmap then
	os.execute(HEATMAP_VISALIZER_EXEC_NAME .. " " .. heatmap_data .. " " .. heatmap_img .. " " .. heatmap_visualizer_args)
end
if not file_exists(heatmap_img) then
	error("File '" .. heatmap_img "' doesn't exist!")
end

-- Prepare Values

if not userdata.containskey("rayman_ringmapper_current_ring") then
	-- Save currently selected ring in userdata so it is synced with your savestate.
	-- I am not sure if this is the best idea, yet.
	userdata.set("rayman_ringmapper_current_ring", nil)
end

while true do
	gui.clearGraphics()
	gui.cleartext()

	current_hitbox_event = nil

	-- Get variables
	read_mouse()

	cam_x = memory.read_u16_le(0x1F84B8)
	cam_y = memory.read_u16_le(0x1F84C0)

	-- Only draw if in a level	
	if memory.readbyte(0x1cee81) == 1 then
		find_ring_mouseover()
		if mouse_l_cur then
			userdata.set("rayman_ringmapper_current_ring", current_hitbox_event)
		end
		draw_ring_heatmap(userdata.get("rayman_ringmapper_current_ring"))
		draw_rayman_pos()
		draw_mask()
	else
		userdata.set("rayman_ringmapper_current_ring", nil)
	end

	emu.yield()
end