; basic program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000
; PORTB flips between $55 and $AA
; PORTA counts up from 0 using X register

  .org $8000

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

  .org $fffa
  .word $0000
  .word reset ; reset vector
  .word $0000


; vim: syntax=asm6502
