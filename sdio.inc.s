; LCD functions for Ben Eater's 6502 computer kit

; SPDX-License-Identifier: GPL-3.0-or-later

SD_CMD = $0200
SD_ARG = $0201
SD_CRC = $0205
SD_FLG = $0206

SD_DTA = $0300 ; Page aligned for ease of use

SD_FLG_RSP = $80
SD_FLG_DTA = $40

  .macro PUTS
  pha
  lda #<\1
  sta R1
  lda #>\1
  sta R1+1
  jsr puts2
  pla
  .endm

puts2:
  lda #$01
  jsr lcd_cmd
  jsr puts
  lda #250
  jsr delayms
  jsr delayms
  rts

  .macro SET_CMD_FIELDS
  lda #($40 | \1)
  sta SD_CMD

  stz SD_ARG
  stz SD_ARG+1
  lda #>\2
  sta SD_ARG+2
  lda #<\2
  sta SD_ARG+3

  lda #\3
  sta SD_FLG
  .endm

  .macro SET_CMD_FIELDS_CRC
  SET_CMD_FIELDS \1, \2, \3
  lda #\4
  sta SD_CRC
  .endm


print_hex:
  phx
  pha

  lsr
  lsr
  lsr
  lsr
  tax
  lda HEX,x
  jsr lcd_data

  pla
  pha
  and #$0f
  tax
  lda HEX,x
  jsr lcd_data

  pla
  plx
  rts

hexdump:

  ; Move to line 2
  lda #$C0
  jsr lcd_cmd
  
  ldy #0
hex_loop:
  lda SD_DTA,y
  jsr print_hex

  iny
  cpy #16
  bne hex_loop

  rts


sd_init:
  ; TODO: Move this elsewhere?
  lda #$f0
  sta DDRA2
  lda #$ff
  sta DDRB2

; Initialize the microcontroller in the sd card after power-on with, sending
; 1 bits while the card is not selected.
; The spec says *at least* 74 clocks must be sent, but Micropython and
; CircuitPython both use 80 clocks so we follow suit.
init_micro:
  PUTS SD_INIT

  ; Make sure we're not selecting the SD card
  lda #SD_CSB
  sta PB2

  lda #SD_MOSI
  sta PA2

  ldx #80
.loop:
  ora SD_SCLK
  sta PA2
  and #~SD_SCLK
  sta PA2

  dex
  bne .loop

  ; The micro should now be reset and ready to receive commands
  ; We must convert it from SD mode to SPI mode by sending CMD0
  ; to put it in idle state. We do this 5 times and assume if
  ; it doesn't work, there must be no SD card inserted.
  SET_CMD_FIELDS_CRC 0, 0, 0, $95

  ldx #5
send_cmd0:
  PUTS SEND_CMD0
  jsr sd_cmd
  cmp #1
  beq cmd0_done

  dex
  bne send_cmd0

  PUTS NO_SDCARD
  ; TODO: Carve out a memory location to serve as a status byte
  sec
  rts

cmd0_done:
  PUTS FOUND_SDCARD

  ; Once in idle state, we must send CMD8 to do V2 init
  ; TODO: We don't plan on doing V2 init, so do we even need
  ; to send this?
  SET_CMD_FIELDS_CRC 8, $01aa, SD_FLG_RSP, $87

  PUTS SEND_CMD8
  jsr sd_cmd

  ;cmp #$01
  ;beq sd_v2_init

  ;cmp #$04
  ;bmi sd_v1_init

;sd_v2_init:
;  ; NOTE: We are not going to support high-capacity mode
;  ; so we're going to init as a v1 card
;  PUTS SD_V2_INIT

;  lda SD_ARG+3
;  cmp #$aa
;  beq sd_init

;  PUTS SD_CHECK_PATTERN_ERROR
  
;  jsr hexdump
;check_pattern_error:
;  jmp check_pattern_error

;sd_v1_init:
;  PUTS SD_V1_INIT

;sd_init:

  ; We have now initialized t TODO
  ldx #200
