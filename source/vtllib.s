# -------------------------------------------------------------------------
#  Return of the Very Tiny Language for RISC-V
#  file : vtllib.s
#  2024/12/13
#  Copyright (C) 2003-2024 Jun Mizutani <mizutani.jun@nifty.ne.jp>
#  vtllib.s may be copied under the terms of the GNU General Public License.
# -------------------------------------------------------------------------

.ifndef __VTLLIB
__VTLLIB = 1

.include "syscalls.s"
.include "signal.s"
.include "stdio.s"

# ==============================================================
.text

MAXLINE      = 128         #  Maximum Line Length
MAX_FILE     = 256         #  Maximum Filename
MAXHISTORY   =  16         #  No. of history buffer

TIOCGWINSZ   = 0x5413

NCCS  = 19

#   c_cc characters
VINTR     = 0
VQUIT     = 1
VERASE    = 2
VKILL     = 3
VEOF      = 4
VTIME     = 5
VMIN      = 6

#   c_lflag bits
ISIG      = 0000001
ICANON    = 0000002
XCASE     = 0000004
ECHO      = 0000010
ECHOE     = 0000020
ECHOK     = 0000040
ECHONL    = 0000100
NOFLSH    = 0000200
TOSTOP    = 0000400
ECHOCTL   = 0001000
ECHOPRT   = 0002000
ECHOKE    = 0004000
FLUSHO    = 0010000
PENDIN    = 0040000
IEXTEN    = 0100000

TCGETS    = 0x5401
TCSETS    = 0x5402

SEEK_SET  = 0               #  Seek from beginning of file.
SEEK_CUR  = 1               #  Seek from current position.
SEEK_END  = 2               #  Seek from end of file.

#  from include/linux/wait.h
WNOHANG   = 0x00000001
WUNTRACED = 0x00000002

#  from include/asm-i386/fcntl.h
O_RDONLY =    00
O_WRONLY =    01
O_RDWR   =    02
O_CREAT  =  0100
O_EXCL   =  0200
O_NOCTTY =  0400
O_TRUNC  = 01000

S_IFMT   = 0170000
S_IFSOCK = 0140000
S_IFLNK  = 0120000
S_IFREG  = 0100000
S_IFBLK  = 0060000
S_IFDIR  = 0040000
S_IFCHR  = 0020000
S_IFIFO  = 0010000
S_ISUID  = 0004000
S_ISGID  = 0002000
S_ISVTX  = 0001000

S_IRWXU  = 00700
S_IRUSR  = 00400
S_IWUSR  = 00200
S_IXUSR  = 00100

S_IRWXG  = 00070
S_IRGRP  = 00040
S_IWGRP  = 00020
S_IXGRP  = 00010

S_IRWXO  = 00007
S_IROTH  = 00004
S_IWOTH  = 00002
S_IXOTH  = 00001

#  from include/linux/fs.h
MS_RDONLY       =  1        #  Mount read-only
MS_NOSUID       =  2        #  Ignore suid and sgid bits
MS_NODEV        =  4        #  Disallow access to device special files
MS_NOEXEC       =  8        #  Disallow program execution
MS_SYNCHRONOUS  = 16        #  Writes are synced at once
MS_REMOUNT      = 32        #  Alter flags of a mounted FS

AT_FDCWD =  -100

size_dir_ent = 512

# -------------------------------------------------------------------------
#  編集付き行入力(初期文字列付き)
#    a0:バッファサイズ, a1:バッファ先頭
#    a0 に入力文字数を返す
# -------------------------------------------------------------------------
        .align  2
READ_LINE2:
        la      a2, LINE_TOP            #  No. of prompt characters
        ld      a3, (a2)
        sd      a3, 8(a2)               #  FLOATING_TOP=LINE_TOP
        addi    sp, sp, -32
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        mv      a3, a0                  #  バッファサイズ退避
        mv      a2, a1                  #  入力バッファ先頭退避
        mv      a0, a1                  #  入力バッファ表示
        jal     OutAsciiZ
        jal     StrLen                  #  <r0:アドレス, >r1:文字数
        mv      s9, a1                  #  行末位置
        mv      a1, a2                  #  バッファ先頭復帰
        mv      a0, a3                  #  バッファサイズ復帰
        j       RL_0

# -------------------------------------------------------------------------
#  編集付き行入力
#    a0:バッファサイズ, a1:バッファ先頭
#    a0 に入力文字数を返す
#    カーソル位置を取得して行頭を保存, 複数行にわたるペースト不可
# -------------------------------------------------------------------------
READ_LINE3:
        addi    sp, sp, -16
        sd      ra,  0(sp)
        jal     get_cursor_position
        ld      ra,  0(sp)
        addi    sp, sp, 16
        j       RL

# -------------------------------------------------------------------------
#  編集付き行入力
#    a0:バッファサイズ, a1:バッファ先頭
#    a0 に入力文字数を返す
# -------------------------------------------------------------------------
READ_LINE:
        la      a2, LINE_TOP            #  No. of prompt characters
        ld      a3, (a2)
        sd      a3, 8(a2)               #  FLOATING_TOP=LINE=TOP
RL:
        addi    sp, sp, -32
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        li      s9, 0                   #  行末位置
RL_0:
        la      s8, HistLine            #  history string ptr
        mv      s6, a1                  #  Input Buffer
        li      a2, 0
        add     a3, s6, s9              # a3 = Input Buffer + 行末位置
        sb      a2, (a3)                #  mark EOL
        mv      s7, a0                  #  BufferSize
        mv      s10, s9                 #  current position
RL_next_char:
        jal     InChar
        li      a1, 0x1B                #  ESC ?
        bne     a0, a1, 1f
        jal     translate_key_seq
    1:  li      a1, 0x09                #  TAB ?
        beq     a0, a1, RL_tab
        li      a1, 127                 #  BS (linux console) ?
        beq     a0, a1, RL_bs
        li      a1, 0x08                #  BS ?
        beq     a0, a1, RL_bs
        li      a1, 0x04                #  ^D ?
        beq     a0, a1, RL_delete
        li      a1, 0x02                #  ^B
        beq     a0, a1, RL_cursor_left
        li      a1, 0x06                #  ^F
        beq     a0, a1, RL_cursor_right
        li      a1, 0x0E                #  ^N
        beq     a0, a1, RL_forward
        li      a1, 0x10                #  ^P
        beq     a0, a1, RL_backward
        li      a1, 0x0A                #  enter ?
        beq     a0, a1, RL_in_exit
        li      a1, 0x20
        bltu    a0, a1, RL_next_char    #  if a0 < 0x20: skip to next char
