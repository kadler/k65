; LCD functions for Ben Eater's 6502 computer kit

; SPDX-License-Identifier: GPL-3.0-or-later

  .ifndef SDIO_INC
SDIO_INC = 1


SD_CMD = $0200
SD_ARG = $0201
SD_CRC = $0205
SD_FLG = $0206

SD_TMP = $0207

SD_DTA = $0300 ; Page aligned for ease of use

SD_FLG_RSP = $80
SD_FLG_DTA = $40

ERR_SRC_SDIO = 1

ERR_NO_SD = 1
ERR_SD_WAIT_FAIL = 2
ERR_SD_SET_BLK_SIZE = 3
ERR_SD_CHK_PAT = 4
ERR_SD_READ_BLK = 5
ERR_SD_DTA_TKN = 6

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


hexdump:

  ; Move to line 2
  lda #$C0
  jsr lcd_cmd
  
  ldy #4
hex_loop:
  lda SD_DTA,y
  jsr print_hex

  ; iny
  ; cpy #4
  ; bne hex_loop
  dey
  bpl hex_loop

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
.send_cmd0:
  jsr sd_cmd
  cmp #1
  beq .cmd0_done

  dex
  bne .send_cmd0

  jmp .no_sd_found

.cmd0_done:
  ; Once in idle state, we must send CMD8 to do V2 init
  ; TODO: We don't plan on doing V2 init, so do we even need
  ; to send this?
  SET_CMD_FIELDS_CRC 8, $01aa, SD_FLG_RSP, $87
  jsr sd_cmd

  ;cmp #$01
  ;beq sd_v2_init

  ;cmp #$04
  ;bmi sd_v1_init

;sd_v2_init:
;  ; NOTE: We are not going to support high-capacity mode
;  ; so we're going to init as a v1 card

;  lda SD_ARG+3
;  cmp #$aa
;  beq sd_init

; lda #ERR_SD_CHK_PAT
; sta ERR_COD
; sec
; rts

;sd_v1_init:

;sd_init:

  ; We have now initialized t TODO
  ldx #200
.init_loop:
  SET_CMD_FIELDS 55, 0, 0
  jsr sd_cmd

  ; NOTE: We re-use the previous cmd buffer which is correct  _other_
  ; than the HCS bit. However, we're not going to support SDHC/SDXC
  ; so we DO NOT want it set _anyway_, so it all works out :D
  lda #($40 | 41)
  sta SD_CMD

  jsr sd_cmd
  beq .init_done

  dex
  bne .init_loop

  sec
  rts

.init_done:
  ; CMD58: Read the Operations Condition Register (OCR)
  ; pre-set the command and flag, we'll need to re-adjust the
  ; SD_ARG field every time through the loop, but these can
  ; be set once and re-used
  lda #($40 | 58)
  sta SD_CMD

  lda #SD_FLG_RSP
  sta SD_FLG

.send_cmd58:
  lda #0
  sta SD_ARG
  sta SD_ARG+1
  sta SD_ARG+2
  sta SD_ARG+3

  jsr sd_cmd

  lda SD_ARG
  ; CMD58 reads OCR in to SD_ARG
  ; top bit is 0 when SD is busy
  bpl .send_cmd58

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
  bne .set_block_size_error

  clc
.done:
  rts

.error:
  lda #ERR_SRC_SDIO
  sta ERR_SRC
  sec
  jmp .done

.set_block_size_error:
  lda #ERR_SD_SET_BLK_SIZE
  sta ERR_COD
  jmp .error

.no_sd_found:
  lda #ERR_NO_SD
  sta ERR_COD
  jmp .error


; R1 = destination address
; R2 = source sector
sd_read_sector:
  ; Read block
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
  lda #ERR_SRC_SDIO
  sta ERR_SRC
  lda #ERR_SD_READ_BLK
  sta ERR_COD
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

  ldx #200
sd_wait_ready_loop:
  jsr sd_read_byte

  cmp #$ff
  beq .ok

  dex
  bne sd_wait_ready_loop

  lda #ERR_SD_WAIT_FAIL
  sta ERR_COD
  sec
  jmp .done

.ok:
  clc

.done:
  plx
  pla
  rts


; func sd_read_byte
;
; Reads a byte in to accumulator
sd_read_byte:
  phx
  phy

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

  ldx #200
.wait_status_ok:
  jsr sd_read_byte
  ora #0

  bpl .status_ok

  dex
  bne .wait_status_ok

  pha
  jmp .done

.status_ok:
  ; Save off R1 response
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

  ; Wait for SD data token
.wait_data_token:
  jsr sd_read_byte
  bpl .data_token_error

  cmp #$fe
  bne .wait_data_token

  ; R1 contains data pointer
  ; R2 contains size
  ; First iteration through the loop reads the "remainder"
  ; Later iterations always read 256 bytes at a time

.read_data:
  ; Check if we have a remainder
  lda R2
  beq .read_page

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

.data_token_error:
  lda #ERR_SRC_SDIO
  sta ERR_SRC
  lda #ERR_SD_DTA_TKN
  sta ERR_COD
  jmp .done

SD_CHECK_PATTERN_ERROR
  .asciiz "Check pattern error"

  .endif

; vim: syntax=asm6502
