; simple program for Ben Eater's 6502 computer kit
; requires 6522 memory mapped to $6000
; PB1 rotates right from address $00
; PA1 rotates left  from address $01

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

; vim: syntax=asm6502