RL_in_printable:
        add     s9, s9, 1               #  eol
        add     s10, s10, 1             #  current position
        bgeu    s9, s7, RL_in_toolong   #  s7:buffer size
        bltu    s10, s9, RL_insert      #  Insert Char
        jal     OutChar                 #  Yes. Display Char
        add     t0, s6, s10
        sb      a0, -1(t0)              # s10 was already incremented
        j       RL_next_char
RL_insert:
        li      t0, 0x80
        bgeu    a0, t0, 0f
        jal     OutChar
    0:  addi    t0, s9, -1              # p = eol-1
    1:  bgtu    s10, t0, 2f             # while(p=>cp){buf(p)=buf(p-1); p--}
                                        #   if(s10>ip) goto2
        add     a1, s6, t0              #   a1=s6 + s9 - 1
        lbu     a2, -1(a1)
        sb      a2, (a1)
        addi    t0, t0, -1              #  t0--
        j       1b
    2:
        add     t0, s6, s10
        sb      a0, -1(t0)              # s10 was already incremented
        li      t0, 0x80
        bgeu    a0, t0, 3f
        jal     print_line_after_cp
        j       RL_next_char
    3:
        jal     print_line
        j       RL_next_char
RL_in_toolong:
        addi    s9, s9, -1
        addi    s10, s10, -1
        j       RL_next_char
RL_in_exit:
        jal     regist_history
        jal     NewLine
        mv      a0, s9                  #  a0 に文字数を返す
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

# -------------------------------------------------------------------------
#  BackSpace or Delete Character
# -------------------------------------------------------------------------
RL_bs:
        beq     s10, zero, RL_next_char
        jal     cursor_left

RL_delete:
        beq     s10, s9, RL_next_char   # 行末でDELでは何もしない
        add     t0, s6, s10
        lbu     a0, (t0)                #  1文字目確認
        andi    a0, a0, 0xC0
        li      t0, 0xC0
        bne     a0, t0, 1f              #  UTF-8の2文字目以降
        la      a0, DEL_AT_CURSOR       #  漢字なら2回1文字消去
        jal     OutPString
    1:  jal     RL_del1_char            #  1文字削除
        beq     s10, s9, 2f             #  行末なら終了
        add     t0, s6, s10
        lbu     a0, (t0)                #  2文字目文字取得
        andi    a0, a0, 0xC0
        li      t0, 0x80
        beq     a0, t0, 1b              #  UTF-8 後続文字 (ip==0x80)
    2:  la      a0, DEL_AT_CURSOR       #  1文字消去
        jal     OutPString
        j       RL_next_char

RL_del1_char:                           #  while(p<eol){*p++=*q++;}
        addi    sp, sp, -32
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        add     a2, s10, s6             #  p
        add     a1, s9, s6              #  eol
        addi    a3, a2, 1               #  q=p+1
    1:  lbu     a0, (a3)                #  *p++ = *q++;
        sb      a0, (a2)
        addi    a3, a3, 1
        addi    a2, a2, 1
        bleu    a3, a1, 1b
        addi    s9, s9, -1
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

# -------------------------------------------------------------------------
#  Filename Completion
# -------------------------------------------------------------------------
RL_tab:
        jal     FilenameCompletion      #  ファイル名補完
        jal     DispLine
        j       RL_next_char

# -------------------------------------------------------------------------
RL_cursor_left:
        jal     cursor_left
        j       RL_next_char

cursor_left:
        addi    sp, sp, -16
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        beq     s10, zero, 2f           #  先頭なら何もしない
        la      a0, CURSOR_LEFT         #  カーソル左移動、
        jal     OutPString
    1:
        addi    s10, s10, -1            #  文字ポインタ-=1
        add     t0, s6, s10
        lbu     a0, (t0)                #  文字取得
        andi    a0, a0, 0xC0
        li      t0, 0x80
        beq     a0, t0, 1b              #  第2バイト以降のUTF-8文字
        bltu    a0, t0, 2f              #  ASCII
        la      a0, CURSOR_LEFT         #  第1バイト発見、日本語は2回左
        jal     OutPString
    2:
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# -------------------------------------------------------------------------
RL_cursor_right:
        jal     cursor_right
        j       RL_next_char

cursor_right:
        addi    sp, sp, -32
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        beq     s9, s10, 3f             # if cp=eol then next_char
        la      a0, CURSOR_RIGHT
        jal     OutPString

        add     t0, s6, s10
        lbu     a0, (t0)                # 文字取得
        andi    a1, a0, 0x80
        bnez    a1, 1f                  # UTF-8多バイト文字の場合
        addi    s10, s10, 1             # ASCIIなら1バイトだけ
        j       3f
    1:
        andi    a1, a0, 0xF0
    2:  addi    s10, s10, 1             # 最大4byteまで文字位置を更新
        slli    a1, a1, 1
        andi    a1, a1, 0xF0
        bnez    a1, 2b
        la      a0, CURSOR_RIGHT
        jal     OutPString
    3:
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

# -------------------------------------------------------------------------
RL_forward:
        jal     regist_history          #  入力中の行をヒストリへ
        li      a0, 1
        jal     next_history
        j       RL_disp
RL_backward:
        jal     regist_history          #  入力中の行をヒストリへ
        li      a0, -1
        jal     next_history
RL_disp:
        andi    a0, a0, 0x0F            #  ヒストリは 0-15
        sd      a0, (s8)                #  HistLine
        jal     history2input           #  ヒストリから入力バッファ
        jal     DispLine
        j       RL_next_char

# -------------------------------------------------------------------------
#  行頭マージン設定
#    a0 : 行頭マージン設定
# -------------------------------------------------------------------------
set_linetop:
        addi    sp, sp, -16
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        la      a1, LINE_TOP
        sd      a0, (a1)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# --------------------------------------------------------------
