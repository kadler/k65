; ACIA routines

; SPDX-License-Identifier: GPL-3.0-or-later

  .ifndef ACIA_INC
ACIA_INC = 1

; Handy serial terminology:
;
; DCE - data circuit-terminating equipment
; DTE - data terminal equipment
;
; DCD - data carrier detect
; RXD - receive data
; TXD - transmit data
; DTR - data terminal ready
; DSR - data set ready
; RTS - request to send
; CTS - clear to send

; === Flags for Status Register ACIASTS (p7) ===
; 0 = No Interrupt, 1 = interrupt has occurred
ACIA_IRQ_BIT = %10000000
; 0 = ready, 1 = not ready (active low)
ACIA_DSR_BIT = %01000000
; 0 = detected, 1 = not detected (active low)
ACIA_DCD_BIT = %00100000
; 0 = tx buffer full, 1 = empty
ACIA_TXF_BIT = %00010000
; 0 = rx buffer empty, 1 = full
ACIA_RXF_BIT = %00001000
; 0 = no overrun, 1 = overrun occurred
ACIA_OVR_BIT = %00000100
; 0 = no framing errors, 1 = framing error occurred
ACIA_FRM_BIT = %00000010
; 0 = no parity errors, 1 = parity error occurred
ACIA_PAR_BIT = %00000001


; === Flags for Control Register ACIACTL (p9) ===
; Stop Bit Number (SBN)
ACIA_SBN_1                    = %00000000
ACIA_SBN_2                    = %10000000
; NOTE: When using ACIA_WL_5 and no parity
ACIA_SBN_1_HALF               = %10000000
; NOTE: when using ACIA_WL_8 *with* parity
ACIA_SBN_1_PARITY             = %10000000

; Word Length (WL)
ACIA_WL_8                     = %00000000
ACIA_WL_7                     = %00100000
ACIA_WL_6                     = %01000000
ACIA_WL_5                     = %01100000

; Receiver Clock Source (RCS)
ACIA_RCS_EXT                  = %00000000
ACIA_RCS_TX_RATE              = %00010000

; Selected Baud Rate (SBR)
; NOTE: These assume clock rate of 1.8432MHz fed to the baud rate generator
ACIA_SBR_16X                  = %00000000
ACIA_SBR_50                   = %00000001
ACIA_SBR_75                   = %00000010
ACIA_SBR_109                  = %00000011
ACIA_SBR_134                  = %00000100
ACIA_SBR_150                  = %00000101
ACIA_SBR_300                  = %00000110
ACIA_SBR_600                  = %00000111
ACIA_SBR_1200                 = %00001000
ACIA_SBR_1800                 = %00001001
ACIA_SBR_2400                 = %00001010
ACIA_SBR_3600                 = %00001011
ACIA_SBR_4800                 = %00001100
ACIA_SBR_7200                 = %00001101
ACIA_SBR_9600                 = %00001110
ACIA_SBR_19200                = %00001111

; === Flags for Command Register ACIACMD (p11) ===
; Parity Mode Control (PMC) flags
ACIA_PMC_ODD_PARITY           = %00000000
ACIA_PMC_EVEN_PARITY          = %01000000
ACIA_PMC_DISABLE_PARITY       = %10000000

; Parity Mode Enable (PME) flags
ACIA_PARITY_MODE_ON           = %00100000
ACIA_PARITY_MODE_OFF          = %00000000

; Receiver Echo Mode (REM) flags
ACIA_ECHO_OFF                 = %00000000
ACIA_ECHO_ON                  = %00010000

; Transmitter Interrupt Control (TIC) flags
ACIA_RTS_HIGH_TIC_DISABLED    = %00000000
ACIA_RTS_LOW_TIC_ENABLED      = %00000100
ACIA_RTS_LOW_TIC_DISABLED     = %00001000
ACIA_RTS_LOW_TIC_DISABLED_TXD = %00001100

; Receiver Interrupt Request Disabled (IRD) flags
ACIA_IRQ_ENABLE               = %00000000
ACIA_IRQ_DISABLE              = %00000010

; Data Terminal Ready (DTR) flags
ACIA_DTR_HIGH                 = %00000000
ACIA_DTR_LOW                  = %00000001

BS = $08
LF = $0a
CR = $0d
DEL = $7f

RCVBUF = $0600
BUFLEN = $0700

  ; TODO: figure out how to do this better
  ;
  ; For now, delay until byte is sent
  ; Takes FREQ / BAUD / 10 cycles (160) to transfer a byte
  .macro SND_DELAY
  pha
  lda #2
  jsr delayms
  pla
  .endm


