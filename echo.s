; basic program for Ben Eater's 6502 computer kit
; requires 6522 VIA 1 and ACIA
; prints a hello world message on the LCD and sends
; the message on the ACIA upon reset and additionally
; sends the message whenever data is received
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .include header.inc.s

  .ifdef ROM
nmi:
irq:
  rti
  .endif

reset:
  jsr lcd_init

  lda #%00010000 ; 1 stop bit, 8 data bits, external clock, 16x external clock (115200)
  sta ACIACTL

  lda #%00001011
  sta ACIACMD

  lda #<hello
  sta R1
  lda #>hello
  sta R1+1
  jsr puts


send:
  ; X is our string index
  ldx #0

.loop:
  ; TODO: Is this the infamous ACIA bug?
  ;wait_txd_empty:
  ;lda ACIASTS
  ;and #$10
  ;beq wait_txd_empty

  lda hello, x
  beq .newline

  sta ACIADTA
  lda #1
  jsr delayms

  inx
  jmp .loop

.newline
  lda #$0d
  sta ACIADTA
  lda #1
  jsr delayms
  lda #$0a
  sta ACIADTA

receive:
wait_rxd_full:
  lda ACIASTS
  and #$08
  beq wait_rxd_full

  ; Clear buffer
  lda ACIADTA

  .ifdef ROM
  jmp send
  .else
  cmp #'u'
  bne send
  rts
  .endif

  .include lcd.inc.s
  .include delay.inc.s

hello
  .asciiz "Hello, Serial Port!"

; vim: syntax=asm6502
