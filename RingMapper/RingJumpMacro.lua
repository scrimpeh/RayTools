-- Needs RingMapper.lua to be running and a ring to be selected
-- Holds up + jump either on the first frame after grabbing the ring, or until we landed. Prints the x speed on that first frame.
-- For BizHawk 2.9 / PSX Rayman

X_SPEED = 0x1F61CC
RAYMAN_STATE = 0x1F61F6
ID_OBJ_GRAPPED = 0x1F8498

boosting = false
boost_start = nil

rayman_state = nil --7 is on ring, 2 is in the air?
buttons = {["P1 D-Pad Left"]=false, ["P1 D-Pad Right"]=false, ["P1 D-Pad Up"]=true, ["P1 X"]=true}

while true do
    rayman_state = memory.read_u8(RAYMAN_STATE)
    if not boosting and rayman_state == 7 and memory.read_s16_le(ID_OBJ_GRAPPED) == userdata.get("rayman_ringmapper_current_ring") then
        boosting = true
        boost_start = emu.framecount()
    end
    if rayman_state ~= 2 and rayman_state ~= 7 then
        boosting = false
    end
    
    if boosting and emu.framecount()-1 >= boost_start then
        if emu.framecount()-1 == boost_start then
            print(memory.read_s16_le(X_SPEED))
            joypad.set(buttons)
        else
            --joypad.set(buttons)
        end
    end
    emu.frameadvance()
end