#  入力バッファをヒストリへ登録
#    s6 : input buffer address
#    s8 : history string ptr
#    s9 : eol (length of input string)
#    a0,a1,a2,x3 : destroy
# --------------------------------------------------------------
regist_history:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra,  0(sp)

        add     t0, s6, s9
        sb      zero, (t0)              #  write 0 at eol
        jal     check_history
        beq     a1, zero, 1f            #  同一行登録済み

        ld      a0, 8(s8)               #  HistUpdate
        jal     input2history
        ld      a0, 8(s8)               #  HistUpdate
        addi    a0, a0, 1
        andi    a0, a0, 0x0F            #  16 entry
        sd      a0, 8(s8)               #  HistUpdate
        sd      a0, (s8)                #  HistLine
    1:
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# --------------------------------------------------------------
#  ヒストリを a0 (1または-1) だけ進める
#     return : a0 = next entry
# --------------------------------------------------------------
next_history:
        addi    sp, sp, -48
        sd      a4, 32(sp)
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)

        ld      a4, (s8)                #  HistLine
        li      a2, MAXHISTORY
        mv      a3, a0
    1:  addi    a2, a2, -1              #
        blt     a2, zero, 2f            #  すべて空なら終了
        add     a4, a4, a3              #  +/-1
        andi    a4, a4, 0x0F            #  wrap around
        mv      a0, a4                  #  次のエントリー
        jal     GetHistory              #  a0 = 先頭アドレス
        jal     StrLen                  #  <a0:アドレス, >a1:文字数
        beq     a1, zero, 1b            #  空行なら次
    2:  mv      a0, a4                  #  エントリーを返す

        ld      a4, 32(sp)
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

# --------------------------------------------------------------
#  すべてのヒストリ内容を表示
# --------------------------------------------------------------
disp_history:
        addi    sp, sp, -48
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)

        la      a2, history
        li      a3, 0                   # no. of history lines
    1:  la      a1, HistLine            # current history
        ld      a0, (a1)
        bne     a3, a0, 2f
        li      a0, '*'
        j       3f
    2:  li      a0, ' '
    3:  jal     OutChar
        mv      a0, a3                  # ヒストリ番号
        li      a1, 2                   # 2桁
        jal     PrintRight0
        li      a0, ' '
        jal     OutChar
        mv      a0, a2
        jal     OutAsciiZ
        jal     NewLine
        addi    a2, a2, MAXLINE         # next history string
        addi    a3, a3, 1
        li      t0, MAXHISTORY
        bne     a3, t0, 1b              # check next

        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

# --------------------------------------------------------------
#  すべてのヒストリ内容を消去
# --------------------------------------------------------------
erase_history:
        addi    sp, sp, -32
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        la      a2, history
        li      a1, 0                   # no. of history lines
        li      a0, 0
    1:  sd      a0, (a2)                # set zero only first 8bytes
        addi    a2, a2, MAXLINE         # next history
        addi    a1, a1, 1
        li      t0, MAXHISTORY
        bne     a1, t0, 1b              # check next
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

# --------------------------------------------------------------
#  入力バッファと同じ内容のヒストリバッファがあるかチェック
#    s6 : input buffer address
#    s9 : eol (length of input string)
#    a1 : if found then return 0
#    a0,a2,a3 : destroy
# --------------------------------------------------------------
check_history:
        addi    sp, sp, -32
        sd      a4, 24(sp)
        sd      s7, 16(sp)
        sd      s6,  8(sp)
        sd      ra,  0(sp)

        mv      a4, s6                  # save input buffer top
        la      s7, history
        li      a3, MAXHISTORY          # no. of history lines
    1:  mv      s6, a4                  # restore input buffer top
        li      a2, 0                   # string top
    2:  lbu     a0, (s6)                # a0 <-- input buffer
        addi    s6, s6, 1
        add     t0, s7, a2
        lbu     a1, (t0)                # a1 <-- history line
        bne     a0, a1, 3f              # different char
        beq     a0, zero, 4f            # eol found
        addi    a2, a2, 1               # next char
        j       2b
    3:  addi    s7, s7, MAXLINE         # next history line
        addi    a3, a3, -1              # counter
        bne     a3, zero, 1b            # check next
        li      a1, 1                   # compare all, not found
        j       5f

    4:  li      a1, 0                   # found
    5:  ld      a4, 24(sp)
        ld      s7, 16(sp)
        ld      s6,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

# --------------------------------------------------------------
#  入力バッファのインデックスをアドレスに変換
#    enter  a0 : ヒストリバッファのインデックス (0..15)
#    exit   a0 : historyinput buffer top address
# --------------------------------------------------------------
GetHistory:
        addi    sp, sp, -16
        sd      a2,  8(sp)
        sd      a1,  0(sp)
        li      a1, MAXLINE
        la      a2, history
        mul     a1, a0, a1
        add     a0, a1, a2              # a0=ind*MAXLINE+hist
        ld      a2,  8(sp)
        ld      a1,  0(sp)
        addi    sp, sp, 16
        ret

# --------------------------------------------------------------
#  入力バッファからヒストリバッファへコピー
#    a0 : ヒストリバッファのインデックス (0..15)
#    s6 : input buffer
# --------------------------------------------------------------
input2history:
        addi    sp, sp, -32
        sd      s6, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        mv      a1, s6
        jal     GetHistory
        mv      s6, a0
        j       1f                      # input --> history

# --------------------------------------------------------------
#  ヒストリバッファから入力バッファへコピー
#    a0 : ヒストリバッファのインデックス (0..15)
#    s6 : input buffer
# --------------------------------------------------------------
history2input:
        addi    sp, sp, -32
        sd      s6, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)

        jal     GetHistory
        mv      a1, a0                  # a1:address
    1:  lbu     a0, (a1)
        sb      a0, (s6)
        addi    a1, a1, 1
        addi    s6, s6, 1
        bne     a0, zero, 1b

        ld      s6, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

# --------------------------------------------------------------
#   入力バッファをプロンプト直後の位置から表示してカーソルは最終
#   entry  s6 : 入力バッファの先頭アドレス
# --------------------------------------------------------------
DispLine:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        jal     LineTop                 # カーソルを行先頭に
        mv      a0, s6
        jal     OutAsciiZ               # 入力バッファを表示
        la      a0, CLEAR_EOL
        jal     OutPString
        mv      a0, s6
        jal     StrLen                  # <a0:アドレス, >a1:文字数
        mv      s9, a1                  # 入力文字数更新
        mv      s10, s9                 # 入力位置更新
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# --------------------------------------------------------------
#  カーソル位置を取得してFLOATING_TOPに格納
get_cursor_position:
        addi    sp, sp, -48
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        la      a0, CURSOR_REPORT
        jal     OutPString
        jal     InChar                  # 返り文字列
        li      a1, 0x1B                # ^[[y;xR
        bne     a0, a1, 1f
        jal     InChar
        li      a1, '['
        bne     a0, a1, 1f
        jal     get_decimal             # Y
        mv      a3, a1
        jal     get_decimal             # X
        addi    a1, a1, -1
        la      a0, FLOATING_TOP
        sd      a1, (a0)                # 左マージン
    1:
        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

