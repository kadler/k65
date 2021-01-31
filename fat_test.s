
; basic program for Ben Eater's 6502 computer kit
; requires 6522 VIA 1 and ACIA
; prints a hello world message on the LCD and sends
; the message on the ACIA upon reset and additionally
; sends the message whenever data is received
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .include header.inc.s

  .ifdef ROM
syscall_puts:
  jmp puts
syscall_lcd_cmd:
  jmp lcd_cmd
syscall_delayms:
  jmp delayms
syscall_putc:
  jmp putc

nmi:
irq:
  rti
  .endif

reset:
  .ifdef ROM
  jsr lcd_init
  .else
  lda #$01
  jsr lcd_cmd
  .endif

  lda #<message
  sta R1
  lda #>message
  sta R1+1
  jsr puts

  lda #250
  jsr delayms
  jsr delayms
  jsr delayms
  jsr delayms

  stz ERR_COD
  stz ERR_SRC
  jsr fat16_init
  bcs .error

  jsr fat16_load_prg
  bcs .error
  jsr .trampoline

.done:
  jmp .done

.error:
  lda #$C0
  jsr lcd_cmd

  lda #<message_error
  sta R1
  lda #>message_error
  sta R1+1

  jsr puts

  lda #' '
  jsr putc

  lda ERR_SRC
  ora #$30
  jsr putc

  lda #' '
  jsr putc

  lda ERR_COD
  ora #$30
  jsr putc

  jmp .done

  ; TODO: This should be a utiliy function in another module
.trampoline:
  jmp (R1)


  .include fat.inc.s

message_error
  .asciiz "ERROR"

message
  .asciiz "Checking SD card"