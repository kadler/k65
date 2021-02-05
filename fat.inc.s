; FAT16 & MBR routines

; SPDX-License-Identifier: GPL-3.0-or-later

  .ifndef FAT_INC
FAT_INC = 1

  .include lcd.inc.s
  .include delay.inc.s
  .include sdio.inc.s


FAT_DATA = $0400

PUTS_BUFFER = $0210

FAT_ADDRESS = $0300
DIR_ADDRESS = $0302
DTA_ADDRESS = $0304
ADDR_TEMP = $030a

PTE1 = 446

ERR_FAT_FOO = 3

fat16_init:
  jsr sd_init
  bcs .error_2

  ; Read in the Master Boot Record (MBR) in sector 0
  lda #<FAT_DATA
  sta R1
  lda #>FAT_DATA
  sta R1+1

  stz R2
  stz R2+1
  
  jsr sd_read_sector
  bcs .read_mbr_error

  ; ---- MBR Header ----
  ; 512 bytes always at sector 0
  ;
  ; 0    217  (bytes)  bootstrap code pt 1
  ; 218  223           timestamp
  ; 224  439  (bytes)  bootstrap code pt 2
  ; 440  443  (uint)   disk signature
  ; 444  445  (ushort) disk protected
  ; 446  461  partition 1 header
  ; 462  477  partition 2 header
  ; 478  493  partition 3 header
  ; 494  509  partition 4 header
  ; 510  511  boot signature
  ;
  ; https://en.wikipedia.org/wiki/Master_boot_record
  ;
  ; To make things simple, we ignore most of these fields
  ; We really only need the partition 1 header info as we'll
  ; be ignoring the other partitions
  ;
  ; We should maybe check boot signature, though
  ; TODO: Check booot signature @ index 64/65?

  ; To find the partion, we need to look in Partition 1's
  ; Parition Table Entry
  ;
  ; --- Partition Table Entry ---
  ;
  ; 0    0  (byte)   partition status
  ; 1    3  (bytes)  CHS address of first sector
  ; 4    4  (byte)   partition type
  ; 5    7  (bytes)  CHS address of last sector
  ; 8   11  (uint)   LBA address of first sector
  ; 12  15  (uint)   number of sectors
  ;
  ; Like the MBR Header, we're going to ignore most of
  ; these fields:
  ;
  ; - Maybe should validate status is not inactive (0x00 or 0x80)
  ;
  ; - Don't care about partition type. Maybe could check
  ;   that it's 6 (FAT16)
  ;
  ; - We ignore the CHS addresses and instead use the LBA
  ;   offset
  ; TODO: Check partition status @ 0 is 0 or >= 0x80?
  ; TODO: Check that partition type is 6 (FAT16)?

  ; Read FAT Boot sector from the partition's starting sector
  ; We can only read the first 65536 sectors in this code
  ; 32MiB should be enough for anyone, right?
  lda FAT_DATA + PTE1 + 10
  bne .partition_offset_error
  lda FAT_DATA + PTE1 + 11
  bne .partition_offset_error

  ; NOTE: We need to push R2 on to the stack for later, since
  ; sd_read_sector overwrites it.
  lda FAT_DATA + PTE1 + 8
  sta R2
  pha
  lda FAT_DATA + PTE1 + 9
  sta R2+1
  pha
  
  lda #<FAT_DATA
  sta R1
  lda #>FAT_DATA
  sta R1+1

  jsr sd_read_sector

  ; Need to pop R2 from the stack now in case we branch
  pla
  sta R2
  pla
  sta R2+1

  bcs .read_fs_header_error

  ; We now have the FAT16 filesystem header in memory
  ; We need to read various fields from it to do some
  ; validation as well as cache various info for later
  ; use, such as addresses to the FAT, start of data,
  ; and the root directory entries
  ;
  ; --- FAT16 FS Header ---
  ;
  ; 0     2  (bytes)   jump instruction
  ; 3    10  (bytes)   OEM name
  ; 11   12  (ushort)  bytes per sector
  ; 13   13  (byte)    sectors per cluster
  ; 14   15  (ushort)  number of reserved sectors
  ; 16   16  (byte)    number of FATs
  ; 17   18  (ushort)  max dir entries
  ; 19   20  (ushort)  total sectors
  ; 21   21  (byte)    media type
  ; 22   23  (ushort)  sectors per FAT
  ; 24   25  (ushort)  sectors per track
  ; 26   27  (ushort)  number of heads
  ; 28   31  (uint)    number of hidden sectors
  ; 32   35  (uint)    total sectors (if > 65535)
  ; 36   36  (byte)    logical drive number
  ; 37   37  (byte)    reserved
  ; 38   38  (byte)    extended signature
  ; 39   42  (uint)    volume id / serial number
  ; 43   53  (bytes)   volume label
  ; 54   61  (bytes)   filesystem type
  ; 62  509  (bytes)   bootstrap code
  ; 510 511  (ushort)  signature

  ; Validate signature is $55aa
  lda FAT_DATA+510
  cmp #$55
  bne .invalid_signature_error
  lda FAT_DATA+511
  cmp #$aa
  bne .invalid_signature_error

  ; Ensure 512 bytes per sector
  lda FAT_DATA+11
  bne .sector_size_error
  lda FAT_DATA+12
  cmp #2
  bne .sector_size_error

  ; Ensure 1 sector per cluster
  lda FAT_DATA+13
  cmp #1
  bne .cluster_size_error

  ; Determine the address of the FAT. After the FAT16 header is reserved
  ; sectors and following that is the FAT. So we add the number of reserved
  ; sectors to the header address and save this in FAT_ADDRESS for later use
  clc
  lda R2+1
  adc FAT_DATA+14
  sta FAT_ADDRESS
  lda R2
  adc FAT_DATA+15
  sta FAT_ADDRESS+1

  ; Determine the address of the root directory entries, which is stored
  ; immediately following the FAT

  ; Start the DIR_ADDRESS at the FAT_ADDRESS for now
  lda FAT_ADDRESS
  sta DIR_ADDRESS
  lda FAT_ADDRESS+1
  sta DIR_ADDRESS+1

  ; Load the number of fats and add the number of sectors per fat
  ; to the FAT_ADDRESS that many times.
  ; ie. dir address = fat address + (number of fats * sectors per fat)

  ; NOTE: We can clear the carry bit outside the loop for adding the
  ; low byte, because we ensure the carry bit is not set after adding
  ; the high byte
  clc

  ldx FAT_DATA+16
