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
  jsr sendcmd
  jsr sendcmd
  jsr sendcmd

  ; set up 2-line mode
  lda #$3C
  jsr sendcmd

  ; clear the display
  lda #$01
  jsr sendcmd

  ; move the cursor home
  lda #$02
  jsr sendcmd

  ; set display and cursor on, and blink cursor
  lda #$0f
  jsr sendcmd

  ; X is our string index
  lda #0
  tax
  sta $00

loop:
  lda hello, x
  cmp #$00
  beq done
  
  jsr senddata
  
  inx
  jmp loop

done:
  jmp done

senddata:
  sta PORTB
  lda #$A0  ; CLK=1, R/W=0 (W), RS=1 (DATA)
  sta PORTA
  lda #$00  ; CLK=0, R/W=0 (W), RS=0 (CMD)
  sta PORTA
  rts

sendcmd:
  sta PORTB
  lda #$80  ; CLK=1, R/W=0(W), RS=0 (CMD)
  sta PORTA
  lda #$00  ; CLK=0, R/W=0(W), RS=0 (CMD)
  sta PORTA
  rts

hello
  .text "Hello, World!"

  .org $fffa
  .word $0000
  .word reset ; reset vector
  .word $0000


; vim: syntax=asm6502