acia_init:
  pha

  lda #(ACIA_SBN_1 | ACIA_WL_8 | ACIA_RCS_TX_RATE | ACIA_SBR_9600)
  sta ACIACTL

  lda #(ACIA_PMC_DISABLE_PARITY | ACIA_PARITY_MODE_OFF | ACIA_ECHO_OFF | ACIA_RTS_LOW_TIC_DISABLED | ACIA_IRQ_DISABLE | ACIA_DTR_LOW)
  sta ACIACMD

  pla
  ; fall through to acia_clear_buffer

acia_clear_buffer:
  stz BUFLEN
  stz RCVBUF
  rts

acia_check_data:
  phx

  ; Check if we've received a byte
  lda ACIASTS
  and #ACIA_RXF_BIT
  beq .error

  ; If so, store it in the current receive buffer index then update and store
  ; the new buffer length
  ldx BUFLEN
  lda ACIADTA
  sta RCVBUF,x
  inx
  stx BUFLEN

  ; Check if we got a backspace (DEL). We need to handle this specially
  cmp #DEL
  bne .not_backspace

  ; Clear out DEL character we just stored
  dex
  stz RCVBUF,x

  ; If the above dex was not 0, that means we have a character to remove
  ; from the buffer
  beq .empty

  ; Clear out the previous character in the local buffer and update BUFLEN
  dex
  stz RCVBUF,x
  stx BUFLEN

  ; Send a backspace character to the receiver, overwrite the previous
  ; character on screen with a blank
  lda #BS
  sta ACIADTA
  SND_DELAY
  lda #' '
  sta ACIADTA
  SND_DELAY

  lda #BS
  jmp .normal_echo

.empty:
  ; Otherwise, the buffer was already empty, so just set the BUFLEN to 0
  stx BUFLEN
  jmp .done

.not_backspace:
  ; Linux/picocom sends us CR only, but expects CRLF so we need special
  ; handling
  cmp #CR
  bne .not_cr

  ; Echo the CR
  sta ACIADTA
  SND_DELAY

  ; Then get ready to echo an LF.
  lda #LF
  jmp .normal_echo

.not_cr:
  ; Don't echo control codes other than CR, but echo printable characters
  ; TODO: control codes probably should not be stored in the buffer, either
  cmp #' '
  bcc .done

.normal_echo:
  ; Either send another backspace character to move the cursor back after we overwrite
  ; the previous character OR we're just echoing the character that was received.
  sta ACIADTA
  SND_DELAY

.done:
  plx
  clc
  rts

.error:
  plx
  sec
  rts


; func acia_putc
; send a byte to ACIA
;
; inputs:
;  - #a - input character
; outputs:
;  - %C - set on error
acia_putc:
  sta ACIADTA
  SND_DELAY
  clc
  rts

acia_getc:
.wait
  lda ACIASTS
  and #ACIA_RXF_BIT
  beq .wait

  lda ACIADTA
  rts

acia_has_byte:
  pha
  lda ACIASTS
  and #ACIA_RXF_BIT
  bne .has_byte
  sec
  pla
  rts

.has_byte:
  clc
  pla
  rts


; func acia_puts
; send a byte to ACIA until a NUL byte found
;
; NOTE: input *must* be <256 bytes long or
;       infinite loop will occur
;
; inputs:
;  - #R1 - input string
; outputs:
;  - %C - set on error
acia_puts:
  pha
  phy

  ldy #0
.loop:
  lda (R1),y
  beq .done
  sta ACIADTA

  SND_DELAY

  iny
  jmp .loop

.done
  ; send newline
  lda #CR
  sta ACIADTA
  SND_DELAY

  lda #LF
  sta ACIADTA
  SND_DELAY

  ply
  pla
  clc
  rts

.error:
  ply
  pla
  sec
  rts


; func acia_print_hex
; Send input character as two hex characters to ACIA
;
; inputs:
;  - #a - input character
; outputs:
;  - %C - set on error
acia_print_hex:
  phx
  pha

  lsr
  lsr
  lsr
  lsr
  tax
  lda HEX,x
  sta ACIADTA
  SND_DELAY

  pla
  pha
  and #$0f
  tax
  lda HEX,x
  sta ACIADTA
  SND_DELAY

  pla
  plx
  rts


  .endif

; vim: syntax=asm6502