.fat_size_loop:
  lda DIR_ADDRESS
  adc FAT_DATA+22
  sta DIR_ADDRESS

  lda DIR_ADDRESS+1
  adc FAT_ADDRESS+23
  sta DIR_ADDRESS+1
  bcs .fat_size_error

  dex
  bne .fat_size_loop

  ; Determine the address of the data section
  ; The data section immediately follows the root directory entries
  ; Bytes 17-18 of the FAT16 header contain the max number of root
  ; directory entries. These entries are 32-bytes in size, so there are
  ; 16 (512/32) entries per sector. Thus, we divide the number of directory
  ; entries by 16 to get the number of sectors, using a 4 iteration loop
  ; to shift both bytes by 4 bits which is equivalent to divide by 16.
  ; We do this in-place, since we don't use this value again.
  ldx #4
.dir_size_loop:
  lda FAT_DATA+18
  lsr
  sta FAT_DATA+18
  lda FAT_DATA+17
  ror
  sta FAT_DATA+17

  dex
  bne .dir_size_loop

  ; Add the number of sectors used by directory entries to the address of
  ; the directory entry to get the data address.
  clc
  lda DIR_ADDRESS
  adc FAT_DATA+17
  sta DTA_ADDRESS
  lda DIR_ADDRESS+1
  adc FAT_DATA+18
  sta DTA_ADDRESS+1


.done:
  clc
  rts

.error:
  lda #1
  sta ERR_SRC

  sec
.error_2:
  rts

.partition_offset_error:
  lda #1
  sta ERR_COD
  jmp .error

.partition_offset_error1:
  lda #2
  sta ERR_COD
  jmp .error

.sector_size_error:
  lda #3
  sta ERR_COD
  jmp .error

.cluster_size_error:
  lda #4
  sta ERR_COD
  jmp .error

.read_mbr_error:
  lda #5
  sta ERR_COD
  jmp .error

.read_fs_header_error:
  lda #6
  sta ERR_COD
  jmp .error

.read_prg_eror:
  lda #7
  sta ERR_COD
  jmp .error

