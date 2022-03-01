; FAT16 & MBR routines

; SPDX-License-Identifier: GPL-3.0-or-later

  .ifndef FAT_INC
FAT_INC = 1

 ; Basic MBR and FAT16 implementation for 6502
 ; based off of information from
 ; - https://en.wikipedia.org/wiki/Master_boot_record
 ; - https://en.wikipedia.org/wiki/Design_of_the_FAT_file_system
 ; - https://www.win.tue.nl/~aeb/linux/fs/fat/fat-1.html
 ;
 ; PC-compatible disks traditionally use the Master Boot Record partitioning
 ; scheme, which contains data in the first 512-byte sector of the disk,
 ; including a parition table for 4 partitions. Each partition table entry
 ; contains an address to the start of the first sector of the partition.
 ;
 ; From there, we can address the FAT16 filesystem data.
 ;
 ; The basic overview of everything looks like this:
 ;
 ;   Master Boot Record
 ; +-------------------+
 ; | Bootstrap code    |            Partition Table Entry
 ; |      ...          |          / +-------------------+
 ; | Partition entry 1 | --+      | | Partition Status  |
 ; | Partition entry 2 |   |      | | CHS start address |
 ; | Partition entry 3 |   +---- <  | Parition type     |
 ; | Partition entry 4 |          | | CHS end address   |
 ; | Boot Signature    |          | | LBA start address | --+
 ; +-------------------+          | | Number of Sectors |   |
 ;                                \ +-------------------+   |
 ;                                                          |
 ;    +-----------------------------------------------------+
 ;    |
 ;    |                             FAT16 Boot Sector
 ;    +-------------------> +-----------------------------------+
 ;    |                     | Jump instruction                  |
 ;    |                     | OEM name                          |
 ;    |                     | Bytes per sector                  |
 ;    V                     | Sectors per cluster               |
 ;   (+)<------------------ | # reserved sectors                |
 ;    |    +--------------- | # of file allocation tables (FATs)|
 ;    |    |    +---------- | Maximum # root directory entries  |
 ;    |    |    |           | Total sectors                     |
 ;    |    V    |           | Media type                        |
 ;    |   (×)<------------- | Sectors per FAT                   |
 ;    |    |    |           | Sectors per track                 |
 ;    |    |    |           | # of heads                        |
 ;    |    |    |           | # of hidden sectors               |
 ;    |    |    |           | Total sectors (if > 65535)        |
 ;    |    |   (/)<-- 16    | Physical drive number             |
 ;    |    |    |           | Reserved                          |
 ;    |    |    |           | Extended boot signature           |
 ;    |    |    |           | Volume ID                         |
 ;    |    |    |           | Partition Volume Label            |
 ;    |    |    |           | File system type                  |
 ;    |    |    |           +-----------------------------------+
 ;    |    |    |
 ;    |    |    |
 ;    |    |    |
 ;    |    |    |                  File Allocation Table (FAT)
 ;    |    |    |                         Cluster Map
 ;    |    |    |                0         1         2         3
 ;    +-------------------> +---------+---------+---------+---------+      \
 ;    |    |    |           |         |         |         |         |      |
 ;    |    |    |        0  |  F0 FF  |  FF FF  |  00 00  |  04 00  |      |
 ;    |    |    |           |   (0)   |   (1)   |   (2)   |   (3)   |      |
 ;    |    |    |           +---------+---------+---------+---------+      |
 ;    |    |    |           |         |         |         |         |      |
 ;    |    |    |        1  |  05 00  |  FF FF  |  07 00  |  09 00  |      |
 ;    |    |    |           |   (4)   |   (5)   |   (6)   |   (7)   |      |
 ;    |    |    |           +---------+---------+---------+---------+      |
 ;    |    |    |           |         |         |         |         |      |
 ;    |    |    |        2  |  00 00  |  FF FF  |  00 00  |  00 00  |       > ------------+
 ;    |    |    |           |   (8)   |   (9)   |   (10)  |   (11)  |      |              |
 ;    V    |    |           +---------+---------+---------+---------+      |              |
 ;   (+)<--+    |           |         |         |         |         |      |              |
 ;    |         |        3  |  00 00  |  0e 00  |  10 00  |  0d 00  |      |              |
 ;    |         |           |   (12)  |   (13)  |   (14)  |   (15)  |      |              |
 ;    |         |           +---------+---------+---------+---------+      |              |
 ;    |         |           |         |         |         |         |      |              |
 ;    |         |        4  |  11 00  |  12 00  |  FF FF  |  0f 00  | <-+  |              |
 ;    |         |           |   (16)  |   (17)  |   (18)  |   (19)  |   |  |              |
 ;    |         |           +---------+---------+---------+---------+   |  /              |
 ;    |         |                           ...                         |                 |
 ;    |         |                                                       |                 |
 ;    |         |                                                       |                 |
 ;    |         |                                                       +--------------+  |
 ;    |         |            Root Directory Entries                                    |  |
 ;    +-------------------> +----------------------+              Directory Entry      |  |
 ;    |         |           | Directory Entry 1    |--+      / +-------------------+   |  |
 ;    |         |           | Directory Entry 2    |  |      | | File name         |   |  |
 ;    |         |           | Directory Entry 3    |  |      | | File extension    |   |  |
 ;    |         |           |        ...           |  +---- <  | Attributes        |   |  |
 ;    |         |           | Directory Entry 14   |         | | OS-specific attrs |   |  |
 ;    |         |           | Directory Entry 15   |         | | Modified Time     |   |  |
 ;    |         |           | Directory Entry 16   |         | | Modified Date     |   |  |
 ;    |         |           +----------------------+         | | Starting cluster  | --+->+
 ;    V         |           | Directory Entry 17   |         | | File Size         |      |
 ;   (+)<------(÷)<--16     | Directory Entry 18   |         \ +-------------------+      |
 ;    |                     | Directory Entry 19   |                                      |
 ;    |                     |        ...           |                                      |
 ;    |                     | Directory Entry 30   |                                      |
 ;    |                     | Directory Entry 31   |                                      |
 ;    |                     | Directory Entry 32   |                                      |
 ;    |                     +----------------------+                                      |
 ;    |                              ...                                                  |
 ;    |                                                                                   |
 ;    |                                                                                   |
 ;    |                          Start of Data                                            |
 ;    +-------------------> +----------------------+  \                                   |
 ;                          |      Cluster 1       |  |                                   |
 ;                          +----------------------+  |                                   |
 ;                          |      Cluster 2       |  |                                   |
 ;                          +----------------------+  |                                   |
 ;                          |      Cluster 3       |  |                                   |
 ;                          +----------------------+  |                                   |
 ;                          |      Cluster 4       |  |                                   |
 ;                          +----------------------+  |                                   |
 ;                          |        ...           |   > <--------------------------------+
 ;                          +----------------------+  |
 ;                          |      Cluster n-2     |  |
 ;                          +----------------------+  |
 ;                          |      Cluster n-1     |  |
 ;                          +----------------------+  |
 ;                          |      Cluster n       |  |
 ;                          +----------------------+  /
 ;
 ;
 ; The FAT contains a cluster map that forms linked lists of cluster numbers
 ; for each file in the filesystem. Each linked list contains the cluster
 ; numbers making up that file, with the starting cluster for the file
 ; being found from the directory entry.
 ;
 ; There are two reserved clusters:
 ;   - Cluster 0 is the FAT ID
 ;   - Cluster 1 is the end of chain marker (almost always $FFFF)
 ;  Cluster special values:
 ;   - $0000 - free cluster
 ;   - $FF7F - cluster is bad/damaged
 ; This above example has 3 cluster chains:
 ;   - 3 -> 4 -> 5
 ;   - 6 -> 7 -> 9
 ;   - 19 -> 15 -> 13 -> 14 -> 16 -> 17 -> 18
 ; The above example has 5 free clusters:
 ;   - 2
 ;   - 8
 ;   - 10
 ;   - 11
 ;   - 12

