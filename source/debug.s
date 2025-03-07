# -------------------------------------------------------------------------
#   Debugging Macros for RISC-V assembly
#   file : debug.s
#   2025/03/07
#   Copyright (C) 2024-2025 Jun Mizutani <mizutani.jun@nifty.ne.jp>
#   This file may be copied under the terms of the GNU General Public License.
# -------------------------------------------------------------------------

.ifndef __DEBUG
__DEBUG = 1

.ifndef __STDIO
.include "stdio.s"
.endif

#           +-------+
#     sp->  | -     | +32
#           +-------+
#           |not use| +24
#           +-------+
#           |  a1   | +16
#           +-------+
#           |  a0   | +8
#           +-------+
#     sp->  |  ra   | +0
#           +=======+
.macro  ENTER
        addi    sp, sp, -32
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
.endm

.macro  LEAVE
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
.endm

# Print a register value (x0 - x31)
# x0 - x31 registers are unchanged.
# x2(sp) is decremented by 32, then restored.
# ex. PRINTREG a0
# a0 -4520909795638496974 13925834278071054642:C142807E61623132 21ba~.BA
.macro  PRINTREG   reg
        ENTER
        la      a0, 998f                # destroy a0
        jal     OutAsciiZ
        ld      a0,  8(sp)              # restore a0
        mv      a0, \reg
        li      a1, 21                  # destroy a1
        jal     PrintRight
        jal     PrintRightU
        li      a0, ':'                 # destroy a0
        jal     OutChar
        ld      a1, 16(sp)              # restore a1
        ld      a0,  8(sp)              # restore a0
        mv      a0, \reg
        jal     PrintHex16              # destroy a1
        li      a0, ' '                 # destroy a0
        jal     OutChar
        ld      a0,  8(sp)              # restore a0
        ld      a1, 16(sp)              # restore a1
        mv      a0, \reg
        jal     OutChar8
        jal     NewLine
        LEAVE
        jal     zero, 999f
998:    .asciz "\reg"
        .align 2
999:
.endm

# Print ASCIIZ string from the address value in the register.
#   ex. PRINTSTR x11
.macro  PRINTSTR reg
        ENTER
        ld      a0, 0( \reg )
        jal     OutAsciiZ
        jal     NewLine
        LEAVE
.endm

# Print ASCIIZ string from the address value in the memory
# pointed by the register.
#   ex. PRINTSTRI x11
.macro  PRINTSTRI  reg
        ENTER
        mv      a1, \reg
        ld      a0, 0(a1)
        jal     OutAsciiZ
        jal     NewLine
        LEAVE
.endm

# Print a number.
#   ex. CHECK 99
.macro  CHECK   number
        ENTER
        li      a0, \number
        jal     PrintLeft
        jal     NewLine
        LEAVE
.endm

# Print a character.
#   ex. PRINTCH  x11
.macro  PRINTCH  reg
        ENTER
        mv      a0, \reg
        jal     OutChar
        jal     NewLine
        LEAVE
.endm

# Wait until key press.
.macro  PAUSE
        ENTER
        jal     InChar
        LEAVE
.endm

.macro  printpc
        ENTER
        jal     a0, 997f
997:
        jal     PrintHex16
        jal     NewLine
        LEAVE
.endm
.endif