.invalid_signature_error:
  lda #9
  sta ERR_COD
  jmp .error

.fat_size_error:
  lda #10
  sta ERR_COD
  jmp .error


; Load the first program found in the root directory,
; returning the load address in R1
;
; Ultimately, this should be separated in to multiple
; functions:
; - get a directory listing
; - load a given program based on a directory listing
;
; Some current limitations:
; - only reads the first sector of directory entries,
;   limiting it to the first 16 entries
; - does no checking that the file type .PRG
; - only reads the first sector of the file, leading
;   to a file size limitation of < 512 bytes
;
fat16_load_prg:
  ; Read first 16 directory entries
  lda #<FAT_DATA
  sta R1
  lda #>FAT_DATA
  sta R1+1

  lda DIR_ADDRESS
  sta R2
  lda DIR_ADDRESS+1
  sta R2+1
  
  jsr sd_read_sector
  bcs .not_found_error

  ; X is the entry number, Y is the entry offset
  ldx #16
  ldy #0
.dir_loop:
  ; --- FAT Directory Entry ---
  ;
  ;  0   7  (bytes)  file name
  ;  8  10  (bytes)  extension
  ; 11  11  (byte)   attributes
  ; 12  21  (bytes)  os-specific attributes
  ; 22  23  (ushort) modified time
  ; 24  25  (ushort) modified date
  ; 26  27  (ushort) starting file cluster
  ; 28  31  (uint)   file size
  ;
  ; - First byte of filename is special marker:
  ;   * 0x00 - this entry and later entries are available (can stop checking)
  ;   * 0x2e - dot entry . or ..
  ;   * 0xe5 - entry is available (erased)
  ;
  ; - Attributes:
  ;   * 0x01 - read only
  ;   * 0x02 - hidden
  ;   * 0x04 - system file
  ;   * 0x08 - volume label
  ;   * 0x10 - subdirectory
  ;   * 0x20 - archive
  ;   * 0x40 - device
  ;
  ; - If attributes is 0x0f, entry is a long file name entry
  ;   which we're going to skip - don't want to deal with UCS-2

  ; If file name starts with NUL, it's the last entry
  lda FAT_DATA,y
  beq .not_found_error
  cmp #$2e
  beq .dir_loop_next
  cmp #$e5
  beq .dir_loop_next

  lda FAT_DATA+11,y
  cmp #$0f
  beq .dir_loop_next

  ; If it's a volume label, subdirectory, or device - skip
  and #($08 | $10 | $40)
  bne .dir_loop_next

  ; Skip files that are too big. The file size is a 32-bit value,
  ; but the address space is 16-bits, so anything with the high
  ; 2 bytes set is invalid. In addition, we only have a 32k RAM
  ; and not all of that is usable for program data: 1 page is
  ; used for the zero page, 1 page for stack, 1 page for I/O, and
  ; we also need to reserve pages for global and system data.
  ;
  ; Thus, we ensure that the size is less than 29k
  lda FAT_DATA+31,y
  bne .dir_loop_next
  lda FAT_DATA+30,y
  bne .dir_loop_next
  lda FAT_DATA+29,y
  cmp #$74
  ; < 29k is OK
  bmi .file_size_ok
  ; > 29k is BAD
  bne .dir_loop_next
  ; = 29k, check low byte is 0
  lda FAT_DATA+28,y
  bne .dir_loop_next


.file_size_ok:
  phx
  phy

  ; Need to loop over each byte of the file name and extension
  ; This would require adding 2 offsets to our FAT_DATA absolute
  ; address: offset to current entry and offset to current character
  ; The 6502 does not have such addressing modes, however, so we
  ; need to use indirect addressing by calculating the address
  ; to the directory entry, then using an offset from there.
  ; We could have done this for the rest of the loop too, but
  ; indirect addressing is slower so we only use it when necessary.
  ;
  ; R1 = FAT_DATA + y
  clc
  tya
  adc #<FAT_DATA
  sta R1
  lda #0
  adc #>FAT_DATA
  sta R1+1

  ; Copy the unpadded part of the file name
  ldy #0
  ldx #0
.name_loop:
  lda (R1),y
  cmp #' '
  beq .name_done
  sta PUTS_BUFFER,x
  inx
  iny
  cpy #8
  bne .name_loop

