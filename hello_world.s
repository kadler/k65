; classic "hello world" program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000 and LCD
; attached to port A and B
; prints "Hello, World!" to the LCD display on line 1
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .include header.inc.s

main:
  jsr lcd_clear

  ; X is our string index
  lda #0
  tax
  sta $00

loop:
  lda hello, x
  beq done
  
  jsr lcd_putc
  
  inx
  jmp loop

done:
  jmp done

hello
  .text "Hello, World!"

; vim: syntax=asm6502