get_decimal:
        addi    sp, sp, -16
        sd      a3,  8(sp)
        sd      ra,  0(sp)
        jal     InChar
        li      a3, '0'
        sub     a0, a0, a3
        li      a1, 0
        li      a2, 10
    1:  mul     a2, a1, a0              #
        add     a1, a0, a2
        jal     InChar
        sub     a0, a0, a3
        li      a4, 9
        ble     a0, a4, 1b
        ld      a3,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# --------------------------------------------------------------
#  s10 = cursor position
print_line_after_cp:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        la      a0, SAVE_CURSOR
        jal     OutPString
        la      a0, CLEAR_EOL
        jal     OutPString
        add     a0, s10, s6             # address
        sub     a1, s9, s10             # length
        jal     OutString
        la      a0, RESTORE_CURSOR
        jal     OutPString
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# --------------------------------------------------------------
#
print_line:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        jal     LineTop
        mv      a0, s6                  # address
        mv      a1, s9                  # length
        jal     OutString
        jal     setup_cursor
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

setup_cursor:
        addi    sp, sp, -32
        sd      a2,  24(sp)
        sd      a1,  16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        jal     LineTop
        li      a1, 0
        beq     a1, s10, 4f
    1:  add     a2, s6, a1
        lbu     a0, (a2)
        andi    a0, a0, 0xC0
        li      t0, 0x80                # 第2バイト以降のUTF-8文字
        beq     a0, t0, 3f
        bltu    a0, t0, 2f
        la      a0, CURSOR_RIGHT
        jal     OutPString
    2:  la      a0, CURSOR_RIGHT
        jal     OutPString
    3:  addi    a1, a1, 1
        bne     a1, s10, 1b
    4:
        ld      a2,  24(sp)
        ld      a1,  16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# --------------------------------------------------------------
#  Translate Function Key into ctrl-sequence
translate_key_seq:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        jal     InChar
        li      t0, '['
        beq     a0, t0, 1f
        li      a0, 0
        j       7f                      # return

    1:  jal     InChar
        li      t0, 'A'
        bne     a0, t0, 2f
        li      a0, 'P' - 0x40          # ^P
        j       7f                      # return

    2:  li      t0, 'B'
        bne     a0, t0, 3f
        li      a0, 'N' - 0x40          # ^N
        j       7f                      # return

    3:  li      t0, 'C'
        bne     a0, t0, 4f
        li      a0, 'F' - 0x40          # ^F
        j       7f                      # return

    4:  li      t0, 'D'
        bne     a0, t0, 5f
        li      a0, 'B' - 0x40          # ^B
        j       7f                      # return

    5:  li      t0, '3'                 # ^((3~ (Del)
        bne     a0, t0, 6f
        li      t0, '4'                 # ^((4~ (End)
        j       7f                      # return

    6:  jal     InChar
        li      t0, '~'
        bne     a0, t0, 7f
        li      a0, 4                   # ^D

    7:
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# --------------------------------------------------------------
#  行先頭にカーソルを移動(左マージン付)
LineTop:
        addi    sp, sp, -32
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        la      a0, CURSOR_TOP
        jal     OutPString
        la      a0, CURSOR_RIGHT
        la      a2, FLOATING_TOP        # 左マージン
        ld      a2, (a2)
        beq     a2, zero, 2f            # if 0 return
    1:  jal     OutPString
        addi    a2, a2, -1
        bne     a2, zero, 1b
    2:
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

# --------------------------------------------------------------
#   ファイル名補完機能
#   entry  s10 : 次に文字が入力される入力バッファ中の位置
#          s6 : 入力バッファの先頭アドレス
# --------------------------------------------------------------
FilenameCompletion:
        addi    sp, sp, -80
        sd      t4, 64(sp)
        sd      t3, 56(sp)
        sd      s11, 48(sp)
        sd      s10, 40(sp)
        sd      s9, 32(sp)
        sd      s8, 24(sp)
        sd      s7, 16(sp)
        sd      s6,  8(sp)
        sd      ra,  0(sp)
        la      s7, FileNameBuffer      # FileNameBuffer初期化
        la      s11, DirName
        la      t3, FNArray             # ファイル名へのポインタ配列
        la      t4, PartialName         # 入力バッファ内のポインタ
        jal     ExtractFilename         # 入力バッファからパス名を取得
        lbu     a0, (s6)                # 行頭の文字
        beq     a0, zero, 1f            # 行の長さ0？
        jal     GetDirectoryEntry       # ファイル名をコピー
        jal     InsertFileName          # 補完して入力バッファに挿入
    1:
        ld      t4, 64(sp)
        ld      t3, 56(sp)
        ld      s11, 48(sp)
        ld      s10, 40(sp)
        ld      s9, 32(sp)
        ld      s8, 24(sp)
        ld      s7, 16(sp)
        ld      s6,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 80
        ret

