; LCD functions for Ben Eater's 6502 computer kit

; SPDX-License-Identifier: GPL-3.0-or-later

SD_CMD = $0200
SD_ARG = $0201
SD_CRC = $0205
SD_FLG = $0206

SD_TMP = $0207

SD_DTA = $0300 ; Page aligned for ease of use

SD_FLG_RSP = $80
SD_FLG_DTA = $40

  .macro PUTS
  pha
  lda R1
  pha
  lda R1+1
  pha

  lda #<\1
  sta R1
  lda #>\1
  sta R1+1
  jsr puts2

  pla
  sta R1+1
  pla
  sta R1
  pla
  .endm

puts2:
  lda #$01
  jsr lcd_cmd
  jsr puts
  lda #250
  jsr delayms
  jsr delayms
  ; jsr delayms
  rts

  .macro DEBUG
  .ifdef VERBOSE
  PUTS \1
  .endif
  .endm

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
  DEBUG SD_INIT

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
  DEBUG SEND_CMD0
  jsr sd_cmd
  cmp #1
  beq cmd0_done

  dex
  bne send_cmd0

  DEBUG NO_SDCARD
  ; TODO: Carve out a memory location to serve as a status byte
  sec
  rts

cmd0_done:
  DEBUG FOUND_SDCARD

  ; Once in idle state, we must send CMD8 to do V2 init
  ; TODO: We don't plan on doing V2 init, so do we even need
  ; to send this?
  SET_CMD_FIELDS_CRC 8, $01aa, SD_FLG_RSP, $87

  DEBUG SEND_CMD8
  jsr sd_cmd

  ;cmp #$01
  ;beq sd_v2_init

  ;cmp #$04
  ;bmi sd_v1_init

;sd_v2_init:
;  ; NOTE: We are not going to support high-capacity mode
;  ; so we're going to init as a v1 card
;  DEBUG SD_V2_INIT

;  lda SD_ARG+3
;  cmp #$aa
;  beq sd_init

;  DEBUG SD_CHECK_PATTERN_ERROR
  
;  jsr hexdump
;check_pattern_error:
;  jmp check_pattern_error

;sd_v1_init:
;  DEBUG SD_V1_INIT

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

  DEBUG SD_INIT_V1_FAIL
  sec
  rts

sd_init_done:
  DEBUG SD_INIT_V1_SUCCESS

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

  DEBUG SEND_CMD58
  jsr sd_cmd

  lda SD_ARG
  ; CMD58 reads OCR in to SD_ARG
  ; top bit is 0 when SD is busy
  bpl send_cmd58

  ; Set block size to 512 bytes
  lda #($40 | 16)
  sta SD_CMD

  stz SD_ARG
  stz SD_ARG+1
  lda #>512
  sta SD_ARG+2
  stz SD_ARG+3
  
  stz SD_FLG

  jsr sd_cmd


  DEBUG SD_READY
  clc
  rts


; R1 = destination address
; R2 = source sector
sd_read_sector:
  ; Read block
  ; SET_CMD_FIELDS 17, (R4)<<16|(R3), SD_FLG_DTA
  lda #($40 | 17)
  sta SD_CMD

  ; Convert 16-bit sector (512 byte) sector address
  ; to 32-bit byte address in to R3/R4
  ; Multiplying by 512 is shifting left by 9. We do
  ; the first 8 shifts by shifting the byte target
  ; and then shift left by 1. eg.
  ; Normal widening:
  ; R2 -> R3
  ; R2+1 -> R3+1
  ; 0 -> R4
  ; 0 -> R4+1
  ;
  ; Widening and multiplying:
  ; 0 -> R3
  ; R2 << 1 -> R3+1
  ; R2+1 << 1 -> R4
  ; 0 -> R4+1
  stz SD_ARG+3
  clc
  lda R2
  rol
  sta SD_ARG+2
  lda R2+1
  rol
  sta SD_ARG+1
  stz SD_ARG

  lda #SD_FLG_DTA
  sta SD_FLG

  stz R2
  lda #>512
  sta R2+1

  jsr sd_cmd
  bne .error

  clc
.done:
  rts

.error:
  sec
  ; lda #ERR_SRC_SDIO
  ; sta ERR_SRC
  ; lda #ERR_SD_READ_BLK
  ; sta ERR_COD
  jmp .done

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
  ;DEBUG SD_WAIT_READY

  ldx #200
sd_wait_ready_loop:
  jsr sd_read_byte

  cmp #$ff
  beq sd_is_ready

  dex
  bne sd_wait_ready_loop

  DEBUG SD_FAIL_WAIT

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

  ;DEBUG SD_READ_BYTE

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

  ;DEBUG SD_WRITE_BYTE

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

  ;DEBUG SD_CMDS

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

  ;DEBUG READ_STATUS
  ; PUTS READ_STATUS

  ldx #200