sd_init_loop:
  SET_CMD_FIELDS 55, 0, 0
  jsr sd_cmd

  ; NOTE: We re-use the previous cmd buffer which is correct  _other_
  ; than the HCS bit. However, we're not going to support SDHC/SDXC
  ; so we DO NOT want it set _anyway_, so it all works out :D
  lda #($40 | 41)
  sta SD_CMD

  jsr sd_cmd
  beq sd_init_done

  dex
  bne sd_init_loop

  PUTS SD_INIT_V1_FAIL
  sec
  rts

sd_init_done:
  PUTS SD_INIT_V1_SUCCESS

  ; CMD58: Read the Operations Condition Register (OCR)
  ; pre-set the command and flag, we'll need to re-adjust the
  ; SD_ARG field every time through the loop, but these can
  ; be set once and re-used
  lda #($40 | 58)
  sta SD_CMD

  lda #SD_FLG_RSP
  sta SD_FLG

send_cmd58:
  lda #0
  sta SD_ARG
  sta SD_ARG+1
  sta SD_ARG+2
  sta SD_ARG+3

  PUTS SEND_CMD58
  jsr sd_cmd

  lda SD_ARG
  ; CMD58 reads OCR in to SD_ARG
  ; top bit is 0 when SD is busy
  bpl send_cmd58

  PUTS SD_READY
  clc
  rts


SD_MISO = $01
SD_MOSI = $80
SD_SCLK = $40

; active low
SD_CSB  = $01



; func sd_wait_ready
;
; Waits until SD sends us $ff
sd_wait_ready:
  pha
  phx
  ;PUTS SD_WAIT_READY

  ldx #200
sd_wait_ready_loop:
  jsr sd_read_byte

  cmp #$ff
  beq sd_is_ready

  dex
  bne sd_wait_ready_loop

  PUTS SD_FAIL_WAIT

sd_fail_wait:
  jmp sd_fail_wait

sd_is_ready:
  plx
  pla
  rts


; func sd_read_byte
;
; Reads a byte in to accumulator
sd_read_byte:
  phx
  phy

  ;PUTS SD_READ_BYTE

  ldy #SD_MOSI
  sty PA2

  ; TODO: Initilize a with 1 then use branch until rol rotates
  ; the 1 in to the carry flag. This gets rid of the need for the
  ; x register and the dex
  lda #1
sd_readb_loop:
  ldy #(SD_MOSI | SD_SCLK)
  sty PA2

  tay
  lda PA2
  ror
  tya
  rol

  ; Toggle our clock
  ldy #SD_MOSI
  sty PA2

  bcc sd_readb_loop

  ply
  plx
  rts


; func sd_write_byte
sd_write_byte:
  phx
  phy

  ;PUTS SD_WRITE_BYTE

  ldx #8
sd_bit_loop:
  tay

  and #SD_MOSI
  sta PA2
  ora #SD_SCLK
  sta PA2

  and #~SD_SCLK
  sta PA2

  tya
  rol

  dex
  bne sd_bit_loop

  ply
  plx
  rts


; func sd_cmd
sd_cmd:
  phx
  phy

  ; Bring the enable line low, ie. select it
  ldx #0
  stx PB2

  ; TODO: only if needed
  jsr sd_wait_ready

  ;PUTS SD_CMDS

  lda SD_CMD
  jsr sd_write_byte

  lda SD_ARG
  jsr sd_write_byte

  lda SD_ARG+1
  jsr sd_write_byte

  lda SD_ARG+2
  jsr sd_write_byte

  lda SD_ARG+3
  jsr sd_write_byte

  lda SD_CRC
  jsr sd_write_byte

  ;PUTS READ_STATUS

  ldx #200
sd_cmd_wait_status:
  jsr sd_read_byte
  ora #0

  bpl read_status_ok

  dex
  bne sd_cmd_wait_status

  PUTS READ_STATUS_FAIL
;read_status_fail:
  ;jmp read_status_fail
  pha
  jmp sd_cmd_done

