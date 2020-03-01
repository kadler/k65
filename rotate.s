; simple program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000
; PORTB rotates right from address $00
; PORTA rotates left  from address $01

  .org $8000

reset:
  ; set all pins in port B as outputs
  lda #$ff
  sta $6002

  ; set all pins in port A as outputs
  lda #$ff
  sta $6003

  lda #$05
  sta $00
  sta $01

loop:
  lda $00
  ror
  sta $6000
  sta $00

  lda $01
  rol
  sta $6001
  sta $01

  jmp loop

  .org $fffa
  .word $0000
  .word reset ; reset vector
  .word $0000


; vim: syntax=asm6502