.name_done:
  lda #'.'
  sta PUTS_BUFFER,x
  inx

  ; Copy the unpadded part of the file extension
  ldy #8
.ext_loop:
  lda (R1),y
  cmp #' '
  beq .ext_done
  sta PUTS_BUFFER,x
  inx
  iny
  cpy #11
  bne .ext_loop

.ext_done:
  lda #0
  sta PUTS_BUFFER,x

  ply
  plx

  ; Print a loading message with the file name.
  ; Since the filename string could be up to 12 characters
  ; we put the filename on the second line
  lda #$01
  jsr lcd_cmd

  lda #<found_prg
  sta R1
  lda #>found_prg
  sta R1+1
  jsr puts

  lda #$C0
  jsr lcd_cmd

  lda #<PUTS_BUFFER
  sta R1
  lda #>PUTS_BUFFER
  sta R1+1

  jsr puts

  lda #250
  jsr delayms
  jsr delayms
  jsr delayms
  jsr delayms

  ; We've found our program, so break out of the loop
  jmp .dir_loop_done
.dir_loop_next:
  tya
  clc
  adc #32
  tay

  dex
  beq .not_found_error

  jmp .dir_loop
.dir_loop_done:

  ; Subtract 2 from starting file cluster, since the first two
  ; clusters contain the FAT id and the end of chain marker
  sec
  lda FAT_DATA+26,y
  sbc #2
  sta ADDR_TEMP
  lda FAT_DATA+27,y
  sbc #0
  sta ADDR_TEMP+1
  ; Starting cluster was invalid? (ie. < 2)
  bcc .cluster_number_error

  ; Add the starting cluster to the data address to get the
  ; starting sector number
  clc
  lda ADDR_TEMP
  adc DTA_ADDRESS
  sta ADDR_TEMP
  lda ADDR_TEMP+1
  adc DTA_ADDRESS+1
  sta ADDR_TEMP+1

  ; Read the first sector of data
  lda #<FAT_DATA
  sta R1
  lda #>FAT_DATA
  sta R1+1

  lda ADDR_TEMP
  sta R2
  lda ADDR_TEMP+1
  sta R2+1
  
  jsr sd_read_sector
  bcs .read_ldaddr_error

  ; Copy the program data to the load address stored in the
  ; first two bytes of the file
  lda #<(FAT_DATA+2)
  sta R1
  lda #>(FAT_DATA+2)
  sta R1+1

  lda FAT_DATA
  sta R2
  lda FAT_DATA+1
  sta R2+1

  ; copy first 256 bytes
  lda #0 ; 256
  jsr memcpy8_upd

  ; copy remaining 254 bytes (not 256 because load address takes first 2 bytes)
  lda #254
  jsr memcpy8_upd

  ; Return the load address in R1
  lda FAT_DATA
  sta R1
  jsr print_hex
  lda FAT_DATA+1
  sta R1+1
  jsr print_hex

.done:
  clc
  rts

.error:
  lda #1
  sta ERR_SRC
  sec
  rts

.read_ldaddr_error:
  lda #6
  sta ERR_COD
  jmp .error

.cluster_number_error:
  lda #8
  sta ERR_COD
  jmp .error

.not_found_error:
  lda #20
  sta ERR_COD
  jmp .error


; Copy up to 256 bytes from R1 in to R2
; Afterward, R1 & R2 will be incremented based on the
; size passed in.
;
; R1: source address
; R2: destination address
; a:  size
memcpy8_upd:
  pha
  phx
  phy

  tax
  ldy #0
.loop:
  lda (R1),y
  sta (R2),y

  iny
  dex
  bne .loop

  ; Update R1 and R2 based on the copy amount
  ; 0 = 256, which breaks the math so we special
  ; case it
  tya
  beq .add_256
  clc
  adc R2
  sta R2
  lda #0
  adc R2+1
  sta R2+1

  tya
  clc
  adc R1
  sta R1
  lda #0
  adc R1+1
  sta R1+1
  jmp .done

.add_256:
  sec
  lda R2+1
  adc #0
  sta R2+1

  sec
  lda R1+1
  adc #0
  sta R1+1

.done:
  ply
  plx
  pla
  rts

found_prg:
  .asciiz 'Loading'

  .endif
