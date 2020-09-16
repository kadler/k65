; Basic setup for all programs
; If building an EEPROM image, sets up
; reset, nmi, and irq vectors and sets
; origin to $8000
;
; When building a standalone program, sets
; origin to $2000

  .include registers.inc.s

  .ifdef ROM
  .org $fffa
  .word nmi
  .word reset
  .word irq

  .org $8000
  .else
  .org $2000
  .endif

; vim: syntax=asm6502