# --------------------------------------------------------------
#  一致したファイル名が複数なら表示し、なるべく長く補完する。
#  t4:PartialName, t3:FNArray
#  一致するファイル名なしなら、<none>を入力バッファに挿入
#  完全に一致したらファイル名をコピー
#  入力バッファ末に0を追加、次に入力される入力バッファ中の位置
#  を更新. 入力バッファ中の文字数(s10)を返す。
# --------------------------------------------------------------
InsertFileName:
        addi    sp, sp, -48
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        bnez    s9, 1f                 # FNCount ファイル数
        la      a3, NoCompletion       # <none>を入力バッファに挿入
        j       7f                     # 一致するファイル名なし

    1:  ld      a0, (t4)               # 部分ファイル名
        jal     StrLen                 # a1 = 部分ファイル名長
        li      t0, 1                  # ひとつだけ一致?
        bne     s9, t0, 2f             # 候補複数なら2fへ
        ld      a0, (t3)               # FNArray[0]
        add     a3, a0, a1             # a3 = FNArray[0] + a1
        j       7f                     # 入力バッファに最後までコピー

    2:  jal     ListFile               # ファイルが複数なら表示

        #  複数が一致している場合なるべく長く補完
        #  最初のエントリーと次々に比較、すべてのエントリーが一致していたら
        #  比較する文字を1つ進める。一致しない文字が見つかったら終わり
        li      a2, 0                  # 追加して補完できる文字数
    3:  addi    a4, s9, -1             # ファイル数-1
        ld      a0, (t3)               # 最初のファイル名と比較
        add     a3, a0, a1             # a3 = FNArray[0]+部分ファイル名長
        add     t0, a3, a2
        lbu     a0, (t0)               # a0 = (FNArray[0] + 一致長 + a2)

    4:  slli    t0, a4, 3
        add     t0, t3, t0
        ld      s4, (t0)               # s4 = &FNArray(a4)
        add     s4, s4, a1             # s4 = FNArray(a4) + 一致長
        add     t0, s4, a2
        lbu     s4, (t0)               # s4 = FNArray(a4) + 一致長 + a2
        bne     a0, s4, 5f             # 異なる文字発見
        addi    a4, a4, -1             # 次のファイル名
        bnez    a4, 4b                 # すべてのファイル名で繰り返し
        addi    a2, a2, 1              # 追加して補完できる文字数を+1
        j       3b                     # 次の文字を比較
    5:  beq     a2, zero, 9f           # 追加文字なし?

    6:                                 # 複数あるが追加補完不可
        lbu     a0, (a3)               # 補完分をコピー
        add     t0, s6, s10
        sb      a0, (t0)               # 入力バッファに追加
        addi    a2, a2, -1
        blt     a2, zero, 9f           # 補完部分コピー終了
        addi    a3, a3, 1              # 次の文字
        addi    s10, s10, 1
        j       6b                     #

    7:  add     t0, s6, s10
    8:  lbu     a0, (a3)               # ファイル名をコピー
        addi    a3, a3, 1              # 次の文字
        sb      a0, (t0)               # 入力バッファに追加
        addi    t0, t0, 1
        bnez    a0, 8b                 # 文字列末の0で終了
        j       10f                    # コピー終了
    9:
        add     t0, s6, s10            # 補完終了
        sb      zero, (t0)             # 入力バッファ末を0
    10:
        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

# --------------------------------------------------------------
#  入力中の文字列からディレクトリ名と部分ファイル名を抽出して
#  バッファ DirName(s11), PartialName(t4)に格納
#  TABキーが押されたら入力バッファの最後の文字から逆順に
#  スキャンして、行頭またはスペースまたは " を探す。
#  行頭またはスペースの後ろから入力バッファの最後までの
#  文字列を解析してパス名(s11)とファイル名(t4)バッファに保存
#   entry  s10 : 次に文字が入力される入力バッファ中の位置
#          s6 : 入力バッファの先頭アドレス
# --------------------------------------------------------------
ExtractFilename:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        add     a3, s10, s6             # (入力済み位置+1)をa3に
        mv      a1, a3
        sb      zero, (a1)              # 入力済み文字列末をマーク
        mv      s8, s7                  # FNBPointer=FileNameBuffer
        li      s9, 0                   # FNCount=0
    1:                                  # 部分パス名の先頭を捜す
        lbu     a0, (a1)                # カーソル位置から前へ
        li      t0, 0x20                # 空白はパス名の区切り
        beq     a0, t0, 2f              # 空白なら次の処理
        li      t0, '"'                 # " 二重引用符もパス名の区切り
        beq     a0, t0, 2f              # 二重引用符でも次の処理
        beq     a1, s6, 3f              # 行頭なら次の処理
        addi    a1, a1, -1              # 後ろから前に検索
        j       1b                      # もう一つ前を調べる

    2:  addi    a1, a1, 1               # 発見したら部分パス名の先頭に
    3:  lbu     a0, (a1)
        bnez    a0, 4f                  # 行末でなければ 4f へ
        ld      a0,  8(sp)              # 何もない(長さ0)なら終了
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

    4:  addi    a3, a3, -1              # 入力済み文字列最終アドレス
        lbu     a0, (a3)                # 入力済みのパスの / を探す
        li      t0, '/'
        beq     a0, t0, 5f              # 発見したら5f
        bne     a1, a3, 4b              # 前方にさらに/を探す
        j       6f                      # a1=a3 なら「/」は無い

    5:  addi    a3, a3, 1               # ファイル名から/を除く
    6:  # ディレクトリ名をコピー
        sb      zero, (s11)             # ディレクトリ名バッファを空に
        sd      a3, (t4)                # 部分ファイル名先頭
        sub     a2, a3, a1              # a2=ディレクトリ名文字数
        beq     a2, zero, 8f            # ディレクトリ部分がない

        mv      s4, s11                 # DirName
    7:  lbu     a0, (a1)                # コピー
        sb      a0, (s4)                # ディレクトリ名バッファ
        addi    a1, a1, 1
        addi    s4, s4, 1
        sb      a0, (s4)                # 文字列末をマーク
        addi    a2, a2, -1
        bnez    a2, 7b
    8:
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# -------------------------------------------------------------------------
#  ディレクトリ中のエントリをgetdentsで取得(1つとは限らないのか?)して、
#  1つづつファイル/ディレクトリ名をlstatで判断し、
#  ディレクトリ中で一致したファイル名をファイル名バッファに書き込む。
# -------------------------------------------------------------------------
GetDirectoryEntry:
        addi    sp, sp, -48
        sd      a4, 40(sp)
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        lbu     a0, (s11)               # ディレクトリ部分の最初の文字
        bnez    a0, 1f                  # 長さ 0 か?
        la      a0, current_dir         # ディレクトリ部分がない時
        j       2f

    1:  mv      a0, s11                 # ディレクトリ名バッファ
    2:  jal     fropen                  # ディレクトリオープン
        bltz    a0, 5f                  # システムコールエラーなら終了
        mv      a3, a0                  # fd 退避
    3:  #  ディレクトリエントリを取得
        #  uint fd, struct linux_dirent64 *dirp, uint count
        mv      a0, a3                  # fd 復帰
        la      a1, dir_ent             # dir_ent格納先頭アドレス
        mv      a4, a1                  # a4 : dir_entへのポインタ
        li      a2, size_dir_ent        # dir_ent格納領域サイズ
        li      a7, sys_getdents64      # dir_entを複数返す
        ecall
        bltz    a0, 5f                  # valid buffer length
        beqz    a0, 6f                  # 終了
        mv      a2, a0                  # a2 : buffer size
    4:  #  dir_entからファイル情報を取得
        mv      a1, a4                  # a4 : dir_entへのポインタ
        jal     GetFileStat             # ファイル情報を取得
        la      a1, file_stat
        ld      a0, 16(a1)              # file_stat.st_mode
        li      t0, S_IFDIR
        and     a0, a0, t0              # ディレクトリ?
        addi    a1, a4, 19              # ファイル名先頭アドレス
        jal     CopyFilename            # 一致するファイル名を収集

        #  sys_getdentsが返したエントリが複数の場合には次のファイル
        #  1つなら次のディレクトリエントリを得る。
        lh      a0, 16(a4)              # rec_len レコード長
        sub     a2, a2, a0              # buffer_size - rec_len
        beqz    a2, 3b                  # 次のディレクトリエントリ取得
        add     a4, a4, a0              # 次のファイル名の格納領域に設定
        j       4b                      # 次のファイル情報を取得

    5:
