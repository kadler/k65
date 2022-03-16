; Useful macros. Included automatically by header.inc.s

; SPDX-License-Identifier: GPL-3.0-or-later

  .ifndef MACROS_INC
MACROS_INC = 1

  ; Push a 16-bit "register" to the stack
  .macro PHR
  lda \1
  pha
  lda \1+1
  pha
  .endm

  ; Pull a 16-bit "register" from the stack
  .macro PLR
  pla
  sta \1+1
  pla
  sta \1
  .endm

  ; Load a 16-bit "register" from an absolute address
  .macro LDR
  lda \2
  sta \1
  lda (\2)+1
  sta (\1)+1
  .endm

  ; Load a 16-bit "register" from an immediate address
  .macro LDRI
  lda #<\2
  sta \1
  lda #>\2
  sta (\1)+1
  .endm

  ; Move a 16-bit "register" to another 16-bit "register"
  .macro MVR
  lda \2
  sta \1
  lda (\2)+1
  sta (\1)+1
  .endm


  .endif
