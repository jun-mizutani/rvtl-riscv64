#---------------------------------------------------------------------
#   Mersenne Twister
#   file : mt19937ar.s
#     Rewritten in RISC-V Assembly by Jun Mizutani 2025/07/28.
#     From original code in C by Takuji Nishimura(mt19937ar.c).
#     SISC-V version Copyright (C) 2025 Jun Mizutani.
#---------------------------------------------------------------------
# A C-program for MT19937, with initialization improved 2002/1/26.
# Coded by Takuji Nishimura and Makoto Matsumoto.
#
#  Before using, initialize the state by using init_genrand(seed)  
# or init_by_array(init_key, key_length).
#
#  Copyright (C) 1997 - 2002, Makoto Matsumoto and Takuji Nishimura,
# All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#    1. Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#
#    3. The names of its contributors may not be used to endorse or promote 
#      products derived from this software without specific prior written 
#      permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#   Any feedback is very welcome.
# http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html
# email: m-mat @ math.sci.hiroshima-u.ac.jp (remove space)

.text
        .align  2
        .option norelax
        .option rvc
#---------------------------------------------------------------------
# Initialize Mersenne Twister
#   enter a0 : 32bit seed
#---------------------------------------------------------------------
sgenrand:
        addi    sp, sp, -80
        sd      s3, 72(sp)
        sd      s2, 64(sp)
        sd      s1, 56(sp)
        sd      s0, 48(sp)
        sd      a5, 40(sp)
        sd      a4, 32(sp)
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        la      a3, mt
        la      s3, N
        lw      a4, (s3)                # N
        lwu     a5, 12(s3)              # nffffffff
        lwu     s2, 8(s3)               # 1812433253(6C078965)
        and     a1, a0, a5              # a1 = seed & 0xffffffff
        sw      a1, (a3)                # mt[0] = a1
        li      a2, 1                   # i = 1
    1:
        addi    s0, a2, -1              # i-1
        slli    s0, s0, 2               # s0 = (i-1) * 4
        add     s0, a3, s0              # s0 = mt + s0
        lwu     a1, (s0)                # a1 = mt[i-1]
        srli    s1, a1, 30              # mt[i-1] >> 30
        xor     s1, a1, s1              # s1 = mt[i-1] ^ (mt[i-1] >> 30)
        mul     s1, s2, s1              # s1 = 1812433253 * s1
        add     s1, s1, a2              # s1 = s1 + i
        and     s1, s1, a5              # 32-bit mask
        slli    s0, a2, 2
        add     s0, a3, s0
        sw      s1, (s0)                # mt[i] = s1
        addi    a2, a2, 1               # i++
        blt     a2, a4, 1b              # i < N

        la      a1, mti
        sw      a4, (a1)                # mti=N
        ld      s3, 72(sp)
        ld      s2, 64(sp)
        ld      s1, 56(sp)
        ld      s0, 48(sp)
        ld      a5, 40(sp)
        ld      a4, 32(sp)
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
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
        sd      s3, 64(sp)
        sd      s2, 56(sp)
        sd      s1, 48(sp)
        sd      a5, 40(sp)
        sd      a4, 32(sp)
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)

        la      s9, N
        la      s3, mt
        lwu     a4, (s9)                # N
        lwu     s2, 36(s9)
        addi    a2, a4, -1              # N-1
        ble     s2, a2, 3f              # mti <= 623

        lwu     a5, 4(s9)               # M
        lwu     s6, 24(s9)              # UPPER_MASK
        lwu     s7, 28(s9)              # LOWER_MASK
        li      s1, 0                   # K=0
    1:  slli    s0, s1, 2
        add     s10, s3, s0
        lwu     a0, (s10)               # mt[K]
        and     a0, a0, s6              # mt[K] & UPPER_MASK
        add     a3, s1, 1               # J=K+1
        jal     rnd_common2             # return Y>>1:a0,Z:a1
        add     a2, s1, a5              # a2=K+397
        jal     rnd_common
        sw      a1, (s10)               # mt[K]=P^Q^Z
        add     s1, s1, 1               # K=K+1
        sub     a0, a4, a5              # N-M=227
        blt     s1, a0, 1b

    2:  slli    s0, s1, 2
        add     s10, s3, s0
        lwu     a0, (s10)               # mt[K]
        and     a0, a0, s6              # UPPER_MASK
        addi    a3, s1, 1               # J=K+1
        jal     rnd_common2             # return Y>>1:a0,Z:a1
        sub     a2, a5, a4
        add     a2, s1, a2              # K+(M-N)
        jal     rnd_common
        sw      a1, (s10)               # mt[K]=P^Q^Z
        addi    s1, s1, 1               # K=K+1
        addi    s0, a4, -1              # 623
        blt     s1, s0, 2b

        slli    s0, s1, 2
        add     s10, s3, s0
        lwu     a0, (s10)               # mt[K]
        and     a0, a0, s6              # UPPER_MASK
        li      a3, 0                   # J=0
        jal     rnd_common2             # return Y>>1:a0,Z:a1
        addi    a2, a5, -1              # 396
        jal     rnd_common
        addi    a2, a4, -1              # 623
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
        ld      s3, 64(sp)
        ld      s2, 56(sp)
        ld      s1, 48(sp)
        ld      a5, 40(sp)
        ld      a4, 32(sp)
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
n6C078965:          .long   1812433253   # 8
nffffffff:          .long   0xffffffff   # 12
TEMPERING_MASK_B:   .long   0x9d2c5680   # 16
TEMPERING_MASK_C:   .long   0xefc60000   # 20
UPPER_MASK:         .long   0x80000000   # 24
LOWER_MASK:         .long   0x7fffffff   # 28
MATRIX_A:           .long   0x9908b0df   # 32
mti:                .long   N + 1        # 36

.bss
mt:                 .skip   624 * 4
