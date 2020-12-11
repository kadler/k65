; Prints out the number of interrupts that occured while holding
; the irq line low (eg. through a button)
; requires LCD attached to 6522 VIA 1
;
; SPDX-License-Identifier: GPL-3.0-or-later

value   = $0200
mod10   = $0202
message = $0204
counter = $020a

  .include header.inc.s

reset:
  jsr lcd_init

  lda #0
  sta counter
  sta counter + 1

display_counter:
  ; move cursor home
  lda #$02
  jsr lcd_cmd

  ; Initialize message
  lda #0
  sta message

  ; Set up number to be converted
  sei
  lda counter
  sta value
  lda counter + 1
  sta value + 1
  cli

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
  beq display_counter
  jsr lcd_data
  inx
  jmp print

  .include lcd.inc.s

nmi:
  rti

irq:
  inc counter
  bne exit_irq
  inc counter + 1

exit_irq:
  rti

; vim: syntax=asm6502
