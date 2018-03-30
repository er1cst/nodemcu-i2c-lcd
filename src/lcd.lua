-- Instruction:
-- P7   P6   P5   P4   P3    P2  P1  P0
-- DB7  DB6  DB5  DB4  LED-K E   RW  RS

enable = 0x04
backlight = 0x08

function writeString(str)
	for i=1,#str do
		sendInstruction(1,0,string.byte(str,i))
	end
end

-- setPattern saves a character pattern into the CGRAM
-- slot: 0-7, corresponding to 3-5 bits(start from 0) of CGRAM
-- pattern: array of bytes
function setPattern(slot, pattern)
	local ins = 0x40 + bit.lshift(bit.band(slot, 0x07), 3)
	-- set CGRAM address
	sendInstruction(0,0, ins)
	-- AC will automatically increase
	for i=1,#pattern do
		sendInstruction(1,0,pattern[i])
	end
	-- DDRAM
	sendInstruction(0,0,0x80)
end

function backlightOn()
	backlight = 0x08
	i2c.write(0,0x08)
end

function backlightOff()
	backlight = 0x00
	i2c.write(0,0x00)
end



---------------- low level functions ----------------

-- send an instruction by 4-bit operation
function sendInstruction(rs, rw, data)
	local fnbit = bit.bor(rs, bit.lshift(rw, 1), backlight, enable)
	local instruction = fnbit + bit.band(data, 0xf0)

	-- send first 4 bits
	i2c.write(0, instruction)
	i2c.write(0, bit.bxor(instruction, enable))

	-- send last 4 bits
	instruction = fnbit + bit.band(bit.lshift(data, 4), 0xf0)
	i2c.write(0, instruction)
	i2c.write(0, bit.bxor(instruction, enable))
	tmr.delay(37)
end

-- set bits with a pulse on En pin
function sendRaw(byte)
	i2c.write(0, bit.bor(byte, enable))
	i2c.write(0, bit.band(byte, 0xfb))
	tmr.delay(40)
end

function initLCD()
	-- see: HD44780U Documentation P46 for 4-bit operation mode initialization
	sendRaw(0x30)
	-- wait at least 4.1ms (delay 5ms here)
	tmr.delay(5000)

	-- again
	sendRaw(0x30)
	tmr.delay(5000)

	-- again
	sendRaw(0x30)
	tmr.delay(5000)

	-- function set (set to 4-bit mode)
	sendRaw(0x20)

	-- 4-bit operation mode begins

	-- turn off backlight
	backlightOff()

	-- function set
	-- DL = 0 (Data Length, 4-bit operation mode)
	-- N  = 1 (2-line mode)
	-- F  = 0 (5*8 dots)
	sendInstruction(0, 0, 0x28)

	-- display off
	-- D = 0 (display off)
	sendInstruction(0, 0, 0x08)

	-- display clear
	sendInstruction(0, 0, 0x01)

	-- entry mode set
	-- I/D = 1 (DDRAM increment by 1)
	-- S   = 0 (accompanies display shift off)
	sendInstruction(0, 0, 0x06)

	-- display on
	-- D = 1 (display on)
	-- C = 0 (cursor off)
	-- B = 0 (blinking of cursor position off)
	sendInstruction(0, 0, 0x0c)

	-- home
	sendInstruction(0, 0, 0x02)
end

-- set GPIO0 as SDA, GPIO2 as SCL
i2c.setup(0, 3, 4, i2c.SLOW)

addr = 0x27

i2c.start(0)
i2c.address(0, addr, i2c.TRANSMITTER)
initLCD()
--[[

--0-- 0x04, 0x0a, 0x0e, 0x0e, 0x1f, 0x1f, 0x0e, 0x00
-0-0-
-000-
-000-
00000
00000
-000-
-----

pattern = {0x04, 0x0a, 0x0e, 0x0e, 0x1f, 0x1f, 0x0e, 0x00}

--]]

--[[

-----
----- 
-0-0-
00000
00000
-000-
--0--
-----

0x00, 0x00, 0x0a, 0x1f, 0x1f, 0x0e, 0x04, 0x00

--]]


setPattern(0, {0x00, 0x02, 0x05, 0x07, 0x05, 0x05, 0x00, 0x00})
setPattern(1, {0x00, 0x00, 0x00, 0x18, 0x14, 0x1c, 0x04, 0x18})

writeString("\000\001")
i2c.stop(0)