.ifdef DETAILED_MSG
        jal     SysCallError            # システムコールエラー
.endif
    6:  mv      a0, a3                  # fd
        jal     fclose                  # ディレクトリクローズ
        ld      a4, 40(sp)
        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

# --------------------------------------------------------------
#  DirNameとdir_ent.dnameからPathNameを作成
#  PathNameのファイルの状態をfile_stat構造体に取得
#  entry
#    a1 : dir_entアドレス
#    s11 : DirName
#    DirName にディレクトリ名
# --------------------------------------------------------------
GetFileStat:
        addi    sp, sp, -48
        sd      a4, 40(sp)
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        addi    a2, a1, 19              # dir_ent.d_name + x
        la      a3, PathName            # PathName保存エリア
        mv      s4, a3
        mv      a0, s11                 # DirNameディレクトリ名保存アドレス
        jal     StrLen                  # ディレクトリ名の長さ取得>r1
        beq     a1, zero, 2f

    1:  lbu     a4, (a0)                # ディレクトリ名のコピー
        sb      a4, (s4)                # PathNameに書き込み
        addi    a0, a0, 1
        addi    s4, s4, 1
        addi    a1, a1, -1              # -1になるため, bne不可
        bne     a1, zero, 1b

    2:  mv      a0, a2                  # ファイル名の長さ取得
        jal     StrLen                  # <r0:アドレス, >r1:文字数
    3:  lbu     a4, (a2)                # ファイル名のコピー
        sb      a4, (s4)                # PathNameに書き込み
        addi    a2, a2, 1
        addi    s4, s4, 1
        addi    a1, a1, -1
        bne     a1, zero, 3b
        sb      a1, (s4)                # 文字列末(0)をマーク
        li      a0, AT_FDCWD            # 第1引数 dirfd
        mv      a1, a3                  # パス名先頭アドレス
        la      a2, file_stat           # file_stat0のアドレス
        li      a3, 0                   # flags
        li      a7, sys_fstatat         # ファイル情報の取得
        ecall
        bgt     a0, zero, 4f            # valid buffer length
.ifdef DETAILED_MSG
        jal     SysCallError            # システムコールエラー
.endif
    4:  ld      a4, 40(sp)
        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

# --------------------------------------------------------------
#  ディレクトリ中のファイル名ごとに呼ばれ、部分ファイル名に一致した
#  ファイル名をファイル名バッファ (FileNameBuffer)に追記する
#  ファイル名がディレクトリ名なら"/"を付加する
#  entry a0 : ディレクトリフラグ
#        a1 : ファイル名先頭アドレス
#        t4 : 部分ファイル名先頭アドレス格納領域へのポインタ
# --------------------------------------------------------------
CopyFilename:
        addi    sp, sp, -48
        sd      a4, 40(sp)
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        li      t0, MAX_FILE            # 256
        bgeu    s9, t0, 5f              # FNCount>=MAX_FILEなら終了
        mv      a3, a1                  # ファイル名先頭アドレス
        mv      a4, a0                  # ディレクトリフラグ
        ld      a2, (t4)                # t4:PartialName
    1:  lbu     a0, (a2)                # 部分ファイル名
        addi    a2, a2, 1
        beqz    a0, 2f                  # 文字列末?部分ファイル名は一致
        lbu     t0, (a1)                # ファイル名
        addi    a1, a1, 1
        bne     a0, t0, 5f              # 1文字比較  異なれば終了
        j       1b                      # 次の文字を比較

    2:  #  一致したファイル名が格納できるかチェック
        mv      a0, a3                  # ファイル名先頭アドレス
        jal     StrLen                  # ファイル名の長さを求める
        mv      a2, a1                  # ファイル名の長さを退避
        addi    t0, a1, 2               # 文字列末の /0
        add     t0, s8, t0              # 追加時の最終位置 s8:FNBPointer
                                        # FileNameBufferの直後(FNArray0)
        bgeu    t0, t3, 5f              # バッファより大きくなる:終了
        #  ファイル名バッファ中のファイル名先頭アドレスを記録
        slli    t0, s9, 3
        add     t0, t3, t0
        sd      s8, (t0)                # FNArray[FNCount]=s8
        addi    s9, s9, 1               # ファイル名数の更新

    3:  lbu     t0, (a3)                # ファイル名のコピー
        sb      t0, (s8)
        addi    a3, a3, 1
        addi    s8, s8, 1
        addi    a2, a2, -1              # ファイル名の長さを繰り返す
        bnez    a2, 3b

        beqz    a4, 4f                  # ディレクトリフラグ
        li      a0, '/'                 # ディレクトリ名なら"/"付加
        sb      a0, (s8)
    4:  sb      zero, (s8)              # 文字列末(0)の書き込み
        addi    s8, s8, 2               # FNBPointer を更新
    5:
        ld      a4, 40(sp)
        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

# --------------------------------------------------------------
#  ファイル名バッファの内容表示
# --------------------------------------------------------------
ListFile:
        addi    sp, sp, -48
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        jal     NewLine
        li      a3, 0                   # 個数
    1:
        slli    t0, a3, 3
        add     t0, t3, t0              # t3:ファイル名へのポインタ配列
        ld      a2, (t0)                # FNArray + FNCount * 8
        mv      a0, a3
        li      a1, 4                   # 4桁
        jal     PrintRight              # 番号表示
        li      a0, 0x20
        jal     OutChar
        mv      a0, a2
        jal     OutAsciiZ               # ファイル名表示
        jal     NewLine
        addi    a3, a3, 1
        blt     a3, s9, 1b
    2:
        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

