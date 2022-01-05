
include '../lib/constants.inc'
include '../lib/macros.inc'

include 'header.asm'
include '../lib/text.asm'

main:
	; r9 = scroll
	; r10 = last pressed keys
	; r11 = pointer to VRAM
	; r12 = pointer to I/O
	load_word r12, MEM_IO + IO_OFFSET

	; Display registers
	write_io DISPCNT, DISPCNT_DISPLAY_BG0 or DISPCNT_BGMODE0
	write_io BG0CNT, BGCNT_256x256 or BGCNT_SB0 or BGCNT_4BIT or BGCNT_CB2 or BGCNT_PRIORITY0
	write_io BG0HOFS, 0
	write_io BG0VOFS, 0

	; Palette
	mov r11, MEM_PALETTE
	mov r0, 0 ; Black
	strh r0, [r11]
	strh r0, [r11, 32]
	strh r0, [r11, 64]
	strh r0, [r11, 96]
	mov r0, 0xFF ; White
	strb r0, [r11, 2]
	load_word r0, 0x5EF7 ; Light Gray
	strh r0, [r11, 34]
	load_word r0, 0x3DEF ; Gray
	strh r0, [r11, 66]
	load_word r0, 0x1CE7 ; Dark Gray
	strh r0, [r11, 98]

	bl load_glyphs
	bl load_glyphs_inverted
	mov r1, 0
	mov r9, 0
	mov r10, 0
	mov r11, MEM_VRAM

	load_word r0, sad_message
	bl print_str
	load_word r0, 0x8000100
	bl print_hex_word
	write_io_word DMA0SAD, 0x8000100
	write_io_word DMA1SAD, 0x8000100
	write_io_word DMA2SAD, 0x8000100
	write_io_word DMA3SAD, 0x8000100

	load_word r0, dad_message
	bl print_str
	mov r0, 0x2000000
	bl print_hex_word
	write_io_word DMA0DAD, 0x2000000
	write_io_word DMA1DAD, 0x2000000
	write_io_word DMA2DAD, 0x2000000
	write_io_word DMA3DAD, 0x2000000

	load_word r0, length_message
	bl print_str
	mov r0, 0x0020
	bl print_hex_halfword
	write_io DMA0CNT_L, 0x0020
	write_io DMA1CNT_L, 0x0020
	write_io DMA2CNT_L, 0x0020
	write_io DMA3CNT_L, 0x0020

	load_word r0, table_head
	bl print_str
	load_word r4, 0x8000 ; Source increment
	bl try_value
	load_word r4, 0x8080 ; Source decrement
	bl try_value
	load_word r4, 0x8100 ; Source fixed
	bl try_value
	load_word r4, 0x8180 ; This case is marked as "prohibited"
	bl try_value

	forever:
		; Get newly pressed keys
		read_io r0, KEYINPUT
		mvn r0, r0
		mov r8, r10
		mov r10, r0
		bic r0, r8

		teq r0, GBA_UP
		beq .up_press
		teq r0, GBA_DOWN
		beq .down_press
		b .next

		.up_press:
			cmp r9, 0
			subgt r9, 8
			write_io_reg BG0VOFS, r9
			b .next
		.down_press:
			cmp r9, (256 - 160)
			addlt r9, 8
			write_io_reg BG0VOFS, r9

		.next:
		b forever

; r4 = value
try_value:
	stmdb r13!, {lr}

	load_word r0, table_separator
	bl print_str
	mov r5, 0
	bl try_dma
	mov r5, 1
	bl try_dma
	mov r5, 2
	bl try_dma
	mov r5, 3
	bl try_dma

	ldmia r13!, {lr}
	bx lr

; r4 = value
; r5 = channel
try_dma:
	stmdb r13!, {lr}

	; Calculate DMAxCNT_H register for given channel
	; 040000BAh + 0Ch·x 
	load_word r6, DMA0CNT_H
	add r6, r5, lsl 3
	add r6, r5, lsl 2

	; Print everything but result
	load_word r0, dmacnt_name
	bl print_str
	ldrh r0, [r11, -12]
	add r0, r5
	strh r0, [r11, -12]
	mov r0, GLYPH_LINE_VERTICAL
	bl print_char
	mov r0, '0'
	bl print_char
	mov r0, 'x'
	bl print_char
	mov r0, r4
	bl print_hex_halfword
	mov r0, GLYPH_LINE_VERTICAL
	bl print_char
	mov r0, '0'
	bl print_char
	mov r0, 'x'
	bl print_char

	; Get and print result
	strh r4, [r6]
	nop
	nop
	nop
	ldrh r0, [r6]
	bl print_hex_halfword
	next_line 1

	ldmia r13!, {lr}
	bx lr

sad_message db "Source Address: 0x", 0
dad_message db 0xA, "Dest Address: 0x", 0
length_message db 0xA, "Length: 0x", 0
table_head db 0xA, " Register", GLYPH_LINE_VERTICAL, " Wrote", GLYPH_LINE_VERTICAL, "  Read", 0xA, 0
table_separator db GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_CROSS, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_CROSS, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, 0xA, 0

dmacnt_name db "DMA0CNT_H", 0