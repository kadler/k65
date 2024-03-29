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

XLOAD_FILENAME = $0701 ; to $070b

command_load:
  ; Parse the command string passed in to look for the end of the
  ; current token, ie. filename
  ldy #0
.loop
  lda (R2),y
  beq .done

  cmp #' '
  beq .done
  cmp #CR
  beq .done

  iny
  jmp .loop

.done:
  ; We "found" a token. If it's empty, nothing to do
  cpy #0
  beq .error

  ; We found a space or newline. In that case, insert a null-terminator
  ; so that we can pad it properly
  lda #0
  sta (R2),y

  ; Set up registers to call fat16_pad_filename
  MVR R1, R2
  LDRI R2, XLOAD_FILENAME
  jsr fat16_pad_filename
  bcs .error

  ; Print out a load message
  LDRI R1, LOAD_MSG
  jsr acia_puts
  jsr lcd_puts

  ; Try to initialize the FAT16 filesystem on the SD card
  jsr fat16_init
  bcs .error

  ; Re-load our padded filename to call fat16_load_prg
  LDRI R1, XLOAD_FILENAME

  jsr fat16_load_prg
  bcs .error

  jsr trampoline
  clc
  rts

.error:
  lda ERR_SRC
  jsr lcd_print_hex
  lda #' '
  jsr lcd_putc
  lda ERR_COD
  jsr lcd_print_hex
  sec
  rts


command_xload:
  lda #<XLOAD_MSG
  sta R1
  lda #>XLOAD_MSG
  sta R1+1
  jsr acia_puts

  jsr acia_getc

  jsr xmodem_rcv_prg
  bcs .error

  jsr trampoline
  clc
  rts

.error:
  rts

command_status:
  sta $f0
  stx $f1
  sty $f2
  php
  pla
  sta $f3
  tsx
  stx $f4

  lda #<STATUS_HEADER
  sta R1
  lda #>STATUS_HEADER
  sta R1+1
  jsr acia_puts

  lda $f0
  jsr acia_print_hex

  lda #' '
  jsr acia_putc

  lda $f1
  jsr acia_print_hex

  lda #' '
  jsr acia_putc

  lda $f2
  jsr acia_print_hex

  lda #' '
  jsr acia_putc

  lda $f4
  jsr acia_print_hex

  lda #' '
  jsr acia_putc

  ;jsr acia_print_hex

.n:
  lda $f3
  and #$80
  beq .no_n
  lda #'+'
  jsr acia_putc
  jmp .v

.no_n:
  lda #'-'
  jsr acia_putc

.v:
  lda #' '
  jsr acia_putc

  lda $f3
  and #$40
  beq .no_v
  lda #'+'
  jsr acia_putc
  jmp .d

.no_v:
  lda #'-'
  jsr acia_putc

.d:
  lda #' '
  jsr acia_putc

  lda $f3
  and #$08
  beq .no_d
  lda #'+'
  jsr acia_putc
  jmp .i

.no_d:
  lda #'-'
  jsr acia_putc

.i:
  lda #' '
  jsr acia_putc

  lda $f3
  and #$04
  beq .no_i
  lda #'+'
  jsr acia_putc
  jmp .z

.no_i:
  lda #'-'
  jsr acia_putc

.z:
  lda #' '
  jsr acia_putc

  lda $f3
  and #$02
  beq .no_z
  lda #'+'
  jsr acia_putc
  jmp .c

.no_z:
  lda #'-'
  jsr acia_putc

.c:
  lda #' '
  jsr acia_putc

  lda $f3
  and #$01
  beq .no_c
  lda #'+'
  jsr acia_putc
  jmp .end

.no_c:
  lda #'-'
  jsr acia_putc

.end:
  lda #$0d
  jsr acia_putc

  lda #$0a
  jsr acia_putc

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

  ldx #0

  lda #<COMMAND_NAME_LIST
  sta R1
  lda #>COMMAND_NAME_LIST
  sta R1+1
.commands_loop:

  ldy #0
.loop
  ; If we found a null terminator, we've found a potential match
  lda (R1),y
  beq .matches

  ; If the other string doesn't match, go to the next command
  cmp (R2),y
  bne .next_command

  iny
  jmp .loop


.next_command:
  inx
  cpx #COMMAND_TABLE_COUNT
  beq .error

  clc
  lda R1
  adc #8
  sta R1
  lda R1+1
  adc #0
  sta R1+1
  jmp .commands_loop

.matches:
  ; We got a potential match on the command. Now check that
  ; there is a following space or newline. eg.
  ; "xload\r"       matches "xload" OK
  ; "xloadfoo\r"    matches "xload" ERR
  ; "load foo\r"    matches "load" OK
  lda (R2),y
  cmp #' '
  beq .found
  cmp #CR
  beq .found

  jmp .error

.found:
  ; Bump the command string past the command for any further
  ; command string processing to be done by the command itself
  clc
  iny
  tya
  adc R2
  sta R2
  lda #0
  adc R2+1
  sta R2+1

  lda COMMAND_ADDRESS_LOW_LIST,x
  sta R1
  lda COMMAND_ADDRESS_HIGH_LIST,x
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
  .blk 4

  .text "xload"
  .blk 3

  .text "status"
  .blk 2

  .text "write"
  .blk 3

  .text "dump"
  .blk 4

STATUS_HEADER
  .asciiz " a  x  y sp n v d i z c"

XLOAD_MSG
  .asciiz "Start XMODEM transfer then press enter"

LOAD_MSG
  .asciiz "Loading program from SD"

DUMP
  .asciiz "DUMP"
WRITE
  .asciiz "WRITE"

  .endif
