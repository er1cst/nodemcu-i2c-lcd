-- Instruction:
-- P7   P6   P5   P4   P3    P2  P1  P0
-- DB7  DB6  DB5  DB4  LED-K E   RW  RS
-- for pin function introduction see HD44780U P8

BIT_ENABLE                 = 0x04
BIT_BACKLIGHT_ON           = 0x08
BIT_BACKLIGHT_OFF          = 0x00

BIT_SELECT_INSTRUCTION_REG = 0x00
BIT_SELECT_DATA_REG        = 0x01
BIT_READ_REG               = 0x02
BIT_WRITE_REG              = 0x00

backlight = BIT_BACKLIGHT_OFF

function setCursor(row, col)
	local ddramAddr
	if row == 0 then
		if col > 0x27 then
			ddramAddr = col
		elseif col < 0x27
			--todo
		end
end

function writeMessage()
	--todo
end

function writeString(str)
	-- DDRAM
	setDDRAMAddr(0x00)
	for i=1,#str do
		sendInstruction(1,0,string.byte(str,i))
	end
end

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
setPattern(0, {0x00, 0x00, 0x00, 0x18, 0x14, 0x1c, 0x04, 0x18})
--]]

-- setPattern saves a character pattern into the CGRAM
-- CGRAM address space 0b0000x000 - 0b0000x111 is reserved for custom characters (x means whatever)
-- slot: 0-7, corresponding to 3-5 bits(start from 0) of CGRAM
-- pattern: array with 8 elements, each of which represents 1 line from top to bottom
function setPattern(slot, pattern)
	-- the slot number actually corresponds to the lower 3 bits of the CGRAM address
	local addr = bit.lshift(bit.band(slot, 0x07), 3)
	setCGRAMAddr(addr)
	
	-- write data to data register (DR)
	-- the address counter (AC) will automatically increase by 1 internally
	--  Rs  Rw | DB7 DB6 DB5 DB4 DB3 DB2 DB1 DB0
	--   1   0 | [            DATA             ]
	for i=1,#pattern do
		sendInstruction(BIT_SELECT_DATA_REG, BIT_WRITE_REG, pattern[i])
	end
end

function backlightOn()
	backlight = BIT_BACKLIGHT_ON
	i2c.write(0, BIT_BACKLIGHT_ON)
end

function backlightOff()
	backlight = BIT_BACKLIGHT_OFF
	i2c.write(0, BIT_BACKLIGHT_OFF)
end

---------------- mid level functions ----------------

-- setDDRAMAddr sets DDRAM address
-- address: a byte containing the DDRAM address
function setDDRAMAddr(address)
	-- set CGRAM address
	--  Rs  Rw | DB7 DB6 DB5 DB4 DB3 DB2 DB1 DB0
	--   0   0 |   1 [      DDRAM ADDRESS      ]
	sendInstruction(BIT_SELECT_INSTRUCTION_REG, BIT_WRITE_REG, bit.bor(0x80, address))
end

-- setCGRAMAddr sets CGRAM address
-- address: a byte containing the CGRAM address
function setCGRAMAddr(address)
	-- set CGRAM address
	--  Rs  Rw | DB7 DB6 DB5 DB4 DB3 DB2 DB1 DB0
	--   0   0 |   0   1 [    CGRAM ADDRESS    ]
	sendInstruction(BIT_SELECT_INSTRUCTION_REG, BIT_WRITE_REG, bit.bor(0x40, address))
end

function clearDisplay()
	-- set CGRAM address
	--  Rs  Rw | DB7 DB6 DB5 DB4 DB3 DB2 DB1 DB0
	--   0   0 |   0   0   0   0   0   0   0   1
	sendInstruction(BIT_SELECT_INSTRUCTION_REG, BIT_WRITE_REG, 0x01)
end

---------------- low level functions ----------------

-- performs 4-bit operation to send an instruction. Before using this function,
-- you must invoke initLCD() first, because 
function sendInstruction(rs, rw, data)
	local funcbits = bit.bor(rs, rw, backlight, BIT_ENABLE)
	-- 0xf0 is the mask
	local instruction = funcbits + bit.band(data, 0xf0)

	-- send the 4 most significant bits
	i2c.write(0, instruction)
	i2c.write(0, bit.bxor(instruction, BIT_ENABLE))

	-- send the 4 lease significant bits
	instruction = funcbits + bit.band(bit.lshift(data, 4), 0xf0)
	i2c.write(0, instruction)
	i2c.write(0, bit.bxor(instruction, BIT_ENABLE))
	tmr.delay(37)
end

-- set bits with a pulse on En pin
function setBits(byte)
	i2c.write(0, bit.bor(byte, BIT_ENABLE))
	i2c.write(0, bit.band(byte, 0xfb))
	tmr.delay(40)
end

function initLCD(rows)
	-- 8-bit operation mode begins
	-- see: HD44780U Documentation P46 for 4-bit operation mode initialization
	for i=1,3 do
		setBits(0x30)
		-- wait at least 4.1ms
		tmr.delay(4100)
	end

	-- function set (switch to 4-bit mode)
	setBits(0x20)

	-- 4-bit operation mode begins

	-- turn off backlight
	backlightOff()

	-- function set
	--  Rs  Rw | DB7 DB6 DB5 DB4 DB3 DB2 DB1 DB0
	--   0   0 |   0   0   1  DL   N   F   -   -
	-- DL = 0 (Data Length, 4-bit operation mode)
	-- N  = 1 (2-line mode)
	-- F  = 0 (5*8 dots)
	sendInstruction(BIT_SELECT_INSTRUCTION_REG, BIT_WRITE_REG, 0x28)

	-- display off
	-- D = 0 (display off)
	sendInstruction(BIT_SELECT_INSTRUCTION_REG, BIT_WRITE_REG, 0x08)

	-- display clear
	sendInstruction(BIT_SELECT_INSTRUCTION_REG, BIT_WRITE_REG, 0x01)

	-- entry mode set
	-- I/D = 1 (DDRAM increment by 1)
	-- S   = 0 (accompanies display shift off)
	sendInstruction(BIT_SELECT_INSTRUCTION_REG, BIT_WRITE_REG, 0x06)

	-- display on
	-- D = 1 (display on)
	-- C = 0 (cursor off)
	-- B = 0 (blinking of cursor position off)
	sendInstruction(BIT_SELECT_INSTRUCTION_REG, BIT_WRITE_REG, 0x0c)

	-- home
	sendInstruction(BIT_SELECT_INSTRUCTION_REG, BIT_WRITE_REG, 0x02)
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




setPattern(0, {0x00, 0x02, 0x05, 0x07, 0x05, 0x05, 0x00, 0x00})
setPattern(1, {0x00, 0x00, 0x00, 0x18, 0x14, 0x1c, 0x04, 0x18})

writeString("\000\001")
i2c.stop(0)