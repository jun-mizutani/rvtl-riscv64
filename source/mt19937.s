#---------------------------------------------------------------------
#   Mersenne Twister
#   file : mt19937.s
#     Rewritten in RISC-V Assembly by Jun Mizutani 2025/03/07.
#     From original code in C by Takuji Nishimura(mt19937int.c).
#     SISC-V version Copyright (C) 2024-2025 Jun Mizutani.
#---------------------------------------------------------------------

# A C-program for MT19937: Integer version (1999/10/28)
#  genrand() generates one pseudorandom unsigned integer (32bit)
# which is uniformly distributed among 0 to 2^32-1  for each
# call. sgenrand(seed) sets initial values to the working area
# of 624 words. Before genrand(), sgenrand(seed) must be
# called once. (seed is any 32-bit integer.)
#   Coded by Takuji Nishimura, considering the suggestions by
# Topher Cooper and Marc Rieffel in July-Aug. 1997.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later
# version.
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Library General Public License for more details.
# You should have received a copy of the GNU Library General
# Public License along with this library; if not, write to the
# Free Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
#
# Copyright (C) 1997, 1999 Makoto Matsumoto and Takuji Nishimura.
# Any feedback is very welcome. For any question, comments,
# see http://www.math.keio.ac.jp/matumoto/emt.html or email
# matumoto//math.keio.ac.jp
#
# REFERENCE
# M. Matsumoto and T. Nishimura,
# "Mersenne Twister: A 623-Dimensionally Equidistributed Uniform
# Pseudo-Random Number Generator",
# ACM Transactions on Modeling and Computer Simulation,
# Vol. 8, No. 1, January 1998, pp 3--30.

.text
        .align  2
        .option rvc
        .option norelax
#---------------------------------------------------------------------
# Initialize Mersenne Twister
#   enter a0 : 32bit seed
#---------------------------------------------------------------------
sgenrand:
        addi    sp, sp, -80
        sd      s7, 72(sp)
        sd      s6, 64(sp)
        sd      s5, 56(sp)
        sd      s4, 48(sp)
        sd      s3, 40(sp)
        sd      s2, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        la      s3, mt
        la      s7, N
        lw      s4, (s7)                # N
        lwu     s5, 12(s7)              # nffff0000
        lw      s6, 8(s7)               # n69069
        li      a2, 0                   # I=0
    1:
        and     a1, a0, s5              # A = seed & 0xffff0000
        mul     a0, s6, a0              # a0 = seed * 69069
        addi    a0, a0, 1               # S = R * S + 1
        and     s2, a0, s5              # S & 0xffff0000
        srli    s2, s2, 16              # (S & 0xffff0000 >> 16)
        or      a1, a1, s2              # A=A|(S & 0xffff0000 >> 16)
        slli    s0, a2, 2
        add     s0, s3, s0
        sw      a1, (s0)                # mt[i]=A
        mul     a0, s6, a0
        addi    a0, a0, 1               # S = R * S + 1
        addi    a2, a2, 1               # I=I+1
        blt     a2, s4, 1b              # I+1 < 624

        la      a1, mti
        sw      s4, (a1)                # mti=N
        ld      s7, 72(sp)
        ld      s6, 64(sp)
        ld      s5, 56(sp)
        ld      s4, 48(sp)
        ld      s3, 40(sp)
        ld      s2, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 80
        ret

