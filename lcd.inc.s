; LCD routines

; SPDX-License-Identifier: GPL-3.0-or-later

  .ifndef LCD_INC
LCD_INC = 1

; LCD commands
LCD_CLEAR       = %00000001
LCD_HOME        = %00000010
LCD_ENTRY_MODE  = %00000100
LCD_DISP_CTL    = %00001000
LCD_CURS_SHIFT  = %00010000
LCD_FUNC_SET    = %00100000
LCD_CGRAM_ADDR  = %01000000
LCD_DDRAM_ADDR  = %10000000


; LCD_ENTRY_MODE options
LCD_ENTRY_INC   = %00000010
LCD_ENTRY_DEC   = %00000000

; LCD_DISP_CTL options
LCD_DISPLAY_ON  = %00000100
LCD_DISPLAY_OFF = %00000000
LCD_CURSOR_ON   = %00000100
LCD_CURSOR_OFF  = %00000000
LCD_BLINK_ON    = %00000001
LCD_BLICK_OFF   = %00000000

; LCD_FUNC_SET options
LCD_8BIT_MODE   = %00010000
LCD_4BIT_MODE   = %00000000
LCD_TWO_LINE    = %00001000
LCD_ONE_LINE    = %00000000
LCD_5X10_FONT   = %00000100
LCD_5x8_FONT    = %00000000

; LCD_CURS_SHIFT options
LCD_SHIFT_DISP  = %00001000
LCD_MOVE_CURSOR = %00000000
LCD_DIR_RIGHT   = %00000100
LCD_DIR_LEFT    = %00000000


HEX
  .text "0123456789ABCDEF"

lcd_print_hex:
  phx
  pha

  lsr
  lsr
  lsr
  lsr
  tax
  lda HEX,x
  jsr lcd_putc

  pla
  pha
  and #$0f
  tax
  lda HEX,x
  jsr lcd_putc

  pla
  plx
  rts

lcd_puts:
  pha
  phy

  clc
  ldy #0
.loop:
  lda (R1),y
  beq .done

  jsr lcd_putc
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

lcd_putc:
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

lcd_clear:
  pha
  lda #LCD_CLEAR
  jsr lcd_cmd
  pla
  rts

lcd_home:
  pha
  lda #LCD_HOME
  jsr lcd_cmd
  pla
  rts

lcd_line_two:
  pha
  lda #(LCD_DDRAM_ADDR | $40)
  jsr lcd_cmd
  pla
  rts

  .endif

; vim: syntax=asm6502
