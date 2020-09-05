lcd_wait:
  pha

  ; set PORTB to input
  lda #0
  sta PORTBDIR

check_lcd_status:
  lda #$C0  ; CLK=1, R/W=1 (R), RS=0 (CMD)
  sta PORTA

  ; read the busy flag
  lda PORTB
  pha

  lda #$40  ; CLK=0, R/W=1 (R), RS=0 (CMD)
  sta PORTA

  ; Since the busy flag is in the top bit, we can cheat
  ; and check for a "negative" value
  pla
  bmi check_lcd_status

  ; set PORTB back to output
  lda #$ff
  sta PORTBDIR

  pla
  rts

lcd_data:
  pha
  jsr lcd_wait

  sta PORTB
  lda #$A0  ; CLK=1, R/W=0 (W), RS=1 (DATA)
  sta PORTA
  lda #$00  ; CLK=0, R/W=0 (W), RS=0 (CMD)
  sta PORTA

  pla
  rts

lcd_cmd:
  jsr lcd_wait
  pha

  sta PORTB
  lda #$80  ; CLK=1, R/W=0 (W), RS=0 (CMD)
  sta PORTA
  lda #$00  ; CLK=0, R/W=0 (W), RS=0 (CMD)
  sta PORTA

  pla
  rts

; vim: syntax=asm6502
