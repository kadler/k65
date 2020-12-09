; K65, Kevin's 6502 based OS/Monitor
;
; Upon reset, it will initialize the LCD character display
; Currently nmi and irq do nothing
;
; Routines include:
; # LCD
;  - puts
;  - putc
;  - print_hex
;  - lcd_clear
;  - lcd_home
;  - lcd_line_two
;
; # Time-related
;  - delay
;  - delayms
;
; Routine addresses are defined in syscalls.inc.s which is generated from this
; file. PRG files will be re-built if the syscalls are changed. This includes,
; adding new syscalls, as well as removing or re-ordering syscalls.  Backward
; compatibility is maintained so long as syscalls are not removed, re-ordered,
; or new syscalls are added only at the end.
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .include header.inc.s

; WARNING WARNING WARNING WARNING WARNING WARNING
;
; Syscalls should only be added after existing syscalls and syscalls should not
; be removed so that compatibility is maintined with existing programs.
;

; TODO: Rename puts and putc to lcd_puts and lcd_putc
puts_syscall:
  jmp puts

putc_syscall:
  jmp putc

print_hex_syscall:
  jmp print_hex

lcd_cmd_syscall:
  jmp lcd_cmd

lcd_clear_syscall:
  jmp lcd_clear

lcd_home_syscall:
  jmp lcd_home

lcd_line_two_syscall:
  jmp lcd_line_two

delay_syscall:
  jmp delay

delayms_syscall:
  jmp delayms


trampoline:
  jmp (R1)

nmi:
  rti

irq:
  rti


reset:
  ; Set the stack pointer to $ff
  ldx #$ff
  txs

  ; initialize the LCD
  jsr lcd_init

  lda #<msg
  sta R1
  lda #>msg
  sta R1+1
  jsr puts

.loop:
  jmp .loop


msg:
  .asciiz "Welcome to K65!"


  .include delay.inc.s
  .include lcd.inc.s
  .include sdio.inc.s
  .include fat.inc.s

; vim: syntax=asm6502
