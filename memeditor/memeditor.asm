
include '../lib/constants.inc'
include '../lib/macros.inc'

include 'header.asm'
include '../lib/text.asm'

OPEN_BUS_VALUE_HEX = 0xADDEADDE
OPEN_BUS_VALUE_ASCII = 0x44414544

; Variables (offset in IWRAM)
lastKeys = 0
viewer_address = 4
write_menu_size = 8
write_menu_value = 12
write_menu_address = 16

main:
	; r1 = usually palette number to draw with
	; r2 = usually some form of X position
	; r3 = usually some form of Y position
	; r8 = current address (specific meaning changes depending on state)
	; r9 = state
	; r10 = pointer to IWRAM
	; r11 = pointer to VRAM
	; r12 = pointer to I/O
	load_word r12, (MEM_IO + 0xFF)

	mov r0, 0
	str r0, [r10, lastKeys]
	str r0, [r10, viewer_address]
	str r0, [r10, write_menu_size]
	str r0, [r10, write_menu_value]
	str r0, [r10, write_menu_address]

	; Setup display registers
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
	load_word r8, 0x8000000
	mov r9, 0
	mov r10, MEM_IWRAM

	forever:
		.vblank_wait:
			read_io r0, VCOUNT
			cmp r0, 160
			bne .vblank_wait

		mov r0, r9, lsr 1
		cmp r0, 2
		bleq write_menu
		mov r0, r9, lsr 1
		cmp r0, 1
		bleq jump_menu
		mov r0, r9, lsr 1
		cmp r0, 0
		bne forever
		cmp r9, 1
		bleq ascii_viewer
		cmp r9, 0
		bleq hex_viewer

		b forever

check_keys:
	stmdb r13!, {r1, lr}

	read_io r0, KEYINPUT
	mvn r0, r0
	ldr r1, [r10, lastKeys]
	str r0, [r10, lastKeys]
	bic r0, r1

	ldmia r13!, {r1, lr}
	bx lr

enter_viewer:
	stmdb r13!, {lr}

	ldr r8, [r10, viewer_address]
	bl clear_screen
	and r9, 1

	ldmia r13!, {lr}
	bx lr

hex_viewer:
	stmdb r13!, {r8, lr}

	mov r11, MEM_VRAM
	mov r1, 0

	; Row 1
	load_word r0, hex_viewer_top_line
	bl print_str

	; Row 2
	next_line 1
	mov r0, GLYPH_LINE_VERTICAL
	bl print_char
	mov r0, '0'
	bl print_char
	mov r0, 'x'
	bl print_char
	mov r0, r8, lsr 24
	bl print_hex
	mov r0, r8, lsr 16
	bl print_hex
	mov r0, 'x'
	bl print_char
	mov r0, 'x'
	bl print_char
	mov r0, 'x'
	bl print_char
	mov r0, 'x'
	bl print_char
	mov r0, GLYPH_LINE_VERTICAL
	bl print_char

	add r11, 12
	load_word r0, hex_viewer_name
	bl print_str

	; Row 3
	next_line 1
	mov r0, GLYPH_T_UP
	bl print_char

	mov r0, GLYPH_LINE_HORIZONTAL
	mov r4, 29
	.row3_loop:
		bl print_char
		subs r4, 1
		bne .row3_loop

	mov r0, GLYPH_T_UP
	mov r2, 11
	mov r3, 2
	bl print_char_xy
	mov r2, 18
	bl print_char_xy
	mov r2, 29
	bl print_char_xy

	; Row 4
	next_line 1
	add r11, 14
	mov r2, 0
	.row4_loop:
		mov r0, '+'
		bl print_char
		mov r0, '0'
		add r0, r2
		bl print_char
		add r11, 2

		add r2, 1
		cmp r2, 8
		bne .row4_loop

	; Everything else
	mov r3, 4
	.y_loop:
		next_line 1

		; Print row address
		mov r0, r8, lsr 8
		bl print_hex
		and r0, r8, 0xF8
		bl print_hex
		mov r0, ':'
		bl print_char
		add r11, 4

		; Print bytes
		mov r1, 1
		mov r2, 8
		.x_loop:
			ldrb r0, [r8], 1
			b ($ + 12)
			dw OPEN_BUS_VALUE_HEX
			dw OPEN_BUS_VALUE_HEX
			bl print_hex
			add r11, 2

			subs r2, 1
			bne .x_loop
		mov r1, 0

		add r3, 1
		cmp r3, 20
		bne .y_loop
	ldmia r13!, {r8}

	; Read keypad
	bl check_keys
	teq r0, GBA_A
	beq .a_press
	teq r0, GBA_START
	beq .start_press
	teq r0, GBA_UP
	beq .up_press
	teq r0, GBA_DOWN
	beq .down_press
	teq r0, GBA_R
	beq .r_press
	teq r0, GBA_L
	beq .l_press
	b .next

	.a_press:
		str r8, [r10, viewer_address]
		bl enter_write_menu
		b .next
	.start_press:
		mov r6, 0
		mov r7, 0
		str r8, [r10, viewer_address]
		mov r9, 2
		b .next
	.up_press:
		sub r8, 8
		b .next
	.down_press:
		add r8, 8
		b .next
	.r_press:
	.l_press:
		bl clear_screen
		mov r9, 1
		b .next

	.next:
	ldmia r13!, {lr}
	bx lr

