
include '../lib/constants.inc'
include '../lib/macros.inc'

include 'header.asm'
include '../lib/text.asm'

main:
	; r11 = pointer to VRAM
	; r12 = pointer to start of I/O
	mov r12, MEM_IO

	; Setup display registers
	write_io DISPCNT, DISPCNT_DISPLAY_BG0 or DISPCNT_BGMODE0
	write_io BG0CNT, BGCNT_256x256 or BGCNT_SB0 or BGCNT_4BIT or BGCNT_CB2 or BGCNT_PRIORITY0
	write_io BG0HOFS, 0
	write_io BG0VOFS, 0

	; Palette
	mov r11, MEM_PALETTE
	strb r0, [r11]
	mov r0, 0xFF
	strb r0, [r11, 2]

	bl load_glyphs

	mov r11, MEM_VRAM
	mov r0, 't'
	strh r0, [r11], 2
	mov r0, 'e'
	strh r0, [r11], 2
	mov r0, 's'
	strh r0, [r11], 2
	mov r0, 't'
	strh r0, [r11], 2

	mov r1, 0
	load_word r0, message
	bl print_str
	mov r0, '?'
	bl print_char
	mov r0, '&'
	mov r2, 4
	mov r3, 0
	bl print_char_xy
	mov r0, '^'
	mov r2, 7
	mov r3, 2
	bl print_char_xy
	load_word r0, message2
	mov r2, 10
	mov r3, 10
	bl print_str_xy

	loop:
		b loop

message db 0xA, "Hel", 0xA, "lo, world!", 0
message2 db "10, 10", 0