read_status_ok:
  ; Save off R1 response
  ;PUTS READ_STATUS_OK
  pha

  ; Check if we have an R3/R7 response following
  ; the R1 response we already received
  lda SD_FLG
  and #SD_FLG_RSP
  beq sd_check_data

  jsr sd_read_byte
  sta SD_ARG

  jsr sd_read_byte
  sta SD_ARG+1

  jsr sd_read_byte
  sta SD_ARG+2

  jsr sd_read_byte
  sta SD_ARG+3

  ; No commands have both R3/R7 _and_ data
  jmp sd_cmd_done

sd_check_data:
  lda SD_FLG
  and #SD_FLG_DTA
  beq sd_cmd_done

  ; Wait for SD data token
sd_wait_data_token:
  jsr sd_read_byte
  cmp #$fe
  bne sd_wait_data_token

  ;PUTS READING_BYTES

  ; R1 contains data pointer
  ; R2 contains size
  ; First iteration through the loop reads the "remainder"
  ; Later iterations always read 256 bytes at a time

  ; Check if we have > 255 bytes
  lda R2+1
  beq sd_read_remainder

  ldy #0
sd_read_data_loop1:
  jsr sd_read_byte
  sta (R1),y

  iny
  bne sd_read_data_loop1

  inc R1+1
  dec R2+1
  beq sd_read_remainder

  ;PUTS READ_BLOCK

  ldy #0
  jmp sd_read_data_loop1

sd_read_remainder:
  ;PUTS READING_REMAINDER

  ldx R2
  beq sd_cmd_done

  ldy #0
sd_read_data_loop2:
  lda #$01
  jsr lcd_cmd

  lda R1
  jsr print_hex
  lda R1+1
  jsr print_hex

  lda #" "
  jsr lcd_data

  tya
  jsr print_hex

  lda #" "
  jsr lcd_data

  jsr sd_read_byte
  sta (R1),y

  jsr print_hex

  lda #75
  jsr delayms

  iny
  dex
  bne sd_read_data_loop2

;dummy:
  ;jmp dummy

  ; Must read CRC, even though we don't check it
  jsr sd_read_byte
  jsr sd_read_byte

sd_cmd_done:
  ; stop selecting this device
  lda #SD_CSB
  sta PB2

  ; Ensure SD card de-asserts the bus
  ;lda #$ff
  ;jsr sd_write_byte

  ; Load saved R1 response
  pla

  ply
  plx

  ; Set N/Z flags based on a. ply/plx overwrite them
  ora #0
  rts

READING_BYTES
  .asciiz "Gathering data"

READ_BLOCK
  .asciiz "Read a block"

READING_REMAINDER
  .asciiz "Reading remaind."

READ_STATUS
  .asciiz "Reading SD status"

READ_STATUS_OK
  .asciiz "Read status ok"

READ_STATUS_FAIL
  .asciiz "Read status failed"

NO_SDCARD
  .asciiz "No SD card found!"

FOUND_SDCARD
  .asciiz "Found SD. Woohoo!"

SD_FAIL_WAIT
  .asciiz "SD failed wait"

SD_INIT
  .asciiz "Init. SD card"

CMD_ERROR:
  .asciiz "Command failed"

SEND_CMD0:
  .asciiz "Sending CMD0"

SEND_CMD8:
  .asciiz "Sending CMD8"

SEND_CMD16:
  .asciiz "Sending CMD16"

SEND_CMD17:
  .asciiz "Sending CMD17"

SEND_CMD58:
  .asciiz "Sending CMD58"

SD_V2_INIT:
  .asciiz "SDVER2 init"

SD_V1_INIT:
  .asciiz "SDVER1 init"

SD_INIT_V1_SUCCESS:
  .asciiz "SD init success"

SD_INIT_V1_FAIL:
  .asciiz "SD init failure"

SD_CMDS
  .asciiz "Sending SD cmd"

SD_READ_BYTE
  .asciiz "Reading byte"

SD_WRITE_BYTE
  .asciiz "Writing byte"

SD_WAIT_READY
  .asciiz "Waiting for SD card to be ready"

SD_READY
  .asciiz "SD is ready"

SD_CHECK_PATTERN_ERROR
  .asciiz "Check pattern error"

HEX
  .text "0123456789ABCDEF"

; vim: syntax=asm6502
