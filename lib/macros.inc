
include 'constants.inc'

; Saving myself from my own stupidity
macro endif {
	end if
}

; "Smart" way for loading value into register
macro load_word reg, value {
	if (value)
		if (value) and 0xFF
			mov reg, (value) and 0xFF
		end if
		if (value) and 0xFF00
			if (value) and 0xFF
				orr reg, (value) and 0xFF00
			else
				mov reg, (value) and 0xFF00
			end if
		end if
		if (value) and 0xFF0000
			if (value) and 0xFFFF
				orr reg, (value) and 0xFF0000
			else
				mov reg, (value) and 0xFF0000
			end if
		end if
		if (value) and 0xFF000000
			if (value) and 0xFFFFFF
				orr reg, (value) and 0xFF000000
			else
				mov reg, (value) and 0xFF000000
			end if
		end if
	else
		mov reg, 0
	end if
}

IO_OFFSET = 0xFF

; Assuming r12 = 0x04000000, a slightly more readable way for writing to I/O registers
macro write_io location, value {
	load_word r0, (value)
	strh r0, [r12, (location - (MEM_IO + IO_OFFSET))]
}

macro write_io_reg location, reg {
	strh reg, [r12, (location - (MEM_IO + IO_OFFSET))]
}

macro write_io_word location, value {
	load_word r0, (value)
	str r0, [r12, (location - MEM_IO)]
}

; Same thing for read
macro read_io reg, location {
	ldrh reg, [r12, (location - (MEM_IO + IO_OFFSET))]
}