ascii_viewer:
	stmdb r13!, {r8, lr}

	mov r11, MEM_VRAM
	mov r1, 0

	; Row 1
	add r11, 32
	load_word r0, ascii_viewer_top_line
	bl print_str

	; Row 2
	next_line 1
	add r11, 32
	load_word r0, ascii_viewer_name
	bl print_str

	; Row 3
	next_line 1

	mov r0, GLYPH_LINE_HORIZONTAL
	mov r4, 29
	.row3_loop:
		bl print_char
		subs r4, 1
		bne .row3_loop

	mov r0, GLYPH_T_UP
	mov r3, 2
	mov r2, 16
	bl print_char_xy
	mov r2, 29
	bl print_char_xy

	; Row 4
	next_line 1
	add r11, 20
	mov r0, '+'
	bl print_char
	load_word r5, hex_chars
	.row4_loop:
		ldrb r0, [r5], 1
		bl print_char

		cmp r0, 'F'
		bne .row4_loop

	; Everything else
	mov r3, 4
	.y_loop:
		next_line 1

		; Print row address
		mov r0, r8, lsr 24
		bl print_hex
		mov r0, r8, lsr 16
		bl print_hex
		mov r0, r8, lsr 8
		bl print_hex
		and r0, r8, 0xF0
		bl print_hex
		sub r11, 2
		mov r0, 'x'
		bl print_char
		mov r0, ':'
		bl print_char
		add r11, 4

		; Print bytes
		mov r1, 1
		mov r2, 16
		.x_loop:
			ldrb r0, [r8], 1
			b ($ + 12)
			dw OPEN_BUS_VALUE_ASCII
			dw OPEN_BUS_VALUE_ASCII
			cmp r0, 20
			movlt r0, '.'
			cmp r0, 126
			movgt r0, '.'
			bl print_char

			subs r2, 1
			bne .x_loop
		mov r1, 0

		add r3, 1
		cmp r3, 20
		bne .y_loop
	ldmia r13!, {r8}

	; Read keypad
	bl check_keys
	teq r0, GBA_A
	beq .a_press
	teq r0, GBA_START
	beq .start_press
	teq r0, GBA_UP
	beq .up_press
	teq r0, GBA_DOWN
	beq .down_press
	teq r0, GBA_R
	beq .r_press
	teq r0, GBA_L
	beq .l_press
	b .next

	.a_press:
		str r8, [r10, viewer_address]
		bl enter_write_menu
		b .next
	.start_press:
		mov r6, 0
		mov r7, 0
		str r8, [r10, viewer_address]
		mov r9, 3
		b .next
	.up_press:
		sub r8, 16
		b .next
	.down_press:
		add r8, 16
		b .next
	.r_press:
	.l_press:
		bl clear_screen
		mov r9, 0
		b .next

	.next:
	ldmia r13!, {lr}
	bx lr

