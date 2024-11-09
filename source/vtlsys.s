#-------------------------------------------------------------------------
#  file : vtlsys.s for risc-v
#  2024-11-08
#  Copyright (C) 2024 Jun Mizutani <mizutani.jun@nifty.ne.jp>
#-------------------------------------------------------------------------

        .text
        .align  3
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
        li      t0, 'a'              # a にシステムコール番号
        slli    t0, t0, 3
        add     t0, gp, t0           # t0 = t0 * 8 + VarArea
        ld      a7, 0(t0)            # a7 <- [t0*8+VarArea]
        li      a6, SYSCALLMAX
        bgt     a7, a6, 1f
        li      t0, 'b'              # b にシステムコール引数1
        slli    t0, t0, 3
        add     t0, gp, t0           # t0 = t0 * 8 + VarArea
        ld      a0, 0(t0)            # a0 <- [t0*8+VarArea]
        li      t0, 'c'              # c にシステムコール引数2
        slli    t0, t0, 3
        add     t0, gp, t0           # t0 = t0 * 8 + VarArea
        ld      a1, 0(t0)            # a1 <- [t0*8+VarArea]
        li      t0, 'd'              # d にシステムコール引数3
        slli    t0, t0, 3
        add     t0, gp, t0           # t0 = t0 * 8 + VarArea
        ld      a2, 0(t0)            # a2 <- [t0*8+VarArea]
        li      t0, 'e'              # e にシステムコール引数4
        slli    t0, t0, 3
        add     t0, gp, t0           # t0 = t0 * 8 + VarArea
        ld      a3, 0(t0)            # a3 <- [t0*8+VarArea]
        li      t0, 'f'              # f にシステムコール引数5
        slli    t0, t0, 3
        add     t0, gp, t0           # t0 = t0 * 8 + VarArea
        ld      a4, 0(t0)            # a4 <- [t0*8+VarArea]
        li      t0, 'g'              # g にシステムコール引数6
        slli    t0, t0, 3
        add     t0, gp, t0           # t0 = t0 * 8 + VarArea
        ld      a5, 0(t0)            # a5 <- [t0*8+VarArea]
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