; Reserve 512 bytes for a full sector
SECTOR_DTA  = $0400
SECTOR_DTA2 = $0500

PUTS_BUFFER = $0210

FAT_ADDRESS = $0300
DIR_ADDRESS = $0302
DTA_ADDRESS = $0304
ADDR_TEMP = $030a

PTE1 = 446

ERR_SRC_FAT = 2

ERR_FAT_PART_OFF = $01
ERR_FAT_PART_OFF2 = $02
ERR_FAT_SECT_SIZE = $03
ERR_FAT_CLST_SIZE = $04
ERR_FAT_MBR = $05
ERR_FAT_FS_HDR = $06
ERR_FAT_READ_PRG = $07
ERR_FAT_INV_SIGN = $08
ERR_FAT_FAT_SIZE = $09
ERR_FAT_LOD_ADDR= $0a
ERR_FAT_CLST_NBR = $0b
ERR_FAT_NOT_FOUND = $0c

fat16_init:
  jsr sd_init
  bcs .error_2

  ; Read in the Master Boot Record (MBR) in sector 0
  lda #<SECTOR_DTA
  sta R1
  lda #>SECTOR_DTA
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
  lda SECTOR_DTA + PTE1 + 10
  bne .partition_offset_error
  lda SECTOR_DTA + PTE1 + 11
  bne .partition_offset_error

  ; NOTE: We need to push R2 on to the stack for later, since
  ; sd_read_sector overwrites it.
  lda SECTOR_DTA + PTE1 + 8
  sta R2
  pha
  lda SECTOR_DTA + PTE1 + 9
  sta R2+1
  pha
  
  lda #<SECTOR_DTA
  sta R1
  lda #>SECTOR_DTA
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
  lda SECTOR_DTA+510
  cmp #$55
  bne .invalid_signature_error
  lda SECTOR_DTA+511
  cmp #$aa
  bne .invalid_signature_error

  ; Ensure 512 bytes per sector
  lda SECTOR_DTA+11
  bne .sector_size_error
  lda SECTOR_DTA+12
  cmp #2
  bne .sector_size_error

  ; Ensure 1 sector per cluster
  lda SECTOR_DTA+13
  cmp #1
  bne .cluster_size_error

  ; Determine the address of the FAT. After the FAT16 header is reserved
  ; sectors and following that is the FAT. So we add the number of reserved
  ; sectors to the header address and save this in FAT_ADDRESS for later use
  clc
  lda R2+1
  adc SECTOR_DTA+14
  sta FAT_ADDRESS
  lda R2
  adc SECTOR_DTA+15
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

  ldx SECTOR_DTA+16
