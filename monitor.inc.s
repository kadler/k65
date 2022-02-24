; Basic Monitor through ACIA
;
; Supports the following functions:
; - status - print registers (unimplemented)
; - dump - dump and display memory (unimplemented)
; - write - write data to memory (unimplemented)
; - load - load a program (unimplemented)
; - xload - load a program via XMODEM (unimplemented)

; SPDX-License-Identifier: GPL-3.0-or-later

  .ifndef MONITOR_INC
MONITOR_INC = 1


command_load:
  lda #<LOAD
  sta R1
  lda #>LOAD
  sta R1+1
  jsr acia_puts

  rts

command_xload:
  lda #<XLOAD
  sta R1
  lda #>XLOAD
  sta R1+1
  jsr acia_puts

  rts

command_status:
  lda #<STATUS
  sta R1
  lda #>STATUS
  sta R1+1
  jsr acia_puts

  rts

command_write:
  lda #<WRITE
  sta R1
  lda #>WRITE
  sta R1+1
  jsr acia_puts

  rts

command_dump:
  lda #<DUMP
  sta R1
  lda #>DUMP
  sta R1+1
  jsr acia_puts

  rts


; func strcmp
; compares two strings until the first ends (by NUL byte) or
; a difference is found
;
; inputs:
;  - #R1 - str 1
;  - #R2 - str 2
; outputs:
;  - %C - set on error
strcmp:
  pha
  phy

  ldy #0
.loop:
  lda (R1),y
  beq .done
  cmp (R2),y
  bne .error
  iny
  jmp .loop

.done:
  ply
  pla
  clc
  rts

.error:
  ply
  pla
  sec
  rts


; func find_command
; inputs:
;  - #R2 - command text received
; outputs:
;  - #R1 - command routine address
;  - %C - set on error
find_command:
  ; save x
  phx
  phy

  ldx #COMMAND_TABLE_COUNT
  ldy #0

  lda #<COMMAND_NAME_LIST
  sta R1
  lda #>COMMAND_NAME_LIST
  sta R1+1
.loop:
  jsr strcmp
  bcc .done

  dex
  beq .error

  iny

  clc
  lda R1
  adc #8
  sta R1
  lda R1+1
  adc #0
  sta R1+1
  jmp .loop

.done:
  lda COMMAND_ADDRESS_LOW_LIST,y
  sta R1
  lda COMMAND_ADDRESS_HIGH_LIST,y
  sta R1+1

  plx
  ply
  clc
  rts

.error:
  plx
  ply
  sec
  rts


COMMAND_TABLE_COUNT = 5

COMMAND_ADDRESS_HIGH_LIST:
  .byte >command_load
  .byte >command_xload
  .byte >command_status
  .byte >command_write
  .byte >command_dump

COMMAND_ADDRESS_LOW_LIST:
  .byte <command_load
  .byte <command_xload
  .byte <command_status
  .byte <command_write
  .byte <command_dump

COMMAND_NAME_LIST:
  ; table format: 2 byte address, string padded with zeroes to 8
  ; each entry is 10 bytes

  .text "load"
  .byte $0d
  .blk 3

  .text "xload"
  .byte $0d
  .blk 2

  .text "status"
  .byte $0d
  .blk 1

  .text "write"
  .byte $0d
  .blk 2

  .text "dump"
  .byte $0d
  .blk 3

LOAD
  .asciiz "LOAD"
XLOAD
  .asciiz "XLOAD"
STATUS
  .asciiz "STATUS"
DUMP
  .asciiz "DUMP"
WRITE
  .asciiz "WRITE"

  .endif
