; basic program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000 and LCD
; attached to port A and B
; displays all the ASCII printable characters,
; from $20 - $7e, but starting at 'A' (65)
; SPDX-License-Identifier: GPL-3.0-or-later

  .include header.inc.s

nmi:
irq:
  rti

reset:
  jsr lcd_clear

  ; X is our character register
  lda #65 ; start at 'A'
  tax

  ; Y is our cursor register
  lda #$00 ; start at position 0
  tay

loop:
  ; keep cursor on the screen
  ; internally the display has 80 characters,
  ; but the the display has two lines which
  ; are *not* consecutive, so if we get to 16
  ; we move to the next line and if we get to
  ; 32, we move to the first line
  cpy #16
  beq move_line_two

  cpy #32
  beq move_line_one

line_adjusted:
  cpx #$7f
  beq reset_character

display_character:
  ; display the character
  txa
  jsr lcd_putc

  lda #125
  jsr delayms
  
  inx
  iny
  jmp loop

reset_character:
  ; reset index to start ASCII printable characters
  lda #$20
  tax
  jmp display_character

move_line_two:
  ; the cursor is after the last column of the
  ; first line, so move the cursor to the start
  ; of the second line
  lda #$C0
  jsr lcd_cmd

  ; continue display processing
  jmp line_adjusted

move_line_one:
  ; the cursor is after the last column of the
  ; second line, so move cursor home
  lda #$80
  jsr lcd_cmd

  ; reset our cursor position
  lda #$00
  tay

  ; continue display processing
  jmp line_adjusted

  jmp reset

; vim: syntax=asm6502