.fat_size_loop:
  lda DIR_ADDRESS
  adc SECTOR_DTA+22
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
  lda SECTOR_DTA+18
  lsr
  sta SECTOR_DTA+18
  lda SECTOR_DTA+17
  ror
  sta SECTOR_DTA+17

  dex
  bne .dir_size_loop

  ; Add the number of sectors used by directory entries to the address of
  ; the directory entry to get the data address.
  clc
  lda DIR_ADDRESS
  adc SECTOR_DTA+17
  sta DTA_ADDRESS
  lda DIR_ADDRESS+1
  adc SECTOR_DTA+18
  sta DTA_ADDRESS+1


.done:
  clc
  rts

.error:
  lda #ERR_SRC_FAT
  sta ERR_SRC

  sec
.error_2:
  rts

.partition_offset_error:
  lda #ERR_FAT_PART_OFF
  sta ERR_COD
  jmp .error

.partition_offset_error1:
  lda #ERR_FAT_PART_OFF2
  sta ERR_COD
  jmp .error

.sector_size_error:
  lda #ERR_FAT_SECT_SIZE
  sta ERR_COD
  jmp .error

.cluster_size_error:
  lda #ERR_FAT_CLST_SIZE
  sta ERR_COD
  jmp .error

.read_mbr_error:
  lda #ERR_FAT_MBR
  sta ERR_COD
  jmp .error

.read_fs_header_error:
  lda #ERR_FAT_FS_HDR
  sta ERR_COD
  jmp .error

.read_prg_eror:
  lda #ERR_FAT_READ_PRG
  sta ERR_COD
  jmp .error

.invalid_signature_error:
  lda #ERR_FAT_INV_SIGN
  sta ERR_COD
  jmp .error

