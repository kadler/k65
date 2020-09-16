; basic program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000
; Blink pin 1 on PA1 at ~1Hz

  .include header.inc.s

nmi:
irq:
  rti

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



; vim: syntax=asm6502
