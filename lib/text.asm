
macro next_line num, xOffset {
	bic r11, 0x3F ; Beginning of line
	if xOffset eq
		add r11, (0x40 * num)
	else
		add r11, ((0x40 * num) + (xOffset * 2))
	end if
}

macro set_curs x, y {
	mov r11, MEM_VRAM
	add r11, y, lsl 6
	add r11, x, lsl 1
}

; Uses CpuFastSet to quickly clear screenblock 0 without touching DMA
clear_screen:
	stmdb r13!, {r0, r1, r2, lr}

	; Use stack to put known 0 value as source address
	mov r0, 0
	stmdb r13!, {r0}
	mov r0, r13

	mov r1, MEM_VRAM
	mov r2, (0x800 / 4)
	orr r2, (1 shl 24)
	swi CpuFastSet

	add r13, 4
	ldmia r13!, {r0, r1, r2, lr}
	bx lr

; Parameters:
; r0 = Character to print
; r1 = Palette number
; r11 = Pointer to location in VRAM character should be printed
;
; Return Values:
; r11 = VRAM location after new text
print_char:
	stmdb r13!, {r0, lr}

	; Print character
	orr r0, r1, lsl 12 ; Add palette
	strh r0, [r11], 2

	ldmia r13!, {r0, lr}
	bx lr

; Parameters:
; r0 = byte to print
; r1 = Palette number
; r11 = Pointer to location in VRAM characters should be printed
;
; Return Values:
; r11 = VRAM location after new text
print_hex:
	stmdb r13!, {r4, r5, lr}

	; Get top nibble
	load_word r5, hex_chars
	and r4, r0, 0xF0
	ldrb r4, [r5, r4, lsr 4]
	; Print character
	orr r4, r1, lsl 12 ; Add palette
	strh r4, [r11], 2

	; Get bottom nibble
	and r4, r0, 0xF
	ldrb r4, [r5, r4]
	; Print character
	orr r4, r1, lsl 12 ; Add palette
	strh r4, [r11], 2

	ldmia r13!, {r4, r5, lr}
	bx lr

; Parameters:
; r0 = byte to print
; r1 = Palette number
; r11 = Pointer to location in VRAM characters should be printed
;
; Return Values:
; r11 = VRAM location after new text
print_hex_halfword:
	stmdb r13!, {r0, r1, lr}

	mov r1, r0
	mov r0, r1, lsr 8
	bl print_hex
	mov r0, r1
	bl print_hex

	ldmia r13!, {r0, r1, lr}
	bx lr

; Parameters:
; r0 = byte to print
; r1 = Palette number
; r11 = Pointer to location in VRAM characters should be printed
;
; Return Values:
; r11 = VRAM location after new text
print_hex_word:
	stmdb r13!, {r0, r1, lr}

	mov r1, r0
	mov r0, r1, lsr 24
	bl print_hex
	mov r0, r1, lsr 16
	bl print_hex
	mov r0, r1, lsr 8
	bl print_hex
	mov r0, r1
	bl print_hex

	ldmia r13!, {r0, r1, lr}
	bx lr

; Parameters:
; r0 = pointer to string
; r1 = palette number
; r11 = pointer to location in VRAM where printing should start
;
; Return Values:
; r11 = VRAM location after new text
print_str:
	stmdb r13!, {r0, r4, lr}

	.loop:
		ldrb r4, [r0], 1

		; Check for NULL
		cmp r4, 0 
		beq .end

		; Check for newline
		cmp r4, 0xA
		biceq r11, 0x3F ; Beginning of line
		addeq r11, 0x40 ; Next line
		beq .loop

		; Print character
		orr r4, r1, lsl 12 ; Add palette
		strh r4, [r11], 2
		b .loop

	.end:
	ldmia r13!, {r0, r4, lr}
	bx lr

