; classic "hello world" program for Ben Eater's 6502 computer kit
; This program is designed to be a loadable PRG file and makes use
; of hard-coded ROM routines.
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .include header.inc.s

main:
  pha

  ; clear the screen just in case
  jsr lcd_clear

  lda #<hello
  sta R1
  lda #>hello
  sta R1+1
  jsr lcd_puts

  pla
  rts

hello
  .asciiz "Hello SD World!"

; vim: syntax=asm6502