.wait_status_ok:
  jsr sd_read_byte
  ora #0

  bpl .status_ok

  dex
  bne .wait_status_ok

  DEBUG READ_STATUS_FAIL
;read_status_fail:
  ;jmp read_status_fail
  pha
  jmp .done

.status_ok:
  ; Save off R1 response
  ;DEBUG READ_STATUS_OK
  ; PUTS READ_STATUS_OK
  pha

  ; Check if we have an R3/R7 response following
  ; the R1 response we already received
  lda SD_FLG
  and #SD_FLG_RSP
  beq .check_data

  jsr sd_read_byte
  sta SD_ARG

  jsr sd_read_byte
  sta SD_ARG+1

  jsr sd_read_byte
  sta SD_ARG+2

  jsr sd_read_byte
  sta SD_ARG+3

  ; No commands have both R3/R7 _and_ data
  jmp .done

.check_data:
  lda SD_FLG
  and #SD_FLG_DTA
  beq .done

  ; PUTS READING_BYTES

  lda #$01
  jsr lcd_cmd
  lda #$0c
  jsr lcd_cmd
  ; Wait for SD data token
.wait_data_token:
  lda #$02
  jsr lcd_cmd

  jsr sd_read_byte

  jsr print_hex
  
  bpl .data_token_error

  cmp #$fe
  bne .wait_data_token

  jmp .read_data

.data_token_error:
  PUTS SD_CHECK_PATTERN_ERROR

  pha
  lda #$C0
  jsr lcd_cmd

  pla
  jsr print_hex
.debug:
  jmp .debug
  sec
  jmp .done 


  ;DEBUG READING_BYTES

  ; R1 contains data pointer
  ; R2 contains size
  ; First iteration through the loop reads the "remainder"
  ; Later iterations always read 256 bytes at a time

.read_data:
  ; Check if we have a remainder
  lda R2
  beq .read_page

  ;DEBUG READING_REMAINDER
  ; PUTS READING_REMAINDER

  ldx R2
  beq .done

  ldy #0
.read_remainder_byte:

  .ifdef VERBOSE
  lda #$01
  jsr lcd_cmd

  .if 0
  lda R1+1
  jsr print_hex
  lda R1
  jsr print_hex
  .else
  lda SD_ARG
  jsr print_hex
  lda SD_ARG+1
  jsr print_hex
  lda SD_ARG+2
  jsr print_hex
  lda SD_ARG+3
  jsr print_hex

  clc
  lda SD_ARG+3
  adc #1
  sta SD_ARG+3
  lda SD_ARG+2
  adc #0
  sta SD_ARG+2
  lda SD_ARG+1
  adc #0
  sta SD_ARG+1
  lda SD_ARG
  adc #0
  sta SD_ARG
  .endif

  lda #" "
  jsr lcd_data

  .if 0
  tya
  jsr print_hex

  lda #" "
  jsr lcd_data
  .endif
  .endif

  jsr sd_read_byte
  sta (R1),y

  .ifdef VERBOSE
  jsr putc

  pha
  lda #' '
  jsr putc
  pla

  jsr print_hex

  lda #200
  jsr delayms
  .endif

  iny
  dex
  bne .read_remainder_byte

  ; Remainder has been read, adjust address and size
  lda R1
  sec
  sbc R2
  sta R1
  lda R1
  sbc #0
  sta R1
  stz R2

  lda R2+1
  beq .read_done

  ; PUTS READ_BLOCK

.read_page:
  ldy #0
.read_byte:

  .ifdef VERBOSE
  lda #$01
  jsr lcd_cmd

  lda SD_ARG
  jsr print_hex
  lda SD_ARG+1
  jsr print_hex
  lda SD_ARG+2
  jsr print_hex
  lda SD_ARG+3
  jsr print_hex

  clc
  lda SD_ARG+3
  adc #1
  sta SD_ARG+3
  lda SD_ARG+2
  adc #0
  sta SD_ARG+2
  lda SD_ARG+1
  adc #0
  sta SD_ARG+1
  lda SD_ARG
  adc #0
  sta SD_ARG

  lda #" "
  jsr lcd_data
  .endif

  jsr sd_read_byte
  sta (R1),y

  .ifdef VERBOSE
  jsr putc

  pha
  lda #' '
  jsr putc
  pla

  jsr print_hex

  lda #100
  jsr delayms
  .endif

  iny
  bne .read_byte

  ; increment page poitner
  inc R1+1
  ; decrement page count
  dec R2+1
  ; if page count is not zero, read another page
  bne .read_page

.read_done:
;dummy:
  ;jmp dummy

  ; PUTS HEX

  ; Must read CRC, even though we don't check it
  jsr sd_read_byte
  jsr sd_read_byte

.done:
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
