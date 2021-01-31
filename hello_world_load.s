; classic "hello world" program for Ben Eater's 6502 computer kit
; This program is designed to be a loadable PRG file and makes use
; of hard-coded ROM routines.
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .include registers.inc.s

puts = $8000
lcd_cmd = $8003
delayms = $8006

  .org $5000

main:
  pha

  ; clear the screen just in case
  lda #$01
  jsr lcd_cmd

  lda #<hello
  sta R1
  lda #>hello
  sta R1+1
  jsr puts

  pla
  rts

hello
  .asciiz "Hello SD World!"

; vim: syntax=asm6502
