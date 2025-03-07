#-------------------------------------------------------------------------
#  file : vtlsys.s for risc-v
#  2025-03-07
#  Copyright (C) 2024-2025 Jun Mizutani <mizutani.jun@nifty.ne.jp>
#-------------------------------------------------------------------------

        .text
        .align  2
        .option norelax

SYSCALLMAX  =   1079

SystemCall: # return a0
        addi    sp, sp, -64
        sd      a7, 48(sp)
        sd      a5, 40(sp)
        sd      a4, 32(sp)
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        li      s0, 'a'              # a にシステムコール番号
        slli    s0, s0, 3
        add     s0, gp, s0           # s0 = s0 * 8 + VarArea
        ld      a7, 0(s0)            # a7 <- [s0*8+VarArea]
        li      a6, SYSCALLMAX
        bgt     a7, a6, 1f
        li      s0, 'b'              # b にシステムコール引数1
        slli    s0, s0, 3
        add     s0, gp, s0           # s0 = s0 * 8 + VarArea
        ld      a0, 0(s0)            # a0 <- [s0*8+VarArea]
        li      s0, 'c'              # c にシステムコール引数2
        slli    s0, s0, 3
        add     s0, gp, s0           # s0 = s0 * 8 + VarArea
        ld      a1, 0(s0)            # a1 <- [s0*8+VarArea]
        li      s0, 'd'              # d にシステムコール引数3
        slli    s0, s0, 3
        add     s0, gp, s0           # s0 = s0 * 8 + VarArea
        ld      a2, 0(s0)            # a2 <- [s0*8+VarArea]
        li      s0, 'e'              # e にシステムコール引数4
        slli    s0, s0, 3
        add     s0, gp, s0           # s0 = s0 * 8 + VarArea
        ld      a3, 0(s0)            # a3 <- [s0*8+VarArea]
        li      s0, 'f'              # f にシステムコール引数5
        slli    s0, s0, 3
        add     s0, gp, s0           # s0 = s0 * 8 + VarArea
        ld      a4, 0(s0)            # a4 <- [s0*8+VarArea]
        li      s0, 'g'              # g にシステムコール引数6
        slli    s0, s0, 3
        add     s0, gp, s0           # s0 = s0 * 8 + VarArea
        ld      a5, 0(s0)            # a5 <- [s0*8+VarArea]
        ecall
    1:
        ld      a7, 48(sp)
        ld      a5, 40(sp)
        ld      a4, 32(sp)
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 64
        ret

