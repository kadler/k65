; basic program for Ben Eater's 6502 computer kit
; requires 6522 VIA 1 and ACIA
; prints a hello world message on the LCD and sends
; the message on the ACIA upon reset and additionally
; sends the message whenever data is received
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .include header.inc.s

nmi:
irq:
  rti

reset:
  ; set all pins in port B as outputs
  ; set all pins in port A as outputs
  lda #$ff
  sta DDRB1
  sta DDRA1

  lda #%00010000 ; 1 stop bit, 8 data bits, external clock, 16x external clock (115200)
  sta ACIACTL

  lda #%00001011
  sta ACIACMD



  ; ensure we're in 8-bit mode
  ; https://en.wikipedia.org/wiki/Hitachi_HD44780_LCD_controller#Mode_Selection
  lda #$30
  jsr lcd_cmd
  jsr lcd_cmd
  jsr lcd_cmd

  ; set up 2-line mode
  lda #$3C
  jsr lcd_cmd

  ; clear the display
  lda #$01
  jsr lcd_cmd

  ; move the cursor home
  lda #$02
  jsr lcd_cmd

  ; set display and cursor on, and blink cursor
  lda #$0f
  jsr lcd_cmd

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

  jmp send

  .include lcd.inc.s
  .include delay.inc.s

hello
  .asciiz "Hello, Serial Port!"

; vim: syntax=asm6502
