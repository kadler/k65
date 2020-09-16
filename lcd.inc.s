lcd_wait:
  pha

  ; set PB1 to input
  lda #0
  sta DDRB1

check_lcd_status:
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
  bmi check_lcd_status

  ; set PB1 back to output
  lda #$ff
  sta DDRB1

  pla
  rts

lcd_data:
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
  jsr lcd_wait
  pha

  sta PB1
  lda #$80  ; CLK=1, R/W=0 (W), RS=0 (CMD)
  sta PA1
  lda #$00  ; CLK=0, R/W=0 (W), RS=0 (CMD)
  sta PA1

  pla
  rts

; vim: syntax=asm6502