; Parameters:
; r0 = Character to print
; r1 = Palette number
; r2 = start X coordinate
; r3 = start Y coordinate
; r11 = Pointer to location in VRAM character should be printed
;
; Return Values:
; r2 = end X coordinate
; r3 = end Y coordinate
; r11 = VRAM location after new text
print_char_xy:
	stmdb r13!, {r0, lr}

	; Convert coordinates to memory location
	mov r11, MEM_VRAM
	add r11, r3, lsl 6
	add r11, r2, lsl 1

	; Check for newline
	cmp r0, 0xA
	bne .next
	next_line 1
	mov r2, 0
	add r3, 1
	b .end

	; Print character
	.next:
	orr r0, r1, lsl 12 ; Add palette
	strh r0, [r11], 2
	add r2, 1
	ands r2, 31
	addeq r3, 1

	.end:
	ldmia r13!, {r0, lr}
	bx lr

; Parameters:
; r0 = pointer to string
; r1 = palette number
; r2 = start X coordinate
; r3 = start Y coordinate
;
; Return Values:
; r2 = end X coordinate
; r3 = end Y coordinate
; r11 = VRAM location after new text
print_str_xy:
	stmdb r13!, {r0, r4, lr}

	; Convert coordinates to memory location
	mov r11, MEM_VRAM
	add r11, r3, lsl 6
	add r11, r2, lsl 1

	.loop:
		ldrb r4, [r0], 1

		; Check for NULL
		cmp r4, 0 
		beq .end

		; Check for newline
		cmp r4, 0xA
		bne .next
		next_line 1
		mov r2, 0
		add r3, 1
		beq .loop

		; Print character
		.next:
		orr r4, r1, lsl 12 ; Add palette
		strh r4, [r11], 2
		add r2, 1
		ands r2, 31
		addeq r3, 1
		b .loop

	.end:
	ldmia r13!, {r0, r4, lr}
	bx lr

; Stupid BitUnPack reverses the characters so I need this if I don't want to set the horizontol flip bit everywhere
load_glyphs:
	load_word r10, glyphs
	load_word r11, MEM_VRAM + 0x8000 ; Start of charblock 2

	load_word r0, 139 * 8
	.loop:
		ldrb r1, [r10], 1

		; Unpack 1 bit data (r0) to 4 bits (r3)
		and r2, r1, 0x01
		mov r3, r2, lsl (28 - 0)
		and r2, r1, 0x02
		orr r3, r2, lsl (24 - 1)
		and r2, r1, 0x04
		orr r3, r2, lsl (20 - 2)
		and r2, r1, 0x08
		orr r3, r2, lsl (16 - 3)
		and r2, r1, 0x10
		orr r3, r2, lsl (12 - 4)
		and r2, r1, 0x20
		orr r3, r2, lsl (8 - 5)
		and r2, r1, 0x40
		orr r3, r2, lsr (6 - 4)
		and r2, r1, 0x80
		orr r3, r2, lsr (7 - 0)

		str r3, [r11], 4

		subs r0, 1
		bne .loop

	bx lr

load_glyphs_inverted:
	load_word r10, glyphs
	load_word r11, MEM_VRAM + 0x8000 + 0x2000; Start of charblock 2

	load_word r0, 139 * 8
	.loop:
		ldrb r1, [r10], 1

		; Unpack 1 bit data (r0) to 4 bits (r3)
		load_word r3, 0x11111111
		and r2, r1, 0x01
		bic r3, r2, lsl (28 - 0)
		and r2, r1, 0x02
		bic r3, r2, lsl (24 - 1)
		and r2, r1, 0x04
		bic r3, r2, lsl (20 - 2)
		and r2, r1, 0x08
		bic r3, r2, lsl (16 - 3)
		and r2, r1, 0x10
		bic r3, r2, lsl (12 - 4)
		and r2, r1, 0x20
		bic r3, r2, lsl (8 - 5)
		and r2, r1, 0x40
		bic r3, r2, lsr (6 - 4)
		and r2, r1, 0x80
		bic r3, r2, lsr (7 - 0)

		str r3, [r11], 4

		subs r0, 1
		bne .loop

	bx lr

hex_chars: db '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'

include 'glyphs.asm'