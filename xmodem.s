; basic program for Ben Eater's 6502 computer kit
; requires 6522 VIA 1 and ACIA
; prints a hello world message on the LCD and sends
; the message on the ACIA upon reset and additionally
; sends the message whenever data is received
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .include header.inc.s

  .ifndef ROM
puts = $8000
lcd_cmd = $8003
delayms = $8006
putc = $8009
  .endif

  .ifdef ROM
syscall_puts:
  jmp puts
syscall_lcd_cmd:
  jmp lcd_cmd
syscall_delayms:
  jmp delayms
syscall_putc:
  jmp putc

nmi:
irq:
  rti
  .endif

reset:
  .ifdef ROM
  jsr lcd_init
  .else
  lda #$01
  jsr lcd_cmd
  .endif

  lda #%00010000 ; 1 stop bit, 8 data bits, external clock, 16x external clock (115200)
  sta ACIACTL

  lda #%00001011
  sta ACIACMD

  lda #<hello
  sta R1
  lda #>hello
  sta R1+1
  jsr puts

  jsr acia_read_byte

  lda #C
  sta ACIADTA

  jsr xmodem_rcv_prg

  ; lda #$01
  ; jsr lcd_cmd

  ; lda #'T'
  ; jsr putc

  jsr trampoline


  .ifdef ROM
.done:
  jmp reset
  .else
  rts
  .endif

trampoline:
 jmp (R1)


  .ifdef ROM
  .include lcd.inc.s
  .include delay.inc.s
  .endif

SOH = $01
EOT = $04
ACK = $06
NAK = $15
ETB = $17
CAN = $18
C   = $43

PKTHDR = $400
PACKET = PKTHDR+1
PKTNUM = PACKET
PKTNM2 = PACKET+1
PKTDTA = PACKET+2
PKTCRC1 = PACKET+130
PKTCRC2 = PACKET+131

acia_read_byte:
.wait
  lda ACIASTS
  and #$08
  beq .wait

  lda ACIADTA
  rts


xmodem_rcv_pkt:
  pha
  ; TODO: too big
  ;phx

  ldx #0
.loop
  jsr acia_read_byte
  sta PACKET,x
  
  inx
  cpx #132
  bne .loop

.done
  ;plx
  pla
  rts


  .ifdef VALIDATE
xmodem_validate_pkt:
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

  ; TODO: Check CRC

  clc
  rts

.error:
  sec
  rts
  .endif

memcpy8_upd:
  phx
  phy

  tax
  ldy #0
.loop:
  ;lda #$01
  ;jsr lcd_cmd

  ;lda R2+1
  ;jsr print_hex
  ;tya
  ;;lda R2
  ;jsr print_hex
  ;lda #' '
  ;jsr putc

  lda (R1),y
  sta (R2),y

  ;jsr print_hex
  ;lda #255
  ;jsr delayms
  ;jsr delayms

  iny
  dex
  bne .loop

  ; Update R2 to just past the copied data
  clc
  tya
  adc R2
  sta R2
  lda #0
  adc R2+1
  sta R2+1

  ply
  plx
  rts

xmodem_rcv_prg:
  pha
  phx
  phy

.start
  jsr acia_read_byte
  cmp #SOH
  bne .nak_first

  sta PKTHDR
  jsr xmodem_rcv_pkt

  .ifdef VALIDATE
  ; X will contain the packet number
  ; which starts at 1 (not 0!)
  ldx #1

  jsr xmodem_validate_pkt
  bcs .nak_first

  ; Increment packet number for next time
  inx
  .endif

  ; Load address
  ; Save in to the memcpy destination register (R2)
  ; And save a copy on the stack to return later
  lda PKTDTA
  sta R2
  pha
  ; jsr print_hex

  lda PKTDTA+1
  sta R2+1
  pha
  ; jsr print_hex
  ; lda #250
  ; jsr delayms
  ; jsr delayms
  ; jsr delayms
  ; jsr delayms

  ; Set the memcpy source register (R1) to the program
  ; data following the load address
  lda #<(PKTDTA+2)
  sta R1
  lda #>(PKTDTA+2)
  sta R1+1

  ; Copy 126 bytes, since the load address is not included
  lda #126
  jsr memcpy8_upd

  ; Ack the packet
  lda #ACK
  sta ACIADTA

  ;lda #1
  ;jsr delayms

  ; Set up our source register for the subsequent memcpys
  ; From here on out, it never changes so we can hoist it
  ; out of the loop
  lda #<PKTDTA
  sta R1
  lda #>PKTDTA
  sta R1+1

  ; Read more packets until an EOT byte is received
.loop:
  jsr acia_read_byte
  ;jsr print_hex

  cmp #EOT
  beq .done

  ; TODO: Too big
  ;cmp #SOH
  ;bne .nak

  sta PKTHDR
  jsr xmodem_rcv_pkt

  .ifdef VALIDATE
  jsr xmodem_validate_pkt
  bcs .nak

  ; Increment our packet number for next time
  inx
  .endif

  ; Copy all 128 bytes of the packet data this time
  lda #128
  jsr memcpy8_upd

  ; Ack the packet
  lda #ACK
  sta ACIADTA

  jmp .loop

.nak_first:
  lda #NAK
  sta ACIADTA
  jmp .start

.nak:
  lda #NAK
  sta ACIADTA
  jmp .loop

.done:
  ;lda #'d'
  ;jsr putc

  lda #ACK
  sta ACIADTA

  ; Retrieve our saved load address
  pla
  ; jsr print_hex
  sta R1+1
  pla
  ; jsr print_hex
  sta R1

  .if 0
.dump_mem:
  ldy #0
.loop2:
  lda #$01
  jsr lcd_cmd

  lda R1+1
  jsr print_hex
  tya
  jsr print_hex
  lda #' '
  jsr putc

  lda (R1),y

  jsr print_hex
  lda #255
  jsr delayms
  jsr delayms

  iny
  cpy #128
  bne .loop2
  .endif

.ret:
  ply
  plx
  pla
  rts

hello
 .asciiz "XMODEM TEST"

; vim: syntax=asm6502
