; XMODEM routines
;
; This module implements the original XMODEM protocol.
; https://en.wikipedia.org/wiki/XMODEM#Packet_structure
;
; The receiver starts by sending a <NAK>, then the sender will start sending
; 132-byte packets. Each packet contains:
; - <SOH> byte
; - Packet number starting at 1
; - Inverse packet number
; - 128 bytes of data
; - 1 byte checksum of all previous bytes
;
; The main entrypoint provided, is xmodem_rcv_prg, which recieves a PRG file
; and loads it at the start address specified.
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .ifndef XMODEM_INC
XMODEM_INC = 1

SOH = $01
EOT = $04
ACK = $06
NAK = $15
ETB = $17
CAN = $18

PKTNUM = $600
PKTNM2 = PKTNUM+1
PKTCSUM = PKTNM2+1

  .macro XMODEM_UPDATE_CSUM
  clc
  adc PKTCSUM
  sta PKTCSUM
  .endm

xmodem_rcv_prg:
  pha
  phx
  phy

 ; We start by sending a <NAK> to the sender
.nak_first:
  lda #NAK
  sta ACIADTA

.start
  ; Wait until we find the start of a packet
  ; TODO: Need some sort of timeout/error here
  jsr acia_getc
  cmp #SOH
  beq .start_first

  ; If we didn't get the expected <SOH>, send a <NAK> and start over
  jmp .nak_first

  ; The first packet we get, we need to handle specially, since we need to read
  ; the first two bytes of data for the load address. From there, we store the
  ; received data directly in to memory starting at the load address specified.
.start_first
  ; Initialize our checksum calculation
  sta PKTCSUM

  ; Get the first packet number and update the checksum
  jsr acia_getc
  sta PKTNUM
  XMODEM_UPDATE_CSUM

  ; Get the inverted packet number and update the checksum
  jsr acia_getc
  sta PKTNM2
  XMODEM_UPDATE_CSUM

  ; X will contain the packet number, which starts at 1 (not 0!)
  ldx #1

  ; Validate we have gotten the expected packet number
  ; TODO: Do we need to wait until we've received the whole packet?
  jsr xmodem_validate_pktnum
  bcs .nak_first

  ; Increment packet number for next time
  inx

  ; Read the first two bytes of the PRG to determine its load address
  ;
  ; Save in to R2. The xmodem_rcv_pkt function will write data using this
  ; register and we'll update it as we receive packets. Save a copy on the
  ; stack, since we'll need to return this value for the caller to use.
  jsr acia_getc
  sta R2
  pha
  XMODEM_UPDATE_CSUM

  jsr acia_getc
  sta R2+1
  pha
  XMODEM_UPDATE_CSUM

  ; Read the remaining 126 bytes of data of the packet in to the load address
  ldy #0
.first_loop
  jsr acia_getc
  sta (R2),y
  XMODEM_UPDATE_CSUM

  iny
  cpy #126
  bne .first_loop

  ; Validate the received checksum matches our calculated checksum
  jsr acia_getc
  cmp PKTCSUM
  ; If it doesn't match, we need to send a <NAK> and start over with the
  ; special first packet handling.
  bne .nak_first

  ; Ack the packet
  lda #ACK
  sta ACIADTA

  ; Increment R2 past the 126 bytes of data we just read
  clc
  lda R2
  adc #126
  sta R2
  lda R2+1
  adc #0
  sta R2+1

  ; From here, we just read packets until we get an <EOT> byte signalling the end.
  ; Each packet is read in to the next 128 byte chunk of memory in R2.
.loop:
  ; TODO: Should probably add a timeout here in case the sender gives up
  jsr acia_getc

  ; If we get an <EOT>, the sender is done sending data so break out of the loop
  cmp #EOT
  beq .done

  ; If we didn't get the expected <SOH>, send a <NAK> and continue.
  cmp #SOH
  bne .nak

  ; Read in a whole packet. This function also validates the packet number was
  ; correct and that the checksum matched our calculated value.
  jsr xmodem_rcv_pkt
  bcs .nak

  ; Increment our packet number for next time
  inx

  ; Ack the packet
  lda #ACK
  sta ACIADTA

  ; Increment R2 past the 128 bytes of data we just read
  clc
  lda R2
  adc #128
  sta R2
  lda R2+1
  adc #0
  sta R2+1

  ; Get the next packet
  jmp .loop

.nak:
  ; Send a <NAK>
  lda #NAK
  sta ACIADTA
  jmp .loop

.done:
  ; We're done reading packets. All that's left to do is to <ACK> the <EOT>
  lda #ACK
  sta ACIADTA

  ; Retrieve our saved load address to return to the caller
  pla
  sta R1+1
  pla
  sta R1

.ret:
  ply
  plx
  pla
  clc
  rts


xmodem_rcv_pkt:
  pha
  phy

  ; Initialize our checksum calculation
  sta PKTCSUM

  ; Get the packet number and update the checksum
  jsr acia_getc
  sta PKTNUM
  XMODEM_UPDATE_CSUM

  ; Get the inverted packet number and update the checksum
  jsr acia_getc
  sta PKTNM2
  XMODEM_UPDATE_CSUM

  ldy #0
.loop:
  ; Get 128 data bytes and update the checksum
  jsr acia_getc
  sta (R2),y
  XMODEM_UPDATE_CSUM

  iny
  cpy #128
  bne .loop

  ; Validate the received checksum matches our calculated checksum
  jsr acia_getc
  cmp PKTCSUM
  bne .error

  ; Validate our packet number was the expected one and received correctly
  jsr xmodem_validate_pktnum
  bcs .error

.done:
  clc
  ply
  pla
  rts

.error:
  sec
  ply
  pla
  rts


xmodem_validate_pktnum:
  pha

  ; Ensure the packet we got is what we expect
  ; x contains the expected packet number
  cpx PKTNUM
  bne .error

  ; PKTNUM + PKTNM2 should equal 255 exactly
  clc
  lda PKTNUM
  adc PKTNM2

  ; Ensure we didn't overflow
  bcs .error

  ; Ensure it was 255
  cmp #$ff
  bne .error

  pla
  clc
  rts

.error:
  pla
  sec
  rts


XMODEM_START
  .asciiz "XMODEM STARTED"

XMODEM_FOUND_PACKET
  .asciiz "FOUND PACKET"

XMODEM_ACK
  .asciiz "ACK"

XMODEM_NAK
  .asciiz "NAK"

  .endif
; vim: syntax=asm6502
