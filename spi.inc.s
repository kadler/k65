; SPI routines
;
; https://en.wikipedia.org/wiki/Serial_Peripheral_Interface
;
; SPI is a full duplex serial bus, so it sends and receives simultaneously. To
; implement it, we use the shift registers of both VIAs, one to send data and
; the other to receive.  The output shift register SR2 will output the shift
; clock on CB1, which is also used for the receive shift register SR1.
;
; SI  - VIA2 CB2
; SO  - VIA1 CB2
; CLK - VIA2 CB1

; SPDX-License-Identifier: GPL-3.0-or-later

  .ifndef SPI_INC
SPI_INC = 1

; === Flags for Status Register ACIASTS (p26) ===
; 0 = No Interrupt, 1 = interrupt has occurred
VIA_IRQ_BIT = %10000000
; 1 = Time out of T1 timer
VIA_T1_BIT = %01000000
; 1 = Time out of T2 timer
VIA_T2_BIT = %00100000
; 1 = CB1 active edge
VIA_CB1_BIT = %00010000
; 1 = CB2 active edge
VIA_CB2_BIT = %00001000
; 1 = completed 8 shifts
VIA_SR_BIT = %00000100
; 1 = CA1 active edge
VIA_CA1_BIT = %00000010
; 1 = CA2 active edge
VIA_CA2_BIT = %00000001


; === Flags for Peripheral Control Register PCR (p12) ===
; CB2 Control
VIA_PCR_CB2_IN_NEG_EDGE  = %00000000
VIA_PCR_CB2_IND_INT_NEG  = %00100000
VIA_PCR_CB2_IN_POS_EDGE  = %01000000
VIA_PCR_CB2_IND_INT_POS  = %01100000
VIA_PCR_CB2_HNDSHK_OUT   = %10000000
VIA_PCR_CB2_PULSE_OUT    = %10100000
VIA_PCR_CB2_LOW          = %11000000
VIA_PCR_CB2_HIGH         = %11100000
VIA_PCR_CB2_MASK         = ~%11100000

; CB1 Control
VIA_PCR_CB1_NEG_EDGE     = %00000000
VIA_PCR_CB1_POS_EDGE     = %00010000
VIA_PCR_CB1_MASK         = ~%00010000

; CA2 Control
VIA_PCR_CA2_IN_NEG_EDGE  = %00000000
VIA_PCR_CA2_IND_INT_NEG  = %00000010
VIA_PCR_CA2_IN_POS_EDGE  = %00000100
VIA_PCR_CA2_IND_INT_POS  = %00000110
VIA_PCR_CA2_HNDSHK_OUT   = %00001000
VIA_PCR_CA2_PULSE_OUT    = %00001010
VIA_PCR_CA2_LOW          = %00001100
VIA_PCR_CA2_HIGH         = %00001110
VIA_PCR_CA2_MASK         = ~%00001110

; CA1 Control
VIA_PCR_CA1_NEG_EDGE     = %00000000
VIA_PCR_CA1_POS_EDGE     = %00000001
VIA_PCR_CA1_MASK         = ~%00000001


; === Flags for Auxiliary Control Register ACR (p16) ===
; T1 Timer Control (T1C)
VIA_ACR_T1C_TIME_INT     = %00000000
VIA_ACR_T1C_CONT_INT     = %01000000
VIA_ACR_T1C_TIME_INT_PB7 = %10000000
VIA_ACR_T1C_CONT_INT_PB7 = %11000000
VIA_ACR_T1C_MASK         = ~%11000000

; T2 Timer Control (T2C)
VIA_ACR_T2C_TIME_INT     = %00000000
VIA_ACR_T2C_COUNT_PB6    = %00100000
VIA_ACR_T2C_MASK         = ~%00100000

; Shift Register Control (SRC)
VIA_ACR_SRC_DISABLED     = %00000000
VIA_ACR_SRC_IN_T2        = %00000100
VIA_ACR_SRC_IN_PHI2      = %00001000
VIA_ACR_SRC_IN_EXT_CLK   = %00001100
VIA_ACR_SRC_OUT_T2_FREE  = %00010000
VIA_ACR_SRC_OUT_T2       = %00010100
VIA_ACR_SRC_OUT_PHI2     = %00011000
VIA_ACR_SRC_OUT_EXT_CLK  = %00011100
VIA_ACR_SRC_MASK         = ~%00011100

; Latch Enable/Disable
VIA_ACR_LATCH_PB_OFF     = %00000000
VIA_ACR_LATCH_PB_ON      = %00000010
VIA_ACR_LATCH_PB_MASK    = ~%00000010

VIA_ACR_LATCH_PA_OFF     = %00000000
VIA_ACR_LATCH_PA_ON      = %00000001
VIA_ACR_LATCH_PA_MASK    = ~%00000001



spi_init:
  ; Default to low speed clock using T2 timer
  lda #(VIA_ACR_SRC_OUT_T2)
  sta ACR2

  ; Always use output clock as input clock
  lda #(VIA_ACR_SRC_IN_EXT_CLK)
  sta ACR1

  ; Load the input SR to get it ready to receive data
  ; If we don't do this, it will never latch data
  lda SR1

  ; Set T2 timer to 0. Each bit takes N+2 clock cycles.
  ; At 1.8432MHz, this is about 300 kHz
  lda #0
  sta T2CL2
  lda #0
  sta T2CH2

; func spi_set_fast
;
; Set SPI bus to use fast clock
;
; This runs at half of PHI2 about 920 kHz @ 1.843 MHz PHI2
;
spi_set_fast:
  pha

  ; High speed clock runs at (half) PHI2 rate
  lda #(VIA_ACR_SRC_OUT_PHI2)
  sta ACR2

  pla
  rts


; func spi_set_slow
;
; Set SPI bus to use slow clock
;
; This clock uses T2 timer to set the frequency. Using T2=0,
; this is about 300 kHz @ 1.843 MHz PHI2
;
spi_set_slow:
  pha

  ; Low speed clock uses T2 timer to set frequency
  lda #(VIA_ACR_SRC_OUT_T2)
  sta ACR2

  ; Set T2 timer to 0. Each bit takes N+2 clock cycles.
  ; At 1.8432MHz, this is about 300 kHz
  lda #0
  sta T2CL2
  lda #0
  sta T2CH2

  pla
  rts


; func spi_write_byte
;
; Reads a byte in to accumulator to the SPI bus
;
; Since SPI is full-duplex, to read we must also write. So spi_read_byte simply
; writes $ff.
;
; NOTE: Must enable device CS prior to call
spi_read_byte:
  lda #$ff

  ; fall-through to sd_write_byte

; func spi_write_byte
;
; Writes a byte from the accumulator to the SPI bus
;
; NOTE: Must enable device CS prior to call
spi_write_byte:
  sta SR2

  ; Wait until SR bit in the IFR flag is on
  ; to indicate it recieved 8 bits
.wait:
  lda IFR1
  and #VIA_SR_BIT
  beq .wait

  lda SR1
  rts


  .endif

; vim: syntax=asm6502