# --------------------------------------------------------------
#  現在の termios を保存
# --------------------------------------------------------------
GET_TERMIOS:
        addi    sp, sp, -48
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        la      a1, old_termios
        mv      a3, a1                  # old_termios
        jal     tcgetattr
        la      a2, new_termios
        mv      a1, a3                  # old_termios
        sub     a3, a2, a1
    1:  lbu     a0, (a1)
        sb      a0, (a2)
        addi    a1, a1, 1
        addi    a2, a2, 1
        addi    a3, a3, -1
        bne     a3, zero, 1b

        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

# --------------------------------------------------------------
#  新しい termios を設定
#  Rawモード, ECHO 無し, ECHONL 無し
#  VTIME=0, VMIN=1 : 1バイト読み取られるまで待機
# --------------------------------------------------------------
SET_TERMIOS:
        addi    sp, sp, -32
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        la      a2, new_termios
        lwu     a0, 12(a2)              # c_lflag
        la      a1, termios_mode
        lwu     a1, (a1)
        and     a0, a0, a1
        li      t0, ISIG
        or      a0, a0, t0
        sw      a0, 12(a2)
        li      a0, 0
        la      a1, nt_c_cc
        li      a0, 1
        sb      a0, VMIN(a1)
        li      a0, 0
        sb      a0, VTIME(a1)
        la      a1, new_termios
        jal     tcsetattr
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

termios_mode:   .long   ~ICANON & ~ECHO & ~ECHONL

# --------------------------------------------------------------
#  現在の termios を Cooked モードに設定
#  Cookedモード, ECHO あり, ECHONL あり
#  VTIME=1, VMIN=0
# --------------------------------------------------------------
SET_TERMIOS2:
        addi    sp, sp, -32
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra,  0(sp)
        la      a2, new_termios
        ld      a0, 12(a2)              # c_lflag
        la      a1, termios_mode2
        lwu     a1, (a1)
        or      a0, a0, a1
        ori     a0, a0, ISIG
        sw      a0, 12(a2)
        li      a0, 0
        la      a1, nt_c_cc
        li      a0, 0
        sb      a0, VMIN(a1)
        li      a0, 1
        sb      a0, VTIME(a1)
        la      a1, new_termios
        jal     tcsetattr
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret
termios_mode2:   .long   ICANON | ECHO | ECHONL

# --------------------------------------------------------------
#  保存されていた termios を復帰
# --------------------------------------------------------------
RESTORE_TERMIOS:
        addi    sp, sp, -16
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        la      a1, old_termios
        jal     tcsetattr
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# --------------------------------------------------------------
#  標準入力の termios の取得と設定
#  tcgetattr(&termios)
#  tcsetattr(&termios)
#  a0 : destroyed
#  a1 : termios buffer address
# --------------------------------------------------------------
tcgetattr:
        li      a0, TCGETS
        j       IOCTL

tcsetattr:
        li      a0, TCSETS

# --------------------------------------------------------------
#  標準入力の ioctl の実行
#  sys_ioctl(unsigned int fd, unsigned int cmd,
#            unsigned long arg)
#  a0 : cmd
#  a1 : buffer address
# --------------------------------------------------------------
IOCTL:
        addi    sp, sp, -32
        sd      a7, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        mv      a2, a1                  # set arg
        mv      a1, a0                  # set cmd
        li      a0, 0                   # 0 : to stdin
        li      a7, sys_ioctl
        ecall
.ifdef DETAILED_MSG
        jal     SysCallError            # システムコールエラー
.endif
        ld      a7, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

# --------------------------------------------------------------
#  input 1 character from stdin
#  a0 : get char (0:not pressed)
# --------------------------------------------------------------
RealKey:
        addi    sp, sp, -48
        sd      a4, 32(sp)
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        la      a3, nt_c_cc
        li      a0, 0
        sb      a0, VMIN(a3)
        la      a1, new_termios
        jal     tcsetattr
        li      a0, 0                   # a0  stdin
        addi    a1, sp, 8               # a1(stack) address
        li      a2, 1                   # a2  length
        li      a7, sys_read
        ecall
        mv      a4, a0
        beqz    a0, 1f                  # if 0 then empty
        lbu     a4, (a1)                # char code
    1:  li      a1, 1
        sb      a1, VMIN(a3)
        la      a1, new_termios
        jal     tcsetattr
        mv      a0, a4
        ld      a4, 32(sp)
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 48
        ret

# -------------------------------------------------------------------------
#  get window size
#  a0 : column(upper 16bit), raw(lower 16bit)
# -------------------------------------------------------------------------
WinSize:
        addi    sp, sp, -32
        sd      a7, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        li      a0, 0                   # to stdout
        li      a1, TIOCGWINSZ          # get wondow size
        la      a2, winsize
        li      a7, sys_ioctl
        ecall
        ld      a0, (a2)                # winsize.ws_row
        ld      a7, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

# -------------------------------------------------------------------------
#  ファイルをオープン
#  enter   a0: 第１引数 filename
#  return  a0: fd, if error then a0 will be negative.
# -------------------------------------------------------------------------
fropen:
        addi    sp, sp, -32
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        li      a2,  O_RDONLY           # 第3引数 flag
        j       1f
fwopen:
        addi    sp, sp, -32
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        li      a2, O_CREAT | O_WRONLY | O_TRUNC
    1:
        mv      a1, a0                  # 第2引数 filename
        li      a0, AT_FDCWD            # 第1引数 dirfd
        li      a3, 0644                # 第4引数 mode
        li      a7, sys_openat          # システムコール番号
        ecall
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 32
        ret

# -------------------------------------------------------------------------
#  ファイルをクローズ
#  enter   a0 : 第１引数 ファイルディスクリプタ
# -------------------------------------------------------------------------
fclose:
        addi    sp, sp, -16
        sd      a7,  8(sp)
        sd      ra,  0(sp)
        li      a7, sys_close
        ecall
        ld      a7,  8(sp)
        ld      ra,  0(sp)
        addi    sp, sp, 16
        ret

# ==============================================================
.data
                    .align  2
CURSOR_REPORT:      .byte   4, 0x1B
                    .ascii  "[6n"          #  ^[[6n
                    .align  2