jump_menu:
	stmdb r13!, {lr}
	; r6 = highlighted digit
	; r7 = highlighted button

	; Row 1
	mov r1, 0
	mov r0, GLYPH_BEND_DOWN_RIGHT
	mov r2, 7
	mov r3, 4
	set_curs r2, r3
	bl print_char

	mov r0, GLYPH_LINE_HORIZONTAL
	mov r4, 15
	.row1_loop:
		bl print_char
		subs r4, 1
		bne .row1_loop

	mov r0, GLYPH_BEND_DOWN_LEFT
	bl print_char

	; Row 2
	load_word r0, jump_menu_name
	add r3, 1
	set_curs r2, r3
	bl print_str

	; Row 3
	mov r0, GLYPH_T_RIGHT
	add r3, 1
	set_curs r2, r3
	bl print_char

	mov r0, GLYPH_LINE_HORIZONTAL
	mov r4, 15
	.row3_loop:
		bl print_char
		subs r4, 1
		bne .row3_loop

	mov r0, GLYPH_T_LEFT
	bl print_char

	; Row 4
	load_word r0, jump_menu_prefix
	add r3, 1
	set_curs r2, r3
	bl print_str

	mov r0, r8, lsr 24
	bl print_hex
	mov r0, r8, lsr 16
	bl print_hex
	mov r0, r8, lsr 8
	bl print_hex
	mov r0, r8
	bl print_hex

	mov r0, ' '
	bl print_char
	bl print_char
	bl print_char
	mov r0, GLYPH_LINE_VERTICAL
	bl print_char

	; Highlight digit
	load_word r11, MEM_VRAM + (7 shl 6) + (12 shl 1)
	add r11, r6, lsl 1
	ldrh r0, [r11]
	orr r0, 0x0100
	strh r0, [r11, 1]

	; Row 5
	mov r0, GLYPH_T_RIGHT
	add r3, 1
	set_curs r2, r3
	bl print_char

	mov r0, GLYPH_LINE_HORIZONTAL
	mov r4, 15
	.row5_loop:
		bl print_char
		subs r4, 1
		bne .row5_loop

	mov r0, GLYPH_T_LEFT
	bl print_char

	; Row 6
	load_word r0, jump_menu_empty_row
	add r3, 1
	set_curs r2, r3
	bl print_str

	; Buttons
	mov r0, GLYPH_LINE_VERTICAL
	add r3, 1
	set_curs r2, r3
	bl print_char
	mov r0, ' '
	bl print_char
	bl print_char

	mov r4, 0
	load_word r5, hex_chars
	.button_loop:
		ldrb r0, [r5, r4]
		bl print_char
		mov r0, ' '
		bl print_char
		bl print_char

		add r4, 1
		tst r4, 3
		bne .button_loop

		mov r0, ' '
		bl print_char
		mov r0, GLYPH_LINE_VERTICAL
		bl print_char
		load_word r0, jump_menu_empty_row
		add r3, 1
		set_curs r2, r3
		bl print_str
		mov r0, GLYPH_LINE_VERTICAL
		add r3, 1
		set_curs r2, r3
		bl print_char
		mov r0, ' '
		bl print_char
		bl print_char

		cmp r4, 16
		bne .button_loop

	; Bottom row
	sub r11, 6
	mov r0, GLYPH_BEND_UP_RIGHT
	bl print_char

	mov r0, GLYPH_LINE_HORIZONTAL
	mov r4, 15
	.bottom_loop:
		bl print_char
		subs r4, 1
		bne .bottom_loop

	mov r0, GLYPH_BEND_UP_LEFT
	bl print_char

	; Highlight button
	and r2, r7, 0x3
	add r2, r2, lsl 1
	add r2, 10
	mov r3, r7, lsr 2
	mov r3, r3, lsl 1
	add r3, 10
	set_curs r2, r3
	ldrh r0, [r11]
	orr r0, 0x0100
	strh r0, [r11, 1]

	; Key input
	bl check_keys
	teq r0, GBA_A
	beq .a_press
	teq r0, GBA_B
	beq .b_press
	teq r0, GBA_START
	beq .start_press
	teq r0, GBA_RIGHT
	beq .right_press
	teq r0, GBA_LEFT
	beq .left_press
	teq r0, GBA_UP
	beq .up_press
	teq r0, GBA_DOWN
	beq .down_press
	teq r0, GBA_R
	beq .r_press
	teq r0, GBA_L
	beq .l_press
	b .next

	.a_press:
		; Modify current digit
		mov r0, r6, lsl 2
		add r0, 4
		mov r1, 0xF
		bic r8, r1, ror r0
		orr r8, r7, ror r0

		; Move to next digit
		add r6, 1
		and r6, 7
		b .next
	.b_press:
		bl enter_viewer
		b .next
	.start_press:
		str r8, [r10, viewer_address]
		bl enter_viewer
		b .next
	.right_press:
		add r7, 1
		and r7, 0xF
		b .next
	.left_press:
		sub r7, 1
		and r7, 0xF
		b .next
	.up_press:
		sub r7, 4
		and r7, 0xF
		b .next
	.down_press:
		add r7, 4
		and r7, 0xF
		b .next
	.r_press:
		add r6, 1
		and r6, 7
		b .next
	.l_press:
		sub r6, 1
		and r6, 7
		b .next

	.next:
	ldmia r13!, {lr}
	bx lr