#---------------------------------------------------------------------
# Generate Random Number
#   return a0 : random number
#---------------------------------------------------------------------
genrand:
        addi    sp, sp, -112
        sd      s10, 104(sp)
        sd      s9, 96(sp)
        sd      s8, 88(sp)
        sd      s7, 80(sp)
        sd      s6, 72(sp)
        sd      s5, 64(sp)
        sd      s4, 56(sp)
        sd      s3, 48(sp)
        sd      s2, 40(sp)
        sd      s1, 32(sp)
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)

        la      s9, N
        la      s3, mt
        lwu     s4, (s9)                # N
        lwu     s2, 36(s9)
        addi    a2, s4, -1              # N-1
        ble     s2, a2, 3f              # mti <= 623

        lwu     s5, 4(s9)               # M
        lwu     s6, 24(s9)              # UPPER_MASK
        lwu     s7, 28(s9)              # LOWER_MASK
        li      s1, 0                   # K=0
    1:  slli    s0, s1, 2
        add     s10, s3, s0
        lwu     a0, (s10)               # mt[K]
        and     a0, a0, s6              # mt[K] & UPPER_MASK
        add     a3, s1, 1               # J=K+1
        jal     rnd_common2             # return Y>>1:a0,Z:a1
        add     a2, s1, s5              # a2=K+397
        jal     rnd_common
        sw      a1, (s10)               # mt[K]=P^Q^Z
        add     s1, s1, 1               # K=K+1
        sub     a0, s4, s5              # N-M=227
        blt     s1, a0, 1b

    2:  slli    s0, s1, 2
        add     s10, s3, s0
        lwu     a0, (s10)               # mt[K]
        and     a0, a0, s6              # UPPER_MASK
        addi    a3, s1, 1               # J=K+1
        jal     rnd_common2             # return Y>>1:a0,Z:a1
        sub     a2, s5, s4
        add     a2, s1, a2              # K+(M-N)
        jal     rnd_common
        sw      a1, (s10)               # mt[K]=P^Q^Z
        addi    s1, s1, 1               # K=K+1
        addi    s0, s4, -1              # 623
        blt     s1, s0, 2b

        slli    s0, s1, 2
        add     s10, s3, s0
        lwu     a0, (s10)               # mt[K]
        and     a0, a0, s6              # UPPER_MASK
        li      a3, 0                   # J=0
        jal     rnd_common2             # return Y>>1:a0,Z:a1
        addi    a2, s5, -1              # 396
        jal     rnd_common
        addi    a2, s4, -1              # 623
        slli    s0, a2, 2
        add     s0, s3, s0
        sw      a1, (s0)                # mt[623]=P^Q^Z
        li      s2, 0                   # mti=0
    3:  slli    s0, s2, 2
        add     s0, s3, s0
        lwu     a3, (s0)                # y=mt[mti]
        addi    s2, s2, 1
        sw      s2, 36(s9)              # mti++
        srli    a0, a3, 11              # y>>11
        xor     a3, a3, a0              # y=y^(y>>11)
        slli    a0, a3, 7               # y << 7
        lwu     s0, 16(s9)              # TEMPERING_MASK_B
        and     a0, a0, s0              # TEMPERING_MASK_B
        xor     a3, a3, a0
        slli    a0, a3, 15
        lwu     s0, 20(s9)              # TEMPERING_MASK_C
        and     a0, a0, s0              # TEMPERING_MASK_C
        xor     a3, a3, a0
        srli    a0, a3, 18
        xor     a0, a3, a0

        ld      s10, 104(sp)
        ld      s9, 96(sp)
        ld      s8, 88(sp)
        ld      s7, 80(sp)
        ld      s6, 72(sp)
        ld      s5, 64(sp)
        ld      s4, 56(sp)
        ld      s3, 48(sp)
        ld      s2, 40(sp)
        ld      s1, 32(sp)
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 112
        ret

    rnd_common:
        slli    s0, a2, 2
        add     s0, s3, s0
        lwu     a3, (s0)                # mt[x]
        xor     a3, a3, a0              # mt[x]^P
        xor     a1, a3, a1
        ret
    rnd_common2:
        slli    s0, a3, 2
        add     s0, s3, s0
        lwu     a1, (s0)                # mt[J]
        and     a1, a1, s7              # LOWER_MASK
        or      a3, a0, a1              # y
        srli    a0, a3, 1               # a0=(y>>1)
        li      a1, 0
        andi    s0, a3, 1
        beqz    s0, 1f
        lwu     a1, 32(s9)              # MATRIX_A
    1:  ret

.data
N:                  .long   624          # 0
M:                  .long   397          # 4
n69069:             .long   69069        # 8
nffff0000:          .long   0xffff0000   # 12
TEMPERING_MASK_B:   .long   0x9d2c5680   # 16
TEMPERING_MASK_C:   .long   0xefc60000   # 20
UPPER_MASK:         .long   0x80000000   # 24
LOWER_MASK:         .long   0x7fffffff   # 28
MATRIX_A:           .long   0x9908b0df   # 32
mti:                .long   N + 1        # 36

.bss
mt:                 .skip   624 * 4
