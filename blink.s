; basic program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000
; Blink pin 1 on PA1 at ~1Hz

  .include registers.inc.s

  .org $8000

reset:
  ; set all pins in port A as outputs
  lda #$ff
  sta DDRA1

loop:
  lda #1
  sta PA1

  lda #250
  jsr delayms
  jsr delayms

  lda #0
  sta PA1

  lda #250
  jsr delayms
  jsr delayms

  jmp loop

  .include delay.inc.s

  .org $fffa
  .word $0000
  .word reset ; reset vector
  .word $0000


; vim: syntax=asm6502
