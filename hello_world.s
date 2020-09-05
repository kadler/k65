; classic "hello world" program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000 and LCD
; attached to port A and B
; prints "Hello, World!" to the LCD display on line 1
;
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

  ; X is our string index
  lda #0
  tax
  sta $00

loop:
  lda hello, x
  beq done
  
  jsr lcd_data
  
  inx
  jmp loop

done:
  jmp done

  .include lcd.inc.s

hello
  .text "Hello, World!"

  .org $fffa
  .word $0000
  .word reset ; reset vector
  .word $0000


; vim: syntax=asm6502