SAVE_CURSOR:        .byte   2, 0x1B, '7'   #  ^[[7
                    .align  2
RESTORE_CURSOR:     .byte   2, 0x1B, '8'   #  ^[[8
                    .align  2
DEL_AT_CURSOR:      .byte   4, 0x1B
                    .ascii  "[1P"          #  ^[[1P
                    .align  2
CURSOR_RIGHT:       .byte   4, 0x1B
                    .ascii  "[1C"          #  ^[[1C
                    .align  2
CURSOR_LEFT:        .byte   4, 0x1B
                    .ascii  "[1D"          #  ^[[1D
                    .align  2
CURSOR_TOP:         .byte   1, 0x0D
                    .align  2
CLEAR_EOL:          .byte   4, 0x1B
                    .ascii  "[0K"          #  ^[[0K
                    .align  2
CSI:                .byte   2, 0x1B, '['   #  ^[[

                    .align  2
NoCompletion:       .asciz  "<none>"
                    .align  2
current_dir:        .asciz  "./"

                    .align  2
LINE_TOP:           .quad   7          #  No. of prompt characters
FLOATING_TOP:       .quad   7          #  Save cursor position

# ==============================================================
.bss
                    .align  2
HistLine:           .quad   0
HistUpdate:         .quad   0
input:              .skip   MAXLINE

                    .align  2
history:            .skip   MAXLINE * MAXHISTORY

                    .align  2
DirName:            .skip   MAXLINE
PathName:           .skip   MAXLINE

                    .align  2
PartialName:        .quad   0           #  部分ファイル名先頭アドレス格納
FileNameBuffer:     .skip   2048, 0     #  2kbyte for filename completion
FNArray:            .skip   MAX_FILE*8  #  long* Filename(0..255)
FNBPointer:         .quad   0           #  FileNameBufferの格納済みアドレス+1
FNCount:            .quad   0           #  No. of Filenames

                    .align  2
old_termios:
ot_c_iflag:         .long   0           #  input mode flags
ot_c_oflag:         .long   0           #  output mode flags
ot_c_cflag:         .long   0           #  control mode flags
ot_c_lflag:         .long   0           #  local mode flags
ot_c_line:          .byte   0           #  line discipline
ot_c_cc:            .skip   NCCS        #  control characters

                    .align  2
new_termios:
nt_c_iflag:         .long   0           #  input mode flags
nt_c_oflag:         .long   0           #  output mode flags
nt_c_cflag:         .long   0           #  control mode flags
nt_c_lflag:         .long   0           #  local mode flags
nt_c_line:          .byte   0           #  line discipline
nt_c_cc:            .skip   NCCS        #  control characters

                    .align  2
new_sig:
nsa_sighandler:     .quad   0           #   0
nsa_mask:           .quad   0           #   8
nsa_flags:          .quad   0           #  16
nsa_restorer:       .quad   0           #  24
old_sig:
osa_sighandler:     .quad   0           #  32
osa_mask:           .quad   0           #  40
osa_flags:          .quad   0           #  48
osa_restorer:       .quad   0           #  56

TV:
tv_sec:             .quad   0
tv_usec:            .quad   0
TZ:
tz_minuteswest:     .quad   0
tz_dsttime:         .quad   0

winsize:
ws_row:             .hword  0
ws_col:             .hword  0
ws_xpixel:          .hword  0
ws_ypixel:          .hword  0

ru:                                 # 18 words
ru_utime_tv_sec:    .long   0       # user time used
ru_utime_tv_usec:   .long   0       #
ru_stime_tv_sec:    .long   0       # system time used
ru_stime_tv_usec:   .long   0       #
ru_maxrss:          .long   0       # maximum resident set size
ru_ixrss:           .long   0       # integral shared memory size
ru_idrss:           .long   0       # integral unshared data size
ru_isrss:           .long   0       # integral unshared stack size
ru_minflt:          .long   0       # page reclaims
ru_majflt:          .long   0       # page faults
ru_nswap:           .long   0       # swaps
ru_inblock:         .long   0       # block input operations
ru_oublock:         .long   0       # block output operations
ru_msgsnd:          .long   0       # messages sent
ru_msgrcv:          .long   0       # messages received
ru_nsignals:        .long   0       # signals received
ru_nvcsw:           .long   0       # voluntary context switches
ru_nivcsw:          .long   0       # involuntary

                    .align  2
dir_ent:                            #  256 bytesのdir_ent格納領域
#        u64             d_ino;     #  0
#        s64             d_off;     #  8
#        unsigned short  d_reclen;  #  16
#        unsigned char   d_type;    #  18
#        char            d_name(0); #  19    ディレクトリエントリの名前
#  -----------------------------------------------------------------------
#  de_d_ino:         .long   0      #  0
#  de_d_off:         .long   0      #  4
#  de_d_reclen:      .hword  0      #  8
#  de_d_name:                       #  10    ディレクトリエントリの名前
                    .skip   512

                    .align  2
#  from linux-4.1.2/include/uapi/asm-generic/stat.h
file_stat:                          #  128 bytes
fs_st_dev:          .quad   0       #  0  ファイルのデバイス番号
fs_st_ino:          .quad   0       #  8  ファイルのinode番号
fs_st_mode:         .long   0       #  16 ファイルのアクセス権とタイプ
fs_st_nlink:        .long   0       #  20
fs_st_uid:          .long   0       #  24
fs_st_gid:          .long   0       #  28
fs_st_rdev:         .quad   0       #  32
fs_st_pad1:         .quad   0       #  40
fs_st_size:         .quad   0       #  48 ファイルサイズ(byte)
fs_st_blksize:      .long   0       #  56 ブロックサイズ
fs_st_pad2:         .long   0       #  60
fs_st_blocks:       .quad   0       #  64
fs_st_atime:        .quad   0       #  72 ファイルの最終アクセス日時
fs_st_atime_nsec:   .quad   0       #  80 ファイルの最終アクセスnsec
fs_st_mtime:        .quad   0       #  88 ファイルの最終更新日時
fs_st_mtime_nsec:   .quad   0       #  96 ファイルの最終更新nsec
fs_st_ctime:        .quad   0       # 104 ファイルの最終status変更日時
fs_st_ctime_nsec:   .quad   0       # 112 ファイルの最終status変更nsec
fs___unused4:       .long   0       # 120
fs___unused5:       .long   0       # 124

.endif