.fat_size_error:
  lda #ERR_FAT_PART_OFF
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
  lda #<SECTOR_DTA
  sta R1
  lda #>SECTOR_DTA
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
  lda SECTOR_DTA,y
  beq .not_found_error
  cmp #$2e
  beq .dir_loop_next
  cmp #$e5
  beq .dir_loop_next

  lda SECTOR_DTA+11,y
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
  lda SECTOR_DTA+31,y
  bne .dir_loop_next
  lda SECTOR_DTA+30,y
  bne .dir_loop_next
  lda SECTOR_DTA+29,y
  cmp #$74
  ; < 29k is OK
  bmi .file_size_ok
  ; > 29k is BAD
  bne .dir_loop_next
  ; = 29k, check low byte is 0
  lda SECTOR_DTA+28,y
  bne .dir_loop_next


.file_size_ok:
  phx
  phy

  ; Need to loop over each byte of the file name and extension
  ; This would require adding 2 offsets to our SECTOR_DTA absolute
  ; address: offset to current entry and offset to current character
  ; The 6502 does not have such addressing modes, however, so we
  ; need to use indirect addressing by calculating the address
  ; to the directory entry, then using an offset from there.
  ; We could have done this for the rest of the loop too, but
  ; indirect addressing is slower so we only use it when necessary.
  ;
  ; R1 = SECTOR_DTA + y
  clc
  tya
  adc #<SECTOR_DTA
  sta R1
  lda #0
  adc #>SECTOR_DTA
  sta R1+1

  lda #<PUTS_BUFFER
  sta R2
  lda #>PUTS_BUFFER
  sta R2+1

  jsr fat16_unpad_filename

  ply
  plx

  ; Print a loading message with the file name.
  ; Since the filename string could be up to 12 characters
  ; we put the filename on the second line
  jsr lcd_clear

  lda #<found_prg
  sta R1
  lda #>found_prg
  sta R1+1
  jsr lcd_puts

  jsr lcd_line_two

  lda #<PUTS_BUFFER
  sta R1
  lda #>PUTS_BUFFER
  sta R1+1

  jsr lcd_puts

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
  lda SECTOR_DTA+26,y
  sbc #2
  sta ADDR_TEMP
  lda SECTOR_DTA+27,y
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
  lda #<SECTOR_DTA
  sta R1
  lda #>SECTOR_DTA
  sta R1+1

  lda ADDR_TEMP
  sta R2
  lda ADDR_TEMP+1
  sta R2+1
  
  jsr sd_read_sector
  bcs .read_ldaddr_error

  ; Copy the program data to the load address stored in the
  ; first two bytes of the file
  lda #<(SECTOR_DTA+2)
  sta R1
  lda #>(SECTOR_DTA+2)
  sta R1+1

  lda SECTOR_DTA
  sta R2
  lda SECTOR_DTA+1
  sta R2+1

  ; copy first 256 bytes
  lda #0 ; 256
  jsr memcpy8_upd

  ; copy remaining 254 bytes (not 256 because load address takes first 2 bytes)
  lda #254
  jsr memcpy8_upd

  ; Return the load address in R1
  lda SECTOR_DTA
  sta R1
  jsr lcd_print_hex
  lda SECTOR_DTA+1
  sta R1+1
  jsr lcd_print_hex

.done:
  clc
  rts

.error:
  lda #ERR_SRC_FAT
  sta ERR_SRC
  sec
  rts

.read_ldaddr_error:
  lda #ERR_FAT_LOD_ADDR
  sta ERR_COD
  jmp .error

.cluster_number_error:
  lda #ERR_FAT_CLST_NBR
  sta ERR_COD
  jmp .error

.not_found_error:
  lda #ERR_FAT_NOT_FOUND
  sta ERR_COD
  jmp .error



; func fat16_pad_filename
;
; Converts 8.3 format name FILENAME.EXT to FAT 11-byte padded name format FILENAMEEXT.
;
; inputs:
;  - #R1 - input string
;  - #R2 - output string
fat16_pad_filename:
  pha
  phy

  ; Copy the unpadded part of the file name, up to 8 characters
  ldy #0
.name_loop:
  lda (R1),y
  cmp #'.'
  beq .name_pad

  cmp #'a'
  bmi .name_store

  cmp #'{'
  bpl .name_store

  ; Lower case a-z found, convert to upper case
  and #~$20

