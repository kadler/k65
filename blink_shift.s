; basic program for Ben Eater's 6502 computer kit
; Blink example using hardware of 6522 VIA2:
; T1 timer can toggle PB7 when it reaches 0
; SR can be run under T2 control
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .include header.inc.s

nmi:
irq:
  rti

reset:
  ; Set T1 to continuous mode with output toggling of PB7
  ; Also set shift register output to free run under T2 rate
  lda #%11010000
  sta ACR2

  ; Set T1 timer to 1. Toggling takes N+1.5 clock cycles.
  ; At 1.8432MHz, this is about 368KHz for a full cycle
  lda #1
  sta T1CL2
  lda #0
  sta T1CH2

  ; Set T2 timer to 0. Each bit takes N+2 clock cycles.
  ; At 1.8432MHz, this is about 922KHz
  lda #0
  sta T2CL2
  lda #0
  sta T2CH2

  ; Shift some bit patterns
  lda #%10110100
  sta SR2

.loop:
  jmp .loop

; vim: syntax=asm6502
