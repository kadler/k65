; basic program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000
; PB1 flips between $55 and $AA
; PA1 counts up from 0 using X register

  .include header.inc.s

nmi:
irq:
  rti

reset:
  ; set all pins in port B as outputs
  lda #$ff
  sta $6002

  ; set all pins in port A as outputs
  lda #$ff
  sta $6003

  lda #$00
  tax

loop:
  lda #$55
  sta $6000

  inx
  txa
  sta $6001

  lda #$aa
  sta $6000

  inx
  txa
  sta $6001

  jmp loop

; vim: syntax=asm6502
