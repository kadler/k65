; basic program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000 and LCD
; attached to port A and B
; displays all the ASCII printable characters,
; from $20 - $7e, but starting at 'A' (65)
; SPDX-License-Identifier: GPL-3.0-or-later

PORTB    = $6000
PORTA    = $6001
PORTBDIR = $6002
PORTADIR = $6003

  .org $8000

reset:
  ; set all pins in port B as outputs
  ; set all pins in port A as outputs
  lda #$ff
  sta PORTBDIR
  sta PORTADIR

  ; ensure we're in 8-bit mode
  ; https://en.wikipedia.org/wiki/Hitachi_HD44780_LCD_controller#Mode_Selection
  lda #$30
  jsr lcd_cmd
  jsr lcd_cmd
  jsr lcd_cmd

  ; set up 2-line mode
  lda #$3C
  jsr lcd_cmd

  ; clear the display
  lda #$01
  jsr lcd_cmd

  ; move the cursor home
  lda #$02
  jsr lcd_cmd

  ; set display and cursor on, and blink cursor
  lda #$0f
  jsr lcd_cmd

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
  jsr lcd_data
  
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

  ; include LCD routines
  .include lcd.inc.s

  .org $fffa
  .word $0000
  .word reset ; reset vector
  .word $0000


; vim: syntax=asm6502
