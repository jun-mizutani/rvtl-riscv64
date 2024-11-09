#-------------------------------------------------------------------------
#  Return of the Very Tiny Language for ARM64
#  2024/11/09
#  Copyright (C) 2024 Jun Mizutani <mizutani.jun@nifty.ne.jp>
#
#  file : ext.s
#-------------------------------------------------------------------------

        jal     GetChar                 # get the next character of "\"
        li      t0, 'j'
        beq     tp, t0, ext_j
        j       func_err

ext_j:
        jal     GetChar                 # get the next character of "j"
        li      t0, 'm'
        beq     tp, t0, ext_jm
        j       func_err
ext_jm:
        # some additional work
        ret
