  .ifndef DELAY_INC
DELAY_INC = 1

; Delay # of milliseconds in the a register
; Hand optimized for 1.8432MHz clock
delayms:
  pha                ; 3 cycles
  phx                ; 3 cycles
  phy                ; 3 cycles

  tax                ; 2 cycles

.outer:
  ldy #201           ; 2 cycles

.inner:
  dey                ; 2 cycles
  nop                ; 2 cycles
  nop                ; 2 cycles
  bne .inner         ; 3 cycles / 2 at end

  dex                ; 2 cycles
  bne .outer         ; 3 cycles / 2 at end

  ply                ; 4 cycles
  plx                ; 4 cycles
  pla                ; 4 cycles

  rts

delay:
  phx
  tax

.loop:
  lda #250
  jsr delayms
  jsr delayms
  jsr delayms
  jsr delayms

  dex
  bne .loop

  plx
  rts
  .endif
