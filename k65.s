; K65, Kevin's 6502 based OS/Monitor
;
; Upon reset, it will initialize the LCD character display and ACIA
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
; # ACIA
;  - acia_putc
;  - acia_puts
;  - acia_print_hex
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

acia_putc_syscall:
  jmp acia_putc

acia_puts_syscall:
  jmp acia_puts

acia_print_hex_syscall:
  jmp acia_print_hex

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

  ; Initialize the LCD
  jsr lcd_init

  ; Initialize the ACIA
  jsr acia_init

  ; Print a welcome message
  lda #<WELCOME
  sta R1
  lda #>WELCOME
  sta R1+1

  jsr puts
  jsr acia_puts

  ; Enter the main loop
mainloop:
  jsr lcd_line_two

  jsr acia_check_data
  bcs mainloop

  ; if the user sent a LF, then a command is ready to be checked
  ; NOTE: Default behavior for picocom/Linux is to convert LF -> CR (not CRLF),
  ;       however we handle that and inject an LF locally.
  cmp #LF
  bne mainloop

  ; Print diagnostic message
  jsr lcd_home
  lda #<COMMAND_CHECK
  sta R1
  lda #>COMMAND_CHECK
  sta R1+1
  jsr puts

  ; see if we had a valid command
  lda #<RCVBUF
  sta R2
  lda #>RCVBUF
  sta R2+1
  jsr find_command

  ; If command was not found, so there's nothing to do but clear the buffer
  ; TODO: Print error message
  bcs .clear_command

  ; Otherwise, call the found command routine
  jsr trampoline

.clear_command:
  ; Regardless of whether we got a valid command or not, we need to clear the buffer
  ; so we're ready to start decoding the next command.
  jsr acia_clear_buffer

  jmp mainloop


COMMAND_CHECK:
  .asciiz "Checking command"
WELCOME:
  .asciiz "Welcome to K65!"


  .include acia.inc.s
  .include monitor.inc.s
  .include delay.inc.s
  .include lcd.inc.s
  .include sdio.inc.s
  .include fat.inc.s
  .include xmodem.inc.s

; vim: syntax=asm6502
