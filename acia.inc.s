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
; 0 = tx buffer empty, 1 = full
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

RCVBUF = $0400
BUFLEN = $0500

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

  lda #(ACIA_SBN_1 | ACIA_WL_8 | ACIA_SBR_9600)
  sta ACIACTL

  lda #(ACIA_PMC_DISABLE_PARITY | ACIA_PMC_DISABLE_PARITY | ACIA_ECHO_OFF | ACIA_RTS_LOW_TIC_DISABLED | ACIA_IRQ_DISABLE | ACIA_DTR_LOW)
  sta ACIACMD

  pla
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
