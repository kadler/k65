; basic program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000
; PB1 flips between $55 and $AA

  .include header.inc.s

nmi:
irq:
  rti

reset:
  ; set all pins in port B as outputs
  lda #$ff
  sta $6002

loop:
  lda #$55
  sta $6000

  lda #$aa
  sta $6000

  jmp loop

; vim: syntax=asm6502