enter_write_menu:
	stmdb r13!, {lr}

	mov r6, 0
	mov r7, 0
	bl clear_screen
	and r9, 1
	orr r9, (2 shl 1)

	ldmia r13!, {lr}
	bx lr

write_menu:
	stmdb r13!, {lr}
	; r6 = highlighted field
	; r7 = highlighted button

	mov r11, MEM_VRAM
	mov r1, 0

	; Row 1
	add r11, 24
	load_word r0, write_menu_top_line
	bl print_str

	; Row 2
	next_line 1
	add r11, 24
	load_word r0, write_menu_name
	bl print_str

	; Row 3
	next_line 1
	mov r0, GLYPH_BEND_DOWN_RIGHT
	bl print_char
	mov r0, GLYPH_LINE_HORIZONTAL
	mov r4, 28
	.row3_loop:
		bl print_char
		subs r4, 1
		bne .row3_loop

	mov r0, GLYPH_T_UP
	mov r3, 2
	mov r2, 12
	bl print_char_xy
	mov r0, GLYPH_T_LEFT
	mov r2, 29
	bl print_char_xy

	; Row 4
	next_line 1
	load_word r0, write_menu_line1
	bl print_str

	ldr r8, [r10, write_menu_size]
	cmp r8, 0
	moveq r0, (write_menu_byte_string and 0x000000FF)
	orreq r0, (write_menu_byte_string and 0x0000FF00)
	orreq r0, (write_menu_byte_string and 0x00FF0000)
	orreq r0, (write_menu_byte_string and 0xFF000000)
	cmp r8, 1
	moveq r0, (write_menu_halfword_string and 0x000000FF)
	orreq r0, (write_menu_halfword_string and 0x0000FF00)
	orreq r0, (write_menu_halfword_string and 0x00FF0000)
	orreq r0, (write_menu_halfword_string and 0xFF000000)
	cmp r8, 2
	moveq r0, (write_menu_word_string and 0x000000FF)
	orreq r0, (write_menu_word_string and 0x0000FF00)
	orreq r0, (write_menu_word_string and 0x00FF0000)
	orreq r0, (write_menu_word_string and 0xFF000000)
	add r0, 1
	bl print_str

	cmp r6, 0
	blne .row4_cont
	ldrb r5, [r0, -1]
	sub r11, r5, lsl 1
	.row4_loop1:
		ldrh r0, [r11]
		orr r0, 0x0100
		strh r0, [r11], 2

		subs r5, 1
		bne .row4_loop1

	.row4_cont:
	mov r0, ' '
	bl print_char
	mov r0, '0'
	bl print_char
	mov r0, 'x'
	bl print_char
	ldr r8, [r10, write_menu_value]
	mov r0, r8, lsr 24
	bl print_hex
	mov r0, r8, lsr 16
	bl print_hex
	mov r0, r8, lsr 8
	bl print_hex
	mov r0, r8
	bl print_hex

	mov r0, ' '
	mov r4, 4
	.space_loop:
		bl print_char
		subs r4, 1
		bne .space_loop

	mov r0, r6, lsr 4
	cmp r0, 1
	blne .row5
	sub r11, 24
	and r0, r6, 7
	add r11, r0, lsl 1
	ldrh r0, [r11]
	orr r0, 0x100
	strh r0, [r11]

	; Row 5
	.row5:
	next_line 1
	load_word r0, write_menu_line2
	bl print_str

	ldr r8, [r10, write_menu_address]
	mov r0, r8, lsr 24
	bl print_hex
	mov r0, r8, lsr 16
	bl print_hex
	mov r0, r8, lsr 8
	bl print_hex
	mov r0, r8
	bl print_hex

	mov r0, r6, lsr 4
	cmp r0, 2
	blne .row6
	sub r11, 16
	and r0, r6, 7
	add r11, r0, lsl 1
	ldrh r0, [r11]
	orr r0, 0x100
	strh r0, [r11]

	; Row 6
	.row6:
	mov r0, GLYPH_LINE_VERTICAL
	mov r2, 29
	mov r3, 3
	set_curs r2, r3
	bl print_char
	add r11, (0x40 - 2)
	bl print_char

	next_line 1
	mov r0, GLYPH_BEND_UP_RIGHT
	bl print_char
	mov r0, GLYPH_LINE_HORIZONTAL
	mov r4, 28
	.row5_loop:
		bl print_char
		subs r4, 1
		bne .row5_loop
	mov r0, GLYPH_BEND_UP_LEFT
	bl print_char

	; Size buttons
	cmp r6, 0
	moveq r1, 0
	movne r1, 2
	next_line 2, 3
	load_word r0, write_menu_byte_string
	bl print_str
	cmp r7, 0
	moveq r8, r11
	add r11, 4
	load_word r0, write_menu_halfword_string
	bl print_str
	cmp r7, 1
	moveq r8, r11
	add r11, 4
	load_word r0, write_menu_word_string
	bl print_str
	cmp r7, 2
	moveq r8, r11

	cmp r6, 0
	bne .hex_buttons
	cmp r7, 0
	moveq r0, (write_menu_byte_string and 0x000000FF)
	orreq r0, (write_menu_byte_string and 0x0000FF00)
	orreq r0, (write_menu_byte_string and 0x00FF0000)
	orreq r0, (write_menu_byte_string and 0xFF000000)
	cmp r7, 1
	moveq r0, (write_menu_halfword_string and 0x000000FF)
	orreq r0, (write_menu_halfword_string and 0x0000FF00)
	orreq r0, (write_menu_halfword_string and 0x00FF0000)
	orreq r0, (write_menu_halfword_string and 0xFF000000)
	cmp r7, 2
	moveq r0, (write_menu_word_string and 0x000000FF)
	orreq r0, (write_menu_word_string and 0x0000FF00)
	orreq r0, (write_menu_word_string and 0x00FF0000)
	orreq r0, (write_menu_word_string and 0xFF000000)
	ldrb r4, [r0]
	sub r11, r8, r4, lsl 1
	.size_button_loop:
		ldrh r0, [r11]
		orr r0, 0x0100
		strh r0, [r11], 2

		subs r4, 1
		bne .size_button_loop

	; Hex buttons
	.hex_buttons:
	cmp r6, 0
	moveq r1, 2
	movne r1, 0
	mov r2, 10
	mov r3, 9
	set_curs r2, r3
	mov r4, 0
	load_word r5, hex_chars
	.button_loop:
		ldrb r0, [r5, r4]
		bl print_char
		add r11, 4

		add r4, 1
		tst r4, 3
		bne .button_loop
		next_line 3, 10

		cmp r4, 16
		bne .button_loop

	cmp r6, 0
	beq .key_input
	and r0, r7, 3
	add r2, r0, lsl 1
	add r2, r0
	and r0, r7, 0xC
	add r3, r0, lsr 1
	add r3, r0, lsr 2
	set_curs r2, r3
	ldrh r0, [r11]
	orr r0, 0x0100
	strh r0, [r11]

	; Key input
	.key_input:
	bl check_keys
	teq r0, GBA_A
	beq .a_press
	teq r0, GBA_B
	beq .b_press
	teq r0, GBA_START
	beq .start_press
	teq r0, GBA_RIGHT
	beq .right_press
	teq r0, GBA_LEFT
	beq .left_press
	teq r0, GBA_UP
	beq .up_press
	teq r0, GBA_DOWN
	beq .down_press
	teq r0, GBA_R
	beq .r_press
	teq r0, GBA_L
	beq .l_press
	b .next

	.a_press:
		cmp r6, 0
		streq r7, [r10, write_menu_size]
		moveq r6, 0x10
		beq .next

		mov r0, r6, lsr 4
		cmp r0, 1
		ldreq r8, [r10, write_menu_value]
		ldrne r8, [r10, write_menu_address]

		; Modify current digit
		and r0, r6, 7
		mov r0, r0, lsl 2
		add r0, 4
		mov r1, 0xF
		bic r8, r1, ror r0
		orr r8, r7, ror r0

		mov r0, r6, lsr 4
		cmp r0, 1
		streq r8, [r10, write_menu_value]
		strne r8, [r10, write_menu_address]

		; Move to next digit
		b .r_press
	.b_press:
		bl enter_viewer
		b .next
	.start_press:
		ldr r1, [r10, write_menu_size]
		ldr r8, [r10, write_menu_address]
		ldr r0, [r10, write_menu_value]

		cmp r1, 0
		streqb r0, [r8]
		cmp r1, 1
		streqh r0, [r8]
		cmp r1, 2
		streq r0, [r8]

		bl enter_viewer
		b .next
	.right_press:
		add r7, 1
		and r7, 0xF

		; Size selection gets trimmed
		cmp r6, 0
		bne .next
		cmp r7, 2
		movgt r7, 0
		b .next
	.left_press:
		sub r7, 1
		and r7, 0xF

		; Size selection gets trimmed
		cmp r6, 0
		bne .next
		cmp r7, 2
		movgt r7, 2
		b .next
	.up_press:
		cmp r6, 0
		beq .next
		sub r7, 4
		and r7, 0xF
		b .next
	.down_press:
		cmp r6, 0
		beq .next
		add r7, 4
		and r7, 0xF
		b .next
	.r_press:
		; Moving from size selection
		cmp r6, 0
		moveq r6, 0x10
		moveq r7, 0
		beq .next

		; Change nibble
		and r0, r6, 7
		add r0, 1
		ands r0, 7
		bic r6, 7
		orr r6, r0
		bne .next

		; Change field if overflow
		cmp r6, 0x10
		moveq r6, 0x20
		movne r6, 0x00
		movne r7, 0
		b .next
	.l_press:
		; Moving from size selection
		cmp r6, 0
		moveq r6, 0x27
		moveq r7, 0
		beq .next

		; Change nibble
		ands r0, r6, 7
		sub r0, 1
		and r0, 7
		bic r6, 7
		orr r6, r0
		bne .next

		; Change field if overflow
		cmp r6, 0x27
		moveq r6, 0x17
		movne r6, 0x00
		movne r7, 0
		b .next

	.next:
	ldmia r13!, {lr}
	bx lr

