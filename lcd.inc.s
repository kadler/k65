; LCD functions for Ben Eater's 6502 computer kit

; SPDX-License-Identifier: GPL-3.0-or-later

  .ifndef LCD_INC
LCD_INC = 1

puts:
  pha
  phy

  clc
  ldy #0
.loop:
  lda (R1),y
  beq .done

  jsr lcd_data
  iny
  bne .loop

.done:
  ply
  pla
  rts


lcd_init:
  ; set all pins in port B as outputs
  ; set all pins in port A as outputs
  lda #$ff
  sta DDRB1
  sta DDRA1

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

  ; set display and cursor on
  lda #$0e
  jsr lcd_cmd

  rts


lcd_wait:
  pha

  ; set PB1 to input
  lda #0
  sta DDRB1

.check_status:
  lda #$C0  ; CLK=1, R/W=1 (R), RS=0 (CMD)
  sta PA1

  ; read the busy flag
  lda PB1
  pha

  lda #$40  ; CLK=0, R/W=1 (R), RS=0 (CMD)
  sta PA1

  ; Since the busy flag is in the top bit, we can cheat
  ; and check for a "negative" value
  pla
  bmi .check_status

  ; set PB1 back to output
  lda #$ff
  sta DDRB1

  pla
  rts

lcd_data:
putc:
  pha
  jsr lcd_wait

  sta PB1
  lda #$A0  ; CLK=1, R/W=0 (W), RS=1 (DATA)
  sta PA1
  lda #$00  ; CLK=0, R/W=0 (W), RS=0 (CMD)
  sta PA1

  pla
  rts

lcd_cmd:
  pha
  jsr lcd_wait

  sta PB1
  lda #$80  ; CLK=1, R/W=0 (W), RS=0 (CMD)
  sta PA1
  lda #$00  ; CLK=0, R/W=0 (W), RS=0 (CMD)
  sta PA1

  pla
  rts

  .endif

; vim: syntax=asm6502
