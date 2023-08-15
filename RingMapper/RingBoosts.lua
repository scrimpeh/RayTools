-- Rayman Ringboost Script used for finding the ring heatmap
-- For BizHawk 2.8

-- Adapted from the RingBoost brute forcer initially developed by Got4n
-- The main change is that this script receives an event index as input
-- and will output relative positions

-- Note that there's a significant difference between the origin coordinates of rayman and his actual coordinates on screen
-- This needs to be taken into account when displaying the results

-- Constants
RAYMAN_X = 0x1F61BC
RAYMAN_Y = 0x1F61BE

CAMERA_X = 0x1F84B8
CAMERA_Y = 0x1F84C0

X_SPEED = 0x1F61CC
Y_SPEED = 0x1F61CE

ADDR_OFFSET = 0x80000000
EVENT_SIZE = 112

RAYMAN_STATE = 0x1F61F6
 
function set_xy(x, y)
	-- Get ring position
	local event_mem_start = memory.read_u32_le(0x1D7AE0) - ADDR_OFFSET
	local current_event = event_mem_start + EVENT_SIZE * ring_index
	local ring_x = memory.read_s16_le(current_event + 0x1C)
	local ring_y = memory.read_s16_le(current_event + 0x1E)
	-- Set Rayman Position
	local rayman_x = ring_x + x
	local rayman_y = ring_y + y
	memory.write_u16_le(RAYMAN_X, rayman_x)
	memory.write_u16_le(RAYMAN_Y, rayman_y)
	-- Write Camera
	if x < 0 then
		memory.write_u16_le(CAMERA_X, rayman_x + 50)
	else
		memory.write_u16_le(CAMERA_X, rayman_x - 200)
	end
	memory.write_u16_le(CAMERA_Y, rayman_y - 96)
end

function advance_frames(val)
	for i = 0, val, 1 do
		emu.frameadvance()
	end
end
 
-- Configuration
filename = "temp/ring_map_temp.txt"

frames_to_wait = 1

ring_index = 131

x_min = 512
x_max = 640
y_min = -160
y_max = -84

x_inc = 1
y_inc = 1

-- Preparation

console.clear()
console.log("Starting Rayman Ring Mapper...")

savestate.save("temp/rayman_ringmapper_bruteforcer")
savestate.load("temp/rayman_ringmapper_bruteforcer")
 
emu.limitframerate(false)

-- Main Loop
file = io.open(filename, "a")

for x = x_min, x_max, x_inc do
	for y = y_min, y_max, y_inc do 
		savestate.load("temp/rayman_ringmapper_bruteforcer") 
		set_xy(x, y)
		advance_frames(frames_to_wait)

		if memory.read_u8(RAYMAN_STATE) == 7 then
			xs = memory.read_s16_le(X_SPEED)
			ys = memory.read_s16_le(Y_SPEED)
			file:write(string.format("%d,%d,%d,%d\n", x, y, xs, ys))
		end

		emu.yield()
	end
end

file:close()

console.log("Done")
emu.limitframerate(true)