hex_viewer_name db GLYPH_LINE_VERTICAL, "Hex Viewer", GLYPH_LINE_VERTICAL, 0
hex_viewer_top_line db GLYPH_BEND_DOWN_RIGHT, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_BEND_DOWN_LEFT, "      ", GLYPH_BEND_DOWN_RIGHT, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_BEND_DOWN_LEFT, 0

ascii_viewer_name db GLYPH_LINE_VERTICAL, "ASCII Viewer", GLYPH_LINE_VERTICAL, 0
ascii_viewer_top_line db GLYPH_BEND_DOWN_RIGHT, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_BEND_DOWN_LEFT, 0

jump_menu_name db GLYPH_LINE_VERTICAL, "Jump to Address", GLYPH_LINE_VERTICAL, 0
jump_menu_prefix db GLYPH_LINE_VERTICAL, "  0x", 0
jump_menu_empty_row db GLYPH_LINE_VERTICAL, "               ", GLYPH_LINE_VERTICAL, 0

write_menu_name db GLYPH_LINE_VERTICAL, "Write to Address", GLYPH_LINE_VERTICAL, 0
write_menu_top_line db GLYPH_BEND_DOWN_RIGHT, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_LINE_HORIZONTAL, GLYPH_BEND_DOWN_LEFT, 0
write_menu_line1 db GLYPH_LINE_VERTICAL, "Write ", 0
write_menu_byte_string db 4, "byte", 0
write_menu_halfword_string db 8, "halfword", 0
write_menu_word_string db 4, "word", 0
write_menu_line2 db GLYPH_LINE_VERTICAL, "to address 0x", 0