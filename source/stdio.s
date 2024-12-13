# ------------------------------------------------------------------------
# Standard I/O Subroutine for RISC-V
#   2024/12/13 risc-v 64 system call
# Copyright (C) 2024  Jun Mizutani <mizutani.jun@nifty.ne.jp>
# stdio.s may be copied under the terms of the GNU General Public License.
# ------------------------------------------------------------------------

.ifndef __STDIO
__STDIO = 1

.ifndef __SYSCALL
  .equ sys_exit,  93
  .equ sys_read,  63
  .equ sys_write, 64
.endif

.text
.option norelax
.align 2  # 4byte boundary

#------------------------------------
# exit with 0
Exit:
        addi    sp, sp, -16
        sd      a7,  8(sp)
        sd      ra,  0(sp)
        li      a0, 0
        li      a7, sys_exit
        ecall
        ld      a7,  8(sp)          # will not execute
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret                         # jalr x0，x1，0

#------------------------------------
# exit with a0
ExitN:
        addi    sp, sp, -16
        sd      a7,  8(sp)
        sd      ra,  0(sp)
        li      a7, sys_exit
        ecall
        ld      a7,  8(sp)          # will not execute
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

#------------------------------------
# print string to stdout
# a0 : address, a1 : length
OutString:
        addi    sp, sp, -48
        sd      a7, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        mv      a2,  a1                 # a2  length
        mv      a1,  a0                 # a1  string address
        li      a0,  1                  # a0  stdout
        li      a7,  sys_write
        ecall
        ld      a7, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret                             # jr ra

#------------------------------------
# input  a0 : address
# output a1 : return length of strings
# leaf function
StrLen:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      a2,  0(sp)
        li      a1, 0                   # a1 : counter
1:      lbu     a2, 0(a0)
        addi    a1, a1, 1               # counter++
        addi    a0, a0, 1               # address
        bne     a2, zero, 1b
        addi    a1, a1, -1              # counter++
        ld      a0,  8(sp)
        ld      a2,  0(sp)
        addi    sp, sp, 16
        ret

#------------------------------------
# print asciiz string
# a0 : pointer to string
OutAsciiZ:
        addi    sp, sp, -16
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        jal     StrLen                  # jal ra, StrLen
        jal     OutString               # jal ra, OutString
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

#------------------------------------
# print pascal string to stdout
# a0 : top address
OutPString:
        addi    sp, sp, -32
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        lbu     a1,  0(a0)
        addi    a0,  a0, 1
        jal     OutString
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

#------------------------------------
# print 1 character to stdout
# a0 : put char
OutChar:
        addi    sp, sp, -48
        sd      a7, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        addi    a1, sp, 8               # a1  address
        li      a0, 1                   # a0  stdout
        mv      a2, a0                  # a2  length
        li      a7, sys_write
        ecall
        ld      a7, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret                             # jr ra

#------------------------------------
# print 4 printable characters in a0 to stdout
OutChar4:
        addi    sp, sp, -48
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        li      a3,  4
        jal     OutCharN

#------------------------------------
# print 8 printable characters in a0 to stdout
OutChar8:
        addi    sp, sp, -48
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)              # char
        li      a3,  8

OutCharN:
        mv      a1, a0
1:
        andi    a0, a1, 0x7F
        li      a2, 0x20
        bge     a0, a2, 2f
        li      a0, '.'
2:
        jal     OutChar
        srli    a1, a1, 8
        addi    a3, a3, -1
        bne     a3, zero, 1b

        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

#------------------------------------
# new line
NewLine:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        li      a0,  10
        jal     OutChar
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret


#------------------------------------
# Backspace
BackSpace:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        li      a0,  8
        jal     OutChar
        li      a0, ' '
        jal     OutChar
        li      a0,  8
        jal     OutChar
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret


#------------------------------------
# print binary number
#   a0 : number
#   a1 : bit
PrintBinary:
        addi    sp, sp, -32
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        beq     a1, zero, 4f            # if a1=0 exit
        li      a2, 64
        ble     a1, a2, 1f              # if a1>64 then a1=64
        mv      a1, a2
    1:  sub     a2, a2, a1
        sll     a2, a0, a2              # discard upper 64-a1 bit
    2:  li      a0, '0'
        bge     a2, zero, 3f
        addi    a0, a0, 1
    3:  jal     OutChar
        slli    a2, a2, 1
        addi    a1, a1, -1
        bne     a1, zero, 2b
    4:
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

#------------------------------------
# print a1 digit octal number
#   a0 : number
#   a1 : columns
PrintOctal:
        addi    sp, sp, -64
        sd      a4, 48(sp)
        sd      a3, 40(sp)
        sd      a2, 32(sp)
        sd      a1, 24(sp)
        sd      a0, 16(sp)
        sd      fp,  8(sp)
        sd      ra,  0(sp)

        mv      fp, sp                  # save sp
        li      a4, 32                  # buffer size
        sub     sp, sp, a4              # allocate buffer
        ble     a1, a4, 1f
        mv      a1, a4                  # prevent overflow
    1:
        mv      a3, a1                  # column
    2:  andi    a2, a0, 7
        srli    a0, a0, 3

        addi    fp, fp, -1              # push a2
        sb      a2, 0(fp)

        addi    a3, a3, -1
        bne     a3, zero, 2b
    3:
        lb      a0, 0(fp)               # 上位桁から POP
        addi    fp, fp, 1               # pop a0

        addi    a0, a0, '0'             # 文字コードに変更
        jal     OutChar                 # 出力
        addi    a1, a1, -1              # column--
        bne     a1, zero, 3b
    4:
        add     sp, sp, a4              # restore sp

        ld      a4, 48(sp)
        ld      a3, 40(sp)
        ld      a2, 32(sp)
        ld      a1, 24(sp)
        ld      a0, 16(sp)
        ld      fp,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 64
        ret

#------------------------------------
# print 2 digit hex number (lower 8 bit of a0)
#   a0 : number
PrintHex2:
        li      a1, 2
        j       PrintHex

#------------------------------------
# print 4 digit hex number (lower 16 bit of a0)
#   a0 : number
PrintHex4:
        li      a1, 4
        j       PrintHex

#------------------------------------
# print 8 digit hex number (a0)
#   a0 : number
PrintHex8:
        li      a1, 8
        j       PrintHex

PrintHex16:
        li      a1, 16

#------------------------------------
# print hex number
#   a0 : number     a1 : digit
PrintHex:
        addi    sp, sp, -64
        sd      a5, 56(sp)
        sd      a4, 48(sp)
        sd      a3, 40(sp)
        sd      a2, 32(sp)
        sd      a1, 24(sp)
        sd      a0, 16(sp)
        sd      fp,  8(sp)
        sd      ra,  0(sp)
        mv      fp, sp

        li      a5, 16                  # buffer size
        sub     sp, sp, a5              # allocate buffer
        ble     a1, a5, 1f
        mv      a1, a5                  # prevent overflow
1:      mv      a3, a1                  # column
2:      and     a2, a0, 0x0F            #
        srli    a0, a0, 4               #
        ori     a2, a2, 0x30
        li      a4, 0x39
        ble     a2, a4, 3f
        add     a2, a2, 0x41-0x3A       # if (a2>'9') a2+='A'-'9'
3:
        addi    fp, fp, -1              # push a2
        sb      a2, 0(fp)               # first in/last out
        addi    a3, a3, -1              # column--
        bne     a3, zero, 2b
        mv      a3, a1                  # column
4:
        lb      a0, 0(fp)
        addi    fp, fp, 1               # pop a0
        jal     OutChar
        addi    a3, a3, -1              # column--
        bne     a3, zero, 4b

        add     sp, sp, a5              # restore sp
        ld      a5, 56(sp)              # pop up registers
        ld      a4, 48(sp)
        ld      a3, 40(sp)
        ld      a2, 32(sp)
        ld      a1, 24(sp)
        ld      a0, 16(sp)
        ld      fp,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 64
        ret

#------------------------------------
# Output Unsigned Number to stdout
# a0 : number
PrintLeftU:
        addi    sp, sp, -64
        sd      a4, 48(sp)
        sd      a3, 40(sp)
        sd      a2, 32(sp)
        sd      a1, 24(sp)
        sd      a0, 16(sp)
        sd      fp,  8(sp)
        sd      ra,  0(sp)
        mv      fp, sp
        addi    sp, sp, -32             # allocate buffer
        li      a2, 0                   # counter
        li      a3, 0                   # positive flag
        j       1f

#------------------------------------
# Output Number to stdout
# a0 : number
PrintLeft:
        addi    sp, sp, -64
        sd      a4, 48(sp)
        sd      a3, 40(sp)
        sd      a2, 32(sp)
        sd      a1, 24(sp)
        sd      a0, 16(sp)
        sd      fp,  8(sp)
        sd      ra,  0(sp)
        mv      fp, sp
        addi    sp, sp, -32             # allocate buffer
        li      a2, 0                   # counter
        li      a3, 0                   # positive flag
        bge     a0, zero, 1f
        li      a3, 1                   # set negative
        sub     a0, a2, a0              # a0 = 0-a0
    1:  li      a1, 10                  # a3 = 10
        divu    a4, a0, a1              # division by 10
        remu    a1, a0, a1              # a1 = reminder(a0 / a1)
        mv      a0, a4
        addi    a2, a2, 1               # counter++
        addi    fp, fp, -1              # push a2
        sb      a1, 0(fp)               # least digit (reminder)
        bne     a0, zero, 1b            # done ?
        beq     a3, zero, 2f
        li      a0, '-'                 # if (a0<0) putchar("-")
        jal     OutChar                 # output '-'
    2:  lb      a0, 0(fp)               # most digit
        addi    fp, fp, 1               # pop a0
        addi    a0, a0, '0'             # ASCII
        jal     OutChar                 # output a digit
        addi    a2, a2, -1              # counter--
        bne     a2, zero, 2b
        addi    sp, sp, 32

        ld      a4, 48(sp)
        ld      a3, 40(sp)
        ld      a2, 32(sp)
        ld      a1, 24(sp)
        ld      a0, 16(sp)
        ld      fp,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 64
        ret

#------------------------------------
# Output Number to stdout
# a1:column
# a0:number
PrintRight0:
        addi    sp, sp, -80
        sd      a6, 64(sp)
        sd      a5, 56(sp)
        sd      a4, 48(sp)
        sd      a3, 40(sp)
        sd      a2, 32(sp)
        sd      a1, 24(sp)
        sd      a0, 16(sp)
        sd      fp,  8(sp)
        sd      ra,  0(sp)
        mv      fp, sp
        addi    sp, sp, -32             # allocate buffer
        li      a4, '0'
        j       0f

#------------------------------------
# Output Unsigned Number to stdout
# a1:column
# a0:number
PrintRightU:
        addi    sp, sp, -80
        sd      a6, 64(sp)
        sd      a5, 56(sp)
        sd      a4, 48(sp)
        sd      a3, 40(sp)
        sd      a2, 32(sp)
        sd      a1, 24(sp)
        sd      a0, 16(sp)
        sd      fp,  8(sp)
        sd      ra,  0(sp)
        mv      fp, sp
        addi    sp, sp, -32             # allocate buffer
        li      a4, ' '
    0:  mv      a5, a1
        li      a2, 0                   # counter
        li      a3, 0                   # positive flag
        j       1f                      # PrintRight.1

#------------------------------------
# Output Number to stdout
# a1:column
# a0:number
PrintRight:
        addi    sp, sp, -80
        sd      a6, 64(sp)
        sd      a5, 56(sp)
        sd      a4, 48(sp)
        sd      a3, 40(sp)
        sd      a2, 32(sp)
        sd      a1, 24(sp)
        sd      a0, 16(sp)
        sd      fp,  8(sp)
        sd      ra,  0(sp)

        mv      fp, sp
        addi    sp, sp, -32             # allocate buffer
        li      a4, ' '
        mv      a5, a1
        li      a2, 0                   # counter=0
        li      a3, 0                   # positive flag
        bge     a0, zero, 1f
        li      a3, 1                   # set negative
        sub     a0, zero, a0            # a0 = 0-a0
    1:  li      a1, 10                  # a3 = 10
        divu    a6, a0, a1              # division by 10
        remu    a1, a0, a1
        mv      a0, a6                  # a0 : quotient7
        addi    a2, a2, 1               # counter++
        addi    fp, fp, -1              # push a2
        sb      a1, 0(fp)               # least digit (reminder)
        bne     a0, zero, 1b            # done ?

        sub     a5, a5, a2              # a5 = no. of space
        ble     a5, zero, 3f            # dont write space
        beq     a3, zero, 2f
        addi    a5, a5, -1              # reserve spase for -
    2:  mv      a0, a4                  # output space or '0'
        jal     OutChar
        addi    a5, a5, -1              # nspace--
        bgt     a5, zero, 2b

    3:  beq     a3, zero, 4f
        li      a0, '-'                 # if (a0<0) putchar("-")
        jal     OutChar            # output '-'
    4:  lb      a0, 0(fp)               # most digit
        addi    fp, fp, 1               # pop a0
        addi    a0, a0, '0'             # ASCII
        jal     OutChar            # output a digit
        addi    a2, a2, -1              # counter--
        bne     a2, zero, 4b
        addi    sp, sp, 32

        ld      a6, 64(sp)
        ld      a5, 56(sp)
        ld      a4, 48(sp)
        ld      a3, 40(sp)
        ld      a2, 32(sp)
        ld      a1, 24(sp)
        ld      a0, 16(sp)
        ld      fp,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 80
        ret

#------------------------------------
# input 1 character from stdin
# a0 : get char
InChar:
        li      a0, 0                   # clear upper bits
        addi    sp, sp, -48
        sd      a7, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        addi    a1, sp, 8               # a1(stack) address
        li      a0, 0                   # a0  stdin
        li      a2, 1                   # a2  length
        li      a7, sys_read
        ecall
        ld      a7, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

#------------------------------------
# Input Line
# a0 : BufferSize
# a1 : Buffer Address
# return       a0 : no. of char
InputLine0:
        addi    sp, sp, -48
        sd      a5, 40(sp)
        sd      a4, 32(sp)
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        mv      a4, a0                  # BufferSize
        mv      a5, a1                  # Input Buffer
        li      a3, 0                   # counter
    1:
        jal     InChar
        li      s0, 0x08                # BS ?
        bne     a0, s0, 2f
        beq     a3, zero, 2f
        jal     BackSpace               # backspace
        addi    a3, a3, -1
        j       1b
    2:
        li      s0, 0x0A                # enter ?
        beq     a0, s0, 4f              # exit

        jal     OutChar                 # printable:
        add     s0, a5, a3
        sb      a0, 0(s0)
        addi    a3, a3, 1
        bge     a3, a4, 3f
        j       1b
    3:
        addi    a3, a3, -1
        jal     BackSpace
        j       1b

    4:  li      a0, 0
        add     s0, a5, a3
        sb      a0, 0(s0)
        addi    a3, a3, 1
        jal     NewLine
        mv      a0, a3
        ld      a5, 40(sp)
        ld      a4, 32(sp)
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

.endif
