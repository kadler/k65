; Converts a 16-bit number to a string and prints it to the LCD
; requires LCD attached to 6522 VIA 1.
;
; SPDX-License-Identifier: GPL-3.0-or-later

value   = $0200
mod10   = $0202
message = $0204

  .include header.inc.s

  .ifdef ROM
nmi:
irq:
  rti
  .endif

reset:
  jsr lcd_init

  ; Initialize message
  lda #0
  sta message

  ; Set up number to be converted
  lda number
  sta value
  lda number + 1
  sta value + 1

divide:
  ; Initialize remainder to 0
  lda #0
  sta mod10
  sta mod10 + 1
  clc

  ldx #16
division_loop:
  ; Rotate quotient and remainder
  rol value
  rol value + 1
  rol mod10
  rol mod10 + 1

  ; a,y = dividend - divisor
  lda mod10
  sec
  sbc #10
  tay
  
  lda mod10 + 1
  sbc #0

  ; branch if dividend < divisor
  bcc ignore_result
  sty mod10
  sta mod10 + 1

ignore_result:
  dex
  bne division_loop

  rol value
  rol value + 1

  lda mod10
  ora #"0"

  ; Push the current character (in a register)
  ; to front of message
  ldy #0
char_loop:
  ldx message,y
  sta message,y
  iny
  txa
  bne char_loop
  sta message,y

  ; Loop until the value is 0
  lda value
  ora value + 1
  bne divide

  ; Print the message
  ldx #0
print:
  lda message,x
  beq done
  jsr lcd_data
  inx
  jmp print

done:
  lda #250
  jsr delayms
  jsr delayms
  jsr delayms
  jsr delayms

  .ifdef ROM
.here:
  jmp .here
  .else
  rts
  .endif

  .include lcd.inc.s
  .include delay.inc.s

number: .word 3742

; vim: syntax=asm6502