.name_store:
  sta (R2),y
  iny
  cpy #8
  bne .name_loop
  jmp .name_done

.name_pad:
  ; save off y
  phy

.pad_loop:
  lda #' '
  sta (R2),y
  iny
  cpy #8
  bne .pad_loop

  ply

.name_done
  ; Make sure we found the dot
  lda (R1),y
  cmp #'.'
  bne .error

  ; Skip over dot
  iny

  ; Increment R1 and R2 registers for the extension
  ;
  ; For the destination string, it's always at R1+8, while the source string
  ; depends on how many characters were in the unpadded name, plus the period.
  ; This allows us to use the same loop counter for both source and dest,
  ; below. We can't use x, since x-indirect addressing works differently.
  clc
  lda R2
  adc #8
  sta R2
  lda R2+1
  adc #0
  sta R2+1

  ; Save off the destination offset, so we can restore R2 before returning
  tya
  pha
  clc
  adc R1
  sta R1
  lda R1+1
  adc #0
  sta R1+1

  ; Copy the unpadded part of the file extension, up to 3 characters
  ldy #0
.ext_loop:
  lda (R1),y
  cmp #0
  beq .ext_pad

  cmp #'a'
  bmi .ext_store

  cmp #'{'
  bpl .ext_store

  ; Lower case a-z found, convert to upper case
  and #~$20

.ext_store:
  sta (R2),y
  iny
  cpy #3
  bne .ext_loop
  jmp .ext_done

.ext_pad:
  lda #' '
  sta (R2),y
  iny
  cpy #3
  bne .ext_pad

.ext_done:
  ; Restore the original R2 value by subtracting the fixed offset
  sec
  lda R2
  sbc #8
  sta R2
  lda R2+1
  sbc #0
  sta R2+1

  ; Restore the original R1 value by subtracting the saved offset
  pla
  sec
  sbc R1
  sta R1
  lda R1+1
  sbc #0
  sta R1+1

  ply
  pla
  clc
  rts

.error:
  ; TODO: Check y is 8 and set an error code?
  ply
  pla
  sec
  rts


; func fat16_unpad_filename
;
; Converts FAT 11-byte padded name format FILENAMEEXT to 8.3 format
; FILENAME.EXT.
;
; inputs:
;  - #R1 - input string
;  - #R2 - output string
fat16_unpad_filename:
  pha
  phy

  ; Copy the unpadded part of the file name, up to 8 characters
  ldy #0
.name_loop:
  lda (R1),y
  cmp #' '
  beq .name_done

  sta (R2),y
  iny
  cpy #8
  bne .name_loop

.name_done:
  lda #'.'
  sta (R2),y
  iny


  ; Increment R1 and R2 registers for the extension
  ;
  ; For the source string, it's always at R1+8, while the destination string
  ; depends on how many characters were in the unpadded name, plus the period.
  ; This allows us to use the same loop counter for both source and dest,
  ; below. We can't use x, since x-indirect addressing works differently.
  clc
  lda R1
  adc #8
  sta R1
  lda R1+1
  adc #0
  sta R1+1

  ; Save off the destination offset, so we can restore R2 before returning
  tya
  pha
  clc
  adc R2
  sta R2
  lda R2+1
  adc #0
  sta R2+1

  ; Copy the unpadded part of the file extension, up to 3 characters
  ldy #0
.ext_loop:
  lda (R1),y
  cmp #' '
  beq .ext_done

  sta (R2),y
  iny
  cpy #3
  bne .ext_loop

.ext_done:
  lda #0
  sta (R2),y

  ; Restore the original R1 value by subtracting the fixed offset
  sec
  lda R1
  sbc #8
  sta R1
  lda R1+1
  sbc #0
  sta R1+1

  ; Restore the original R2 value by subtracting the saved offset
  pla
  sec
  sbc R2
  sta R2
  lda R2+1
  sbc #0
  sta R2+1

  ply
  pla
  rts


fat16_filename_compare:
  pha
  phy

  ldy #0
.loop:
  lda (R1),y
  cmp (R2),y
  bne .false

  iny
  cpy #12
  bne .loop

  ply
  pla
  clc
  rts

.false:
  ply
  pla
  sec
  rts


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
