# -------------------------------------------------------------------------
#  Return of the Very Tiny Language for RISC-V
#  file : rvtl64.s
#  2025-07-28
#  Copyright (C) 2024-2025 Jun Mizutani <mizutani.jun@nifty.ne.jp>
#  rvtl.s may be copied under the terms of the GNU General Public License.
# -------------------------------------------------------------------------
# as -o rvtl64.o rvtl64.s
# ld -o rvtlw rvtl64.o

.option rvc

ARGMAX      =   15
VSTACKMAX   =   1024
MEMINIT     =   256*1024
LSTACKMAX   =   127
FNAMEMAX    =   256
LABELMAX    =   1024
VERSION     =   40000
VERSION64   =   1
CPU         =   6

.ifndef SMALL_VTL
  VTL_LABEL    = 1
  DETAILED_MSG = 1
  # FRAME_BUFFER = 1
.endif

.ifdef  DETAILED_MSG
  .include      "syserror.s"
.endif

.ifdef  FRAME_BUFFER
  .include      "fblib.s"
.endif

.ifdef  DEBUG
  .include      "debug.s"
.endif

.include "vtllib.s"
.include "vtlsys.s"
.include "mt19937ar.s"

#==============================================================
        .text
        .global _start

_start:
        .align  2
        .option norelax
#-------------------------------------------------------------------------
# システムの初期化
#-------------------------------------------------------------------------
        # コマンドライン引数の数をスタックから取得し、[argc] に保存
        ld      a5, (sp)                # a5 = argc
        la      a4, argc                # argc 引数の数を保存
        sd      a5, (a4)                # argc
        addi    a1, sp, 8               # argvp
        sd      a1, 8(a4)               # argvp 引数配列先頭を保存

        # 環境変数格納アドレスをスタックから取得し、[envp] に保存
        addi    s0, a5, 2
        slli    s0, s0, 3               # s0 = (argc + 2) * 8
        add     a2, sp, s0              # a2 = sp + argc * 8
        sd      a2, 16(a4)              # envp 環境変数領域の保存

        # コマンドラインの引数を走査
        li      a3, 1
        beq     a5, a3, 4f              # 引数なしならスキップ
    1:
        slli    s0, a3, 3               # s0 = a3 * 8
        add     s0, a1, s0              # a6 = a3 * 8 + argvp
        ld      a6, (s0)                # a6 = argvp[a3]
        lbu     a6, (a6)                # a6 = argvp[a3][0]
        addi    a3, a3, 1
        li      s0, '-'
        beq     a6, s0, 2f              # 「-」発見
        bne     a3, a5, 1b
        j       3f                      # 「-」なし
    2:
        addi    a6, a3, -1              # rvtl用の引数の数
        sd      a6, (a4)                # argc 引数の数を更新

    3:  slli    s0, a3, 3               # s0 = a3 * 8
        add     a6, a1, s0              # s0 = a3 * 8 + argvp
        sd      a6, 32(a4)              # vtl用の引数文字列配列先頭(argvp_vtl)
        sub     a3, a5, a3
        sd      a3, 24(a4)              # vtl用の引数の個数 (argc_vtl)

    4:  # argv[0]="xxx/rvtlw" ならば cgiモード
        li      a2, 0
        la      a3, cginame             # 文字列 'wltvr',0
        ld      a1, 8(a4)               # argvp
        ld      a0, (a1)                # argv[0]
        li      a5, 0                   # cgiflag = 0
    5:  lbu     a6, (a0)                # argv[0]の文字列末のゼロを検索
        addi    a0, a0, 1               # 文字列の最終文字位置(w)
        bne     a6, zero, 5b            # a1!=0 then 5b
        addi    a0, a0, -2
    6:  lbu     a1, (a0)                # argv[0]を逆順で読む
        addi    a0, a0, -1
        lbu     a6, (a3)                # 'wltvr' を比較
        addi    a3, a3, 1
        beq     a6, zero, 7f            # 文字列末まで一致
        bne     a1, a6, 8f              # no
        j       6b
    7:  li      a4, 1                   # cgiflag = 1
    8:  la      a3, cgiflag
        sd      a4, (a3)                # set cgiflag=1, cgiモード

        # gp に変数領域の先頭アドレスを設定、変数のアクセスはgpを使う
        la      gp, VarArea             # gp の内容は常に VarArea

        # システム変数の初期値を設定
        li      a0, 0                   # 0 を渡して現在値を得る
        li      a7, sys_brk             # brk取得
        ecall
        mv      t2, a0                  # 初期brk値
        addi    s0, gp, ',' * 8         # プログラム先頭 (,)
        sd      a0, (s0)                # a0 -> [','*8+VarArea]
        addi    s0, gp, '=' * 8         # プログラム先頭 (=)
        sd      a0, (s0)                # a0 -> ['='*8+VarArea]
        addi    t3, a0, 4               # プログラム末マーク
        addi    s0, gp, '&' * 8
        sd      t3, (s0)                # VTLプログラムの最終使用アドレス
        li      a1, MEMINIT             # MEMINIT=256*1024
        add     a0, a0, a1              # 初期ヒープ最終
        addi    s0, gp, '*' * 8         # RAM末設定 (*)
        sd      a0, (s0)
        ecall                           # brk設定
        li      a1, -1                  # -1
        sw      a1, (t2)                # コード末マーク
        li      a0, 672274774           # 初期シード値
        addi    s0, gp, '`' * 8         # 乱数シード設定
        sd      a0, (s0)
        jal     sgenrand

        # 現在の端末設定を保存し、端末をローカルエコーOFFに再設定
        jal     GET_TERMIOS             # termios の保存
        jal     SET_TERMIOS             # 端末のローカルエコーOFF

        # ctrl-C, ctrl-Z用のシグナルハンドラを登録する
        li      a1, 0                   # シグナルハンドラ設定
        la      a4, new_sig
        la      a0, SigIntHandler
        sd      a0, (a4)                # nsa_sighandler
        sd      a1, 8(a4)               # nsa_mask
        li      a0, SA_NOCLDSTOP        # 子プロセス停止を無視
        li      a1, SA_RESTORER
        or      a0, a0, a1
        sd      a0, 16(a4)              # nsa_flags
        la      a0, SigReturn
        sd      a0, 24(a4)              # nsa_restorer

        li      a0, SIGINT              # ^C
        mv      a1, a4                  # new_sig
        li      a2, 0                   # old_sig
        li      a3, 8                   # size
        li      a7, sys_rt_sigaction
        ecall

        li      a0, SIG_IGN             # シグナルの無視
        sd      a0, (a4)                # nsa_sighandler
        li      a0, SIGTSTP             # ^Z
        li      a7, sys_rt_sigaction
        ecall

        # PIDを取得して保存(initの識別)、pid=1 なら環境変数設定
        li      a7, sys_getpid
        ecall

        sd      a0, -40(gp)             # pid の保存
        li      a1, 1
        bne     a0, a1, go

        la      a1, envp                # pid=1 なら環境変数設定
        la      a0, env                 # 環境変数配列先頭アドレス
        sd      a0, (a1)
        la      a1, envstr              # pid=1 なら環境変数設定
        sd      a1, (a0)                # env[0] に @envstr を格納

        # /etc/init.vtlが存在すれば読み込む
        la      a0, initvtl             # /etc/init.vtl
        jal     fropen                  # open
        ble     a0, zero, go            # init.vtlが無ければgoへ
        sd      a0, -16(gp)             # FileDesc
        jal     WarmInit2               # コンソール入力指定と初期化
        li      a0, 1
        sb      a0, -4(gp)              # ファイル入力を指定
        sb      a0, -2(gp)              # EOL=yes [gp-2]は未使用
        mv      s1, a0                  # EOLフラグ
        j       Launch
    go:
        jal     WarmInit2               # コンソール入力指定と初期化
        li      a0, 0
        la      a1, counter
        sd      a0, (a1)                # コマンド実行カウント初期化
        addi    a1, a1, 16              # current_arg
        sd      a0, (a1)                # 処理済引数カウント初期化
        jal     LoadCode                # あればプログラムロード
        bgt     a0, zero, Launch

.ifndef SMALL_VTL
        la      a0, start_msg           # 起動メッセージ
        jal     OutAsciiZ
.endif

Launch:         # 初期化終了
        la      a1, save_stack
        mv      a0, sp
        sd      a0, (a1)                # スタックを保存

#-------------------------------------------------------------------------
# メインループ
#-------------------------------------------------------------------------
MainLoop:
        # SIGINTを受信(ctrl-Cの押下)を検出したら初期状態に戻す
        lbu     a2, -5(gp)
        beqz    a2, 1f                  # SIGINT 受信?
    0:  jal     WarmInit                # 実行停止
        j       3f

    1:  lbu     a2, -6(gp)              # 0除算エラー?
        beqz    a2, 2f
        la      a0, err_div0            # 0除算メッセージ
        jal     OutAsciiZ
        j       0b

        # 式中でエラーを検出したらメッセージを表示して停止
    2:  lbu     a2, -7(gp)              # 式中にエラー?
        bnez    a2, Exp_Error           # 式中でエラー発生

        # 行末をチェック (初期化直後は EOL=1)
    3:  beqz    s1, 4f                  # EOL

        # 次行取得 (コンソール入力またはメモリ上のプログラム)
        lbu     a2, -3(gp)              # ExecMode
        beqz    a2, ReadLine            # ExecMode=Memory ?
        j       ReadMem                 # メモリから行取得

    4:  jal     GetChar
    5:  li      s0, ' '                 # 空白読み飛ばし
        bne     tp, s0, 6f
        jal     GetChar
        j       5b

    6:  jal     IsNum                   # 行番号付なら編集モード
        bltz    a0, 7f                  # a0=-1なら非数値
        jal     EditMode                # 編集モード
        j       MainLoop

    7:  la      a2, counter
        ld      a0, (a2)
        addi    a0, a0, 1
        sd      a0, (a2)
        jal     IsAlpha                 # 英文字なら変数代入
        bltz    a0, Command             # コマンド実行
    8:  jal     SetVar                  # 変数代入
        j       MainLoop

LongJump:
        la      a2, save_stack
        ld      a0, (a2)                # スタックを復帰
        mv      sp, a0
        la      a0, err_exp             # 式中に空白
        j       Error
Exp_Error:
        li      s0, 1
        bne     a2, s0, 10f
        la      a0, err_space           # 式中の空白はエラー
        j       Error
    10: li      s0, 2
        bne     a2, s0, 11f
        la      a0, err_vstack          # 変数スタックエラー
        j       Error
    11: li      s0, 3
        bne     a2, s0, 12f
        la      a0, err_label           # ラベル未定義メッセージ
        j       Error
    12: li      s0, 4
        bne     a2, s0, 13f
        la      a0, err_doublequote     # 式中に「"」
        j       Error
    13:
        la      a0, err_unknown         # 式のエラー
        j       Error

#-------------------------------------------------------------------------
# キー入力またはファイル入力されたコードを実行
#-------------------------------------------------------------------------
ReadLine:
        # 1行入力 : キー入力とファイル入力に対応
        lbu     a0, -4(gp)              # Read from console
        beqz    a0, 1f                  # コンソールから入力
        jal     READ_FILE               # ファイルから入力
        j       MainLoop

    1:  jal     DispPrompt              # プロンプトを表示
        la      a1, input2
        li      a0, MAXLINE             # コンソールから1行入力
        jal     READ_LINE               # 編集機能付キー入力
        mv      t2, a1                  # 入力バッファ先頭
        mv      t1, t2
        li      s1, 0                   # not EOL
        j       MainLoop

#-------------------------------------------------------------------------
# メモリに格納されたコードの次行をt2に設定
# t1 : 行先頭アドレス
#-------------------------------------------------------------------------
ReadMem:
        lw      a0, (t1)                # 次行へのオフセット
        ble     a0, zero, 1f            # コード末なら実行終了
        add     t1, t1, a0              # Next Line
        # 現在の行番号を # に設定し、コード部分先頭アドレスを t2 に設定
        jal     SetLineNo               # 行番号を # に設定
        addi    t2, t1, 8               # 行のコード先頭
        li      s1, 0                   # EOL=no
        j       MainLoop

        # コード末ならばコンソール入力(ダイレクトモード)に設定し、
        # EOLを1とすることで、次行取得を促す
    1:  jal     CheckCGI                # CGIモードなら終了
        li      a0, 0
        li      s1, 1                   # EOL=yes
        sb      a0, -3(gp)              # ExecMode=Direct
        j       MainLoop

#-------------------------------------------------------------------------
# シグナルハンドラ
#-------------------------------------------------------------------------
SigIntHandler:
        addi    sp, sp, -16
        sd      a0, (sp)
        li      a0, 1                   # SIGINT シグナル受信
        sb      a0, -5(gp)              # gpは常に同じ値
        ld      a0, (sp)
        addi    sp, sp, 16
        ret

SigReturn:
        li      a7, sys_rt_sigreturn
        ecall                           # 戻らない？

#-------------------------------------------------------------------------
# コマンドラインで指定されたVTLコードファイルをロード
# a0 が負ならエラー
# a1-a4 破壊
#-------------------------------------------------------------------------
LoadCode:
        addi    sp, sp, -16
        sd      ra, (sp)
        la      a3, current_arg         # 処理済みの引数
        ld      a2, (a3)
        addi    a2, a2, 1               # カウントアップ
        ld      a4, 8(a3)               # argc 引数の個数
        beq     a2, a4, 3f              # すべて処理済み
        sd      a2, (a3)                # 処理済みの引数更新
        ld      a4, 16(a3)              # argvp 引数配列先頭
        slli    s0, a2, 3
        add     s0, a4, s0
        ld      a4, (s0)                # 引数取得
        la      a1, FileName
        li      a2, FNAMEMAX
    1:  lbu     a0, (a4)
        sb      a0, (a1)
        beqz    a0, 2f                  # a0=0 then file open
        addi    a4, a4, 1
        addi    a1, a1, 1
        addi    a2, a2, -1
        bnez    a2, 1b

    2:  la      a0, FileName            # ファイルオープン
        jal     fropen                  # open
        jal     CheckError
        bltz    a0, 3f
        sd      a0, -16(gp)             # FileDesc
        li      a0, 1
        sb      a0, -4(gp)              # Read from file(1)
        li      s1, 1                   # EOL=yes
    3:
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 文字列取得 " または EOL まで
#-------------------------------------------------------------------------
GetString:
        addi    sp, sp, -32
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      ra,  0(sp)
        li      a2, 0
        la      a3, FileName
        li      a1, FNAMEMAX
    1: # next:
        jal     GetChar
        li      s0 , '"'
        beq     tp, s0, 2f
        beq     tp, zero, 2f
        add     s0, a3, a2
        sb      tp, (s0)
        addi    a2, a2, 1
        bltu    a2, a1, 1b
    2: # exit:
        li      tp, 0
        add     s0, a3, a2
        sb      tp, (s0)
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# a0 のアドレスからFileNameにコピー
#-------------------------------------------------------------------------
GetString2:
        addi    sp, sp, -32
        sd      a4, 24(sp)
        sd      a3, 16(sp)
        sd      a2,  8(sp)
        sd      a0, (sp)
        li      a2, 0
        la      a3, FileName
        li      a4, FNAMEMAX
    1:
        lbu     s0, (a0)
        sb      s0, (a3)
        beq     s0, zero, 2f
        addi    a0, a0, 1
        addi    a3, a3, 1
        addi    a2, a2, 1
        bltu    a2, a4, 1b
    2:
        ld      a4, 24(sp)
        ld      a3, 16(sp)
        ld      a2,  8(sp)
        ld      a0, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# ファイル名をバッファに取得
# バッファ先頭アドレスを a0 に返す
#-------------------------------------------------------------------------
GetFileName:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar                 # skip =
        li      s0, '='
        bne     tp, s0, 2f              # エラー
        jal     GetChar                 # skip double quote
        li      s0, '"'                 # "
        beq     tp, s0, 1f
        j       2f                      # エラー
    1: # file
        jal     GetString
        la      a0, FileName            # ファイル名表示
        ld      ra, (sp)
        addi    sp, sp, 16
        ret
    2: # error
        addi    sp, sp, 16              # スタック修正
        j       pop_and_Error

#-------------------------------------------------------------------------
# 文の実行
#   文を実行するサブルーチンをコール
#-------------------------------------------------------------------------
Command:
        # tpレジスタの値によって各処理ルーチンを呼び出す
        li      s0, '!'
        blt     tp, s0, 1f
        li      s0, '/'
        bgt     tp, s0, 1f
        addi    a1, tp, -'!'
        la      a2, TblComm1            # ジャンプテーブル1 !-/
        j       jumpToCommand
    1:
        li      s0, ':'
        blt     tp, s0, 2f
        li      s0, '@'
        bgt     tp, s0, 2f
        addi    a1, tp, -':'
        la      a2, TblComm2            # ジャンプテーブル2 :-@
        j       jumpToCommand
    2:
        li      s0, '['
        blt     tp, s0, 3f
        li      s0, '`'
        bgt     tp, s0, 3f
        addi    a1, tp, -'['
        la      a2, TblComm3            # ジャンプテーブル3 [-`
        j       jumpToCommand

    3:
        li      s0, '{'
        blt     tp, s0, 4f
        li      s0, '~'
        bgt     tp, s0, 4f
        addi    a1, tp, -'{'
        la      a2, TblComm4            # ジャンプテーブル4 {-~

jumpToCommand:
        slli    s0, a1, 3
        add     s0, a2, s0
        ld      s0, (s0)                # ジャンプ先アドレス設定
        jalr    ra, s0, 0               # 対応ルーチンをコール
        j       MainLoop

    4:  li      s0, ' '
        beq     tp, s0, MainLoop
        beq     tp, zero, MainLoop
        li      s0, 8
        beq     tp, s0, MainLoop
        j       SyntaxError

#-------------------------------------------------------------------------
# ソースコードを1文字読み込む
# t2 の示す文字を tp に読み込み, t2 を次の位置に更新
# レジスタ保存
#-------------------------------------------------------------------------
GetChar:
        li      s0, 1                   # EOL=yes
        beq     s1, s0, 2f
        lbu     tp, (t2)
        bne     tp, zero, 1f
        li      s1, 1                   # EOL=yes
    1:  addi    t2, t2, 1
    2:  ret

#-------------------------------------------------------------------------
# 行番号をシステム変数 # に設定
#-------------------------------------------------------------------------
SetLineNo:
        lwu     a0, 4(t1)               # 実行中行番号
        addi    s0, gp, '#' * 8
        sd      a0, (s0)                # 行番号を # に設定
        ret

SetLineNo2:
        addi    a3, gp, '#' * 8
        lwu     a0, 4(a3)               # 行番号を取得
        addi    s0, gp, '!' * 8
        sd      a0, (s0)                # 行番号を ! に設定
        lwu     a0, 4(t1)               # Line No.
        sd      a0, (a3)                # 行番号を # に設定
        ret

#-------------------------------------------------------------------------
# CGI モードなら rvtl 終了
#-------------------------------------------------------------------------
CheckCGI:
        la      a3, cgiflag
        ld      a3, (a3)
        li      s0, 1
        beq     a3, s0, Com_Exit        # CGI mode ?
        ret

#-------------------------------------------------------------------------
# 文法エラー
#-------------------------------------------------------------------------
SyntaxError:
        la      a0, syntaxerr
Error:  jal     OutAsciiZ
        lbu     a0, -3(gp)
        beq     a0, zero, 3f            # ExecMode=Direct ?
        lw      a0, 4(t1)               # エラー行行番号
        jal     PrintLeft
        jal     NewLine
        addi    a0, t1, 8               # 行先頭アドレス
    5:  jal     OutAsciiZ               # エラー行表示
        jal     NewLine
        sub     a3, t2, t1
        addi    a3, a3, -9
        beqz    a3, 2f
        li      s0, MAXLINE
        bgeu    a3, s0, 3f
        li      a0, ' '                 # エラー位置設定
    1:  jal     OutChar
        addi    a3, a3, -1
        bnez    a3, 1b
    2:  la      a0, err_str
        jal     OutAsciiZ
        mv      a0, tp
        jal     PrintHex2               # エラー文字コード表示
        li      a0, ']'
        jal     OutChar
        jal     NewLine

    3:  jal     WarmInit                # システムを初期状態に
        j       MainLoop

#-------------------------------------------------------------------------
# 変数スタック範囲エラー
#-------------------------------------------------------------------------
VarStackError_over:
        la      a0, vstkover
        j       1f
VarStackError_under:
        la      a0, vstkunder
    1:  jal     OutAsciiZ
        jal     WarmInit
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# スタックへアドレスをプッシュ (行と文末位置を退避)
#-------------------------------------------------------------------------
PushLine:
        addi    sp, sp, -16
        sd      a2,  8(sp)
        sd      a1, (sp)
        lbu     a1, -1(gp)              # LSTACK
        li      s0, LSTACKMAX
        bge     a1, s0, StackError_over # overflow
        addi    a2, gp, 1024            # (gp + 1024) + LSTACK*8
        slli    s0, a1, 3
        add     s0, a2, s0
        sd      t1, (s0)                # push line top address

        addi    a1, a1, 1               # LSTACK--
        lbu     s0, -1(t2)
        beqz    s0, 1f                  # 行末処理
        slli    s0, a1, 3
        add     s0, a2, s0
        sd      t2, (s0)                # push t2,(gp+1024)+LSTACK*8
        j       2f
    1:
        addi    t2, t2, -1              # 1文字戻す
        slli    s0, a1, 3
        add     s0, a2, s0
        sd      t2, (s0)                # push t2,(gp+1024)+LSTACK*8
        addi    t2, t2, 1               # 1文字進める
    2:
        addi    a1, a1, 1               # LSTACK--
        sb      a1, -1(gp)              # LSTACK
        ld      a2,  8(sp)
        ld      a1, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# スタックからアドレスをポップ (行と文末位置を復帰)
# t1, t2 更新
#-------------------------------------------------------------------------
PopLine:
        addi    sp, sp, -16
        sd      a2,  8(sp)
        sd      a1, (sp)
        lbu     a1, -1(gp)              # LSTACK
        li      s0, 2
        bltu    a1, s0, StackError_under   # underflow
        addi    a1, a1, -1              # LSTACK--
        addi    a2, gp, 1024            # (gp + 1024) + LSTACK*8
        slli    s0, a1, 3
        add     a2, a2, s0
        ld      t2, (a2)                # pop t2
        ld      t1, -8(a2)              # pop t1
        addi    a1, a1, -1
        sb      a1, -1(gp)              # LSTACK
        ld      a2,  8(sp)
        ld      a1, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# スタックエラー
# r0 変更
#-------------------------------------------------------------------------
StackError_over:
        la      a0, stkover
        j       1f
StackError_under:
        la      a0, stkunder
    1:  addi    sp, sp, -16
        sd      ra, (sp)
        jal     OutAsciiZ
        jal     WarmInit
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# スタックへ終了条件(a0)をプッシュ
#-------------------------------------------------------------------------
PushValue:
        addi    sp, sp, -16
        sd      a2,  8(sp)
        sd      a1, (sp)
        lbu     a1, -1(gp)              # LSTACK
        li      s0, LSTACKMAX
        bge     a1, s0, StackError_over
        slli    s0, a1, 3               # s0 = a1 * 8
        addi    a2, gp, 1024            # (gp + 1024) + LSTACK*8
        add     s0, a2, s0              # s0 = a2 + a1 * 8
        sd      a0, (s0)                # a2 + a1 * 8 <-- a0
        addi    a1, a1, 1               # LSTACK++
        sb      a1, -1(gp)              # LSTACK
        ld      a2,  8(sp)
        ld      a1, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# スタック上の終了条件を a0 に設定
#-------------------------------------------------------------------------
PeekValue:
        addi    sp, sp, -16
        sd      a1, (sp)
        lbu     a0, -1(gp)              # LSTACK
        addi    a0, a0, -3              # 行,文末位置の前
        addi    a1, gp, 1024            # (gp + 1024) + LSTACK*8
        slli    s0, a0, 3               # s0 = a0 * 8
        add     s0, a1, s0              # s0 = a2 + a0 * 8
        ld      a0, (s0)                # a2 + a0 * 8 --> a0
        ld      a1, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# スタックから終了条件(a0)をポップ
#-------------------------------------------------------------------------
PopValue:
        addi    sp, sp, -16
        sd      a2,  8(sp)
        sd      a1, (sp)
        lbu     a1, -1(gp)              # LSTACK
        li      s0, 1
        bltu    a1, s0, StackError_under
        addi    a1, a1, -1              # LSTACK--
        addi    a2, gp, 1024            # (gp + 1024) + LSTACK*8
        slli    s0, a1, 3               # s0 = a1 * 8
        add     s0, a2, s0              # s0 = a2 + a1 * 8
        ld      a0, (s0)                # a2 + a1 * 8 --> a0
        sb      a1, -1(gp)              # LSTACK
        ld      a2,  8(sp)
        ld      a1, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# プロンプト表示
#-------------------------------------------------------------------------
DispPrompt:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra, (sp)
        jal     WinSize
        srli    a0, a0, 16              # 桁数
        li      s0, 48
        bltu    a0, s0, 1f
        li      a0, 7                   # long prompt
        jal     set_linetop             # 行頭マージン設定
        la      a0, prompt1             # プロンプト表示
        jal     OutAsciiZ
        ld      a0, -40(gp)             # pid の取得
.ifdef DEBUG
        mv      a0, sp                  # sp の下位4桁
.endif
        jal     PrintHex4
        la      a0, prompt2             # プロンプト表示
        jal     OutAsciiZ
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

    1:  li      a0, 4                   # short prompt
        jal     set_linetop             # 行頭マージン設定
        jal     NewLine
        ld      a0, -40(gp)             # pid の取得
        jal     PrintHex2               # pidの下1桁表示
        la      a0, prompt2             # プロンプト表示
        jal     OutAsciiZ
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# アクセス範囲エラー
#-------------------------------------------------------------------------
RangeError:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra, (sp)
        la      a0, Range_msg           # 範囲エラーメッセージ
        jal     OutAsciiZ
        addi    s0, gp, '#' * 8         # 行番号
        ld      a0, (s0)
        jal     PrintLeft
        li      a0, ','
        jal     OutChar
        addi    s0, gp, '!' * 8         # 呼び出し元の行番号
        ld      a0, (s0)
        jal     PrintLeft
        jal     NewLine
        jal     WarmInit
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# システム初期化２
#-------------------------------------------------------------------------
WarmInit:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     CheckCGI
        ld      ra, (sp)
        addi    sp, sp, 16
WarmInit2:
        # コマンド入力元をコンソールに設定
        sb      zero, -4(gp)            # Read from console
WarmInit1:
        #システム変数及び作業用フラグの初期化
        li      a0, 1                   # 1
        addi    s0, gp, '[' * 8         # 範囲チェックON
        sd      a0, (s0)
        li      s1, 1                   # EOL=yes
        la      a1, exarg               # execve 引数配列初期化
        sd      zero, (a1)
        sb      zero, -7(gp)            # 式のエラー無し
        sb      zero, -6(gp)            # ０除算無し
        sb      zero, -5(gp)            # SIGINTシグナル無し
        sb      zero, -3(gp)            # ExecMode=Direct
        sb      zero, -1(gp)            # LSTACK
        sd      zero, -32(gp)           # VSTACK
        ret

#-------------------------------------------------------------------------
# GOSUB !
#-------------------------------------------------------------------------
Com_GOSUB:
        addi    sp, sp, -16
        sd      ra, (sp)
        lbu     a0, -3(gp)
        bnez    a0, 1f                  # ExecMode=Direct ?
        la      a0, no_direct_mode      # エラー表示
        jal     OutAsciiZ
        addi    sp, sp, 16              # スタック復帰
        jal     WarmInit
        j       MainLoop

    1:
.ifdef VTL_LABEL
        jal     ClearLabel
.endif
        jal     SkipEqualExp            # = を読み飛ばした後 式の評価
        jal     PushLine
        jal     Com_GO_go
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# Return )
#-------------------------------------------------------------------------
Com_Return:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     PopLine                 # 現在行の後ろは無視
        li      s1, 0                   # not EOL
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# IF ; コメント :
#-------------------------------------------------------------------------
Com_IF:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipEqualExp            # = を読み飛ばした後 式の評価
        ld      ra, (sp)
        addi    sp, sp, 16
        beqz    a0, Com_Comment
        ret                             # 真なら戻る、偽なら次行
Com_Comment:
        li      s1, 1                   # EOL=yes 次の行へ
        ret

#-------------------------------------------------------------------------
# 未定義コマンド処理(エラーストップ)
#-------------------------------------------------------------------------
pop2_and_Error:
        addi     sp, sp, 16
pop_and_Error:
        addi     sp, sp, 16
Com_Error:
        j        SyntaxError

#-------------------------------------------------------------------------
# DO UNTIL NEXT #
#-------------------------------------------------------------------------
Com_DO:
        addi    sp, sp, -16
        sd      ra, (sp)
        ld      a0, -3(gp)
        bne     a0, zero, 1f            # ExecMode=Direct ?
        la      a0, no_direct_mode      # エラー表示
        jal     OutAsciiZ
        addi    sp, sp, 16              # スタック修正
        jal     WarmInit
        j       MainLoop
    1:
        jal     GetChar
        li      s0, '='
        bne     tp, s0, 7f              # DO コマンド
        lbu     tp, (t2)                # PeekChar
        li      s0, '('                 # UNTIL?
        bne     tp, s0, 2f              # ( でなければ NEXT
        jal     SkipCharExp             # (を読み飛ばして式の評価
        mv      a2, a0                  # 式の値
        jal     GetChar                 # ) を読む(使わない)
        jal     PeekValue               # 終了条件
        bne     a2, a0, 6f              #  a0:終了条件
        j       5f                      # ループ終了

    2: # next (FOR)
        jal     IsAlpha                 # al=(A-Za-z) ?
        bltz    a0, pop_and_Error       # スタック補正後 SyntaxError
        slli    s0, tp, 3
        add     a2, gp, s0              # 制御変数のアドレス
        jal     Exp                     # 任意の式
        ld      a3, (a2)                # 更新前の値を a3 に
        sd      a0, (a2)                # 制御変数の更新
        mv      a2, a0                  # 更新後の式の値をa2
        jal     PeekValue               # 終了条件を a0 に
        lbu     a1, -8(gp)
        li      s0, 1                   # 降順 (開始値 > 終了値)
        bne     a1, s0, 4f              # 昇順

    3: # 降順
        ble     a3, a2, pop_and_Error   # 更新前が小さければエラー
        bgt     a3, a0, 6f              # continue
        j       5f                      # 終了

    4: # 昇順
        bge     a3, a2, pop_and_Error   # 更新前が大きければエラー
        blt     a3, a0, 6f              # continue

    5: # exit ループ終了
        lbu     a1, -1(gp)              # LSTACK=LSTACK-3
        addi    a1, a1, -3
        sb      a1, -1(gp)              # LSTACK
        j       8f                      # return

    6: # continue UNTIL
        lbu     a1, -1(gp)              # LSTACK 戻りアドレス
        addi    a3, a1, -1

        slli    s0, a3, 3
        add     a2, gp, s0
        addi    a2, a2, 1024
        ld      t2, (a2)                # gp+(a1-1)*8+1024
        addi    a3, a3, -1
        slli    s0, a3, 3
        add     a2, gp, s0
        addi    a2, a2, 1024
        ld      t1, (a2)                # gp+(a1-2)*8+1024
        li      s1, 0                   # not EOL
        j       8f                      # return

    7:  li      a0, 1                   # DO
        jal     PushValue
        jal     PushLine

    8:  ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 変数への代入, FOR文処理
# tp に変数名を設定して呼び出される
#-------------------------------------------------------------------------
SetVar:         # 変数代入
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipAlpha               # 変数の冗長部分の読み飛ばし
        slli    s0, a1, 3
        add     t0, gp, s0              # 変数のアドレス
        li      s0, '('
        beq     tp, s0, s_array1        # 1バイト配列
        li      s0, '{'
        beq     tp, s0, s_array2        # 2バイト配列
        li      s0, '['
        beq     tp, s0, s_array4        # 4バイト配列
        li      s0, ';'
        beq     tp, s0, s_array8        # 8バイト配列
        li      s0, '*'
        beq     tp, s0, s_strptr        # ポインタ指定
        li      s0, '='
        bne     tp, s0, pop_and_Error

        # 単純変数
    0:  jal     Exp                     # 式の処理(先読み無しで呼ぶ)
        sd      a0, (t0)                # 代入
        mv      a1, a0
        li      s0, ','                 # FOR文か?
        bne     tp, s0, 3f              # 終了

        lbu     s0, -3(gp)              # ExecMode=Direct ?
        bnez    s0, 1f                  # 実行時ならOKなのでFOR処理
        la      a0, no_direct_mode      # エラー表示
        jal     OutAsciiZ
        addi    sp, sp, 16              # スタック修正(pop)
        jal     WarmInit
        j       MainLoop                # 戻る

    1:  # for
        li      s0, 0
        sb      s0, -8(gp)              # 昇順(0)
        jal     Exp                     # 終了値をa0に設定
        bge     a0, a1, 2f              # 開始値(a1)と終了値(a0)を比較
        li      s0, 1
        sb      s0, -8(gp)              # 降順 (開始値 >= 終了値)

    2:  jal     PushValue               # 終了値を退避(NEXT部で判定)
        jal     PushLine                # For文の直後を退避

    3:  j       s_var_exit

    s_array1:
        jal     s_array
        bnez    a2, s_range_err         # 範囲外をアクセス
        add     s0, t0, a1
        sb      a0, (s0)                # 代入
        j       s_var_exit

    s_array2:
        jal     s_array
        bnez    a2, s_range_err         # 範囲外をアクセス
        slli    a1, a1, 1
        add     s0, t0, a1
        sh      a0, (s0)                # 代入
        j       s_var_exit

    s_array4:
        jal     s_array
        bnez    a2, s_range_err         # 範囲外をアクセス
        slli    a1, a1, 2
        add     s0, t0, a1
        sw      a0, (s0)                # 代入
        j       s_var_exit

    s_array8:
        jal     s_array
        bnez    a2, s_range_err         # 範囲外をアクセス
        slli    a1, a1, 3
        add     s0, t0, a1
        sd      a0, (s0)                # 代入
        j       s_var_exit

    s_strptr:                           # 文字列をコピー
        jal     GetChar                 # skip =
        ld      t0, (t0)                # 変数にはコピー先
        jal     RangeCheck              # コピー先を範囲チェック
        bnez    a2, s_range_err         # 範囲外をアクセス
        lbu     tp, (t2)                # PeekChar
        li      s0, '"                  # "
        bne     tp, s0, s_sp0

        li      a2, 0                   # 文字列定数を配列にコピー
        jal     GetChar                 # skip double quote
    1:                                  # next char
        jal     GetChar
        li      s0, '"                  # "
        beq     tp, s0, 2f
        beqz    tp, 2f
        add     s0, t0, a2
        sb      tp, (s0)
        addi    a2, a2, 1
        li      s0, FNAMEMAX
        bltu    a2, s0, 1b
    2:                                  # done
        li      tp, 0
        add     s0, t0, a2
        sb      tp, (s0)
        addi    s0, gp, '%' * 8
        sd      a2, (s0)                # コピーされた文字数
        j       s_var_exit

    s_sp0:
        jal     Exp                     # コピー元のアドレス
        beq     t0, a0, 3f
        mv      a1, t0                  # t0退避
        mv      t0, a0                  # RangeCheckはt0を見る
        jal     RangeCheck              # コピー先を範囲チェック
        mv      t0, a1                  # コピー先復帰
        bnez    a2, s_range_err         # 範囲外をアクセス
        li      a2, 0
    1:  lbu     a1, (a0)
        sb      a1, (t0)
        addi    a0, a0, 1
        addi    t0, t0, 1
        addi    a2, a2, 1
        li      s0, 0x40000             # 262144文字まで
        beq     a2, s0, 2f
        bnez    a1, 1b
    2:  addi    a2, a2, -1              # 文字数から行末を除く
        addi    s0, gp, '%' * 8
        sd      a2, (s0)                # コピーされた文字数
        j       s_var_exit

    3:  jal     StrLen
        addi    s0, gp, '%' * 8
        sd      a1, (s0)                # 文字数
        j       s_var_exit

    # a1 にインデックスの値、a0 に右辺値を格納、a2は範囲チェック
    s_array:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     Exp                     # 配列インデックス
        mv      a1, a0
        ld      t0, (t0)
        jal     RangeCheck              # 範囲チェック
        bltz    a2, s_range_err
        jal     SkipCharExp             # 式の処理(先読み無しで呼ぶ)
        j       s_var_exit

    s_range_err:
        jal     RangeError              # アクセス可能範囲を超えた
    s_var_exit:
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 配列のアクセス可能範囲をチェック
# , < t0 < * 範囲外は a2=-1, 範囲内はa2=0
# leaf
#-------------------------------------------------------------------------
RangeCheck:
        addi    sp, sp, -16
        sd      a1,  8(sp)
        sd      a0, (sp)
        addi    s0, gp, '[' * 8         # 範囲チェックフラグ
        ld      a0, (s0)
        beqz    a0, 2f                  # 0 ならチェックしない
        la      a0, input2              # インプットバッファはOK
        beq     t0, a0, 2f
        addi    s0, gp, ',' * 8         # プログラム先頭
        ld      a0, (s0)                # ,
        bltu    t0, a0, 1f              # if t0 < , a0 = -1
        addi    s0, gp, '*' * 8         # RAM末
        ld      a1, (s0)                # *
        bleu    t0, a1, 2f              # if t0 <= * a1 = 0
    1:  li      a2, -1
        j       3f

    2:  li      a2, 0                   # a0 = 0
    3:  ld      a1,  8(sp)
        ld      a0, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 変数の冗長部分の読み飛ばし
#   変数名を a1 に退避, 次の文字を tp に返す
#   SetVar, Variable で使用
#-------------------------------------------------------------------------
SkipAlpha:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra, (sp)
        mv      a1, tp                  # 変数名を a1 に退避
    1:  jal     GetChar
        jal     IsAlpha
        beqz    a0, 1b
    2:  ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# SkipEqualExp  = に続く式の評価
# SkipCharExp   1文字を読み飛ばした後 式の評価
# Exp           式の評価
# a0 に値を返す (先読み無しで呼び出し, 1文字先読みで返る)
#-------------------------------------------------------------------------
SkipEqualExp:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra, (sp)
        jal     GetChar                 # check =
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
SkipEqualExp2:
        li      s0, '='                 # 先読みの時
        beq     tp, s0, Exp             # = を確認
        la      a0, equal_err           #
        jal     OutAsciiZ
        j       pop_and_Error           # 文法エラー

SkipCharExp:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra, (sp)
        jal     GetChar                 # skip a character
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
Exp:
        addi    sp, sp, -16
        sd      a1,  8(sp)
        sd      ra, (sp)
        lbu     tp, (t2)                # PeekChar
        li      s0, ' '
        bne     tp, s0, e_ok
        li      a1, 1
        sb      a1, -7(gp)              # 式中の空白はエラー
        j       LongJump                # エラー

    e_ok:
        addi    sp, sp, -32
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a1,  8(sp)
        sd      a4, (sp)
        jal     Factor                  # a1 に項の値
        mv      a0, a1                  # 式が項のみの場合に備える
    e_next:
        mv      a1, a0                  # これまでの結果をa1に格納
        li      s0, '+'                 # ADD
        bne     tp, s0, e_sub
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        add     a0, a3, a1              # 2項を加算
        j       e_next
    e_sub:
        li      s0, '-'                 # SUB
        bne     tp, s0, e_mul
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        sub     a0, a3, a1              # 左項から右項を減算
        j       e_next
    e_mul:
        li      s0, '*'                 # MUL
        bne     tp, s0, e_div
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        mul     a0, a3, a1              # 左項から右項を減算
        j       e_next
    e_div:
        li      s0, '/'                 # DIV
        bne     tp, s0, e_udiv
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        bnez    a1, e_div1
        li      a2, 1
        sb      a2, -6(gp)              # 0除算エラー
        j       e_exit
    e_div1:
        div     a0, a3, a1              # a0/a1 = s0...a1
        rem     a4, a3, a1
        addi    s0, gp, '%' * 8         # 剰余の保存
        sd      a4, (s0)
        mv      a1, a0                  # 商を a1 に
        j       e_next
    e_udiv:
        li      s0,  '\\'               # UDIV
        bne     tp, s0, e_and
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        bnez    a1, e_udiv1
        li      a2, 1
        sb      a2, -6(gp)              # 0除算エラー
        j       e_exit
    e_udiv1:
        divu    a0, a3, a1              # a0/a1 = a0...a1
        remu    a4, a3, a1
        addi    s0, gp, '%' * 8         # 剰余の保存
        sd      a4, (s0)
        mv      a1, a0                  # 商を a1 に
        j       e_next
    e_and:
        li      s0, '&'                 # AND
        bne     tp, s0, e_or
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        and     a0, a3, a1
        j       e_next
    e_or:
        li      s0,  '|'                # OR
        bne     tp, s0, e_xor
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        or      a0, a3, a1              # 左項と右項を OR
        j       e_next
    e_xor:
        li      s0, '^'                 # XOR
        bne     tp, s0, e_equal
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        xor     a0, a3, a1              # 左項と右項を XOR
        j       e_next
    e_equal:
        li      s0, '='                 # =
        bne     tp, s0, e_exp7
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        bne     a1, a3, e_false         # 左項と右項を比較
    e_true:
        li      a0, 1
        j       e_next
    e_false:
        li      a0, 0                   # 0:偽
        j       e_next
    e_exp7:
        li      s0, '<'                 # <
        bne     tp, s0, e_exp8
        lbu     tp, (t2)                # PeekChar
        li      s0, '='                 # <=
        beq     tp, s0, e_exp71
        li      s0, '>'                 # <>
        beq     tp, s0, e_exp72
        li      s0, '<'                 # <<
        beq     tp, s0, e_shl
                                        # <
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        bge     a3, a1, e_false         # 左項と右項を比較
        j       e_true
    e_exp71:
        jal     GetChar                 # <=
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        bgt     a3, a1, e_false         # 左項と右項を比較
        j       e_true
    e_exp72:
        jal     GetChar                 # <>
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        beq     a3, a1, e_false         # 左項と右項を比較
        j       e_true
    e_shl:
        jal     GetChar                 # <<
        li      s0, '<'                 #
        bne     tp, s0, e_exp9
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        sll     a0, a3, a1              # 左項を右項で SHL (*2)
        j       e_next
    e_exp8:
        li      s0, '>'                 # >
        bne     tp, s0, e_exp9
        lbu     tp, (t2)                # PeekChar
        li      s0, '='                 # >=
        beq     tp, s0, e_exp81
        li      s0,  '>'                # >>
        beq     tp, s0, e_shr
                                        # >
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        ble     a3, a1, e_false         # 左項と右項を比較
        j       e_true
    e_exp81:
        jal     GetChar                 # >=
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        blt     a3, a1, e_false         # 左項と右項を比較
        j       e_true
    e_shr:
        jal     GetChar                 # >>
        mv      a3, a1                  # 項の値を退避
        jal     Factor                  # 右項を取得
        srl     a0, a3, a1              # 左項を右項で SHR (/2)
        j       e_next
    e_exp9:
    e_exit:
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a1,  8(sp)
        ld      a4, (sp)
        addi    sp, sp, 32
        ld      a1,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# UNIX時間をマイクロ秒単位で返す
#-------------------------------------------------------------------------
GetTime:
        addi    sp, sp, -32
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a0,  8(sp)
        sd      ra, (sp)
        la      a3, TV
        mv      a0, a3
        addi    a1, a3, 16              # TZ
        li      a7, sys_gettimeofday
        ecall
        ld      a1, (a3)                # sec
        ld      a0, 8(a3)               # usec
        addi    s0, gp, '%' * 8         # 剰余に usec を保存
        sd      a0, (s0)
        jal     GetChar
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# マイクロ秒単位のスリープ _=n
#-------------------------------------------------------------------------
Com_USleep:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipEqualExp            # = を読み飛ばした後 式の評価
        la      a4, TV                  # 第5引数
        li      a2, 1000                # a2 = 1000
        mul     a3, a2, a2              # a3 = 1000000
        divu    a1, a0, a3              # a1 = int(a0 / 1000000)
        mul     a2, a1, a3              # a2 = a1 * 1000000
        sub     a0, a0, a2              # a0 = a0 - (a1 * 1000000)
        sd      a1, (a4)                # sec
        mul     a0, a0, a2              # usec --> nsec
        sd      a0, 8(a4)               # nsec
        li      a0, 0
        li      a1, 0
        li      a2, 0
        li      a3, 0
        li      a5, 0                   # 第6引数 NULL
        li      a7, sys_pselect6
        ecall
        jal     CheckError
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 配列と変数の参照, a1 に値が返る
# 変数参照にt0を使用(保存)
# a0 は上位のFactorで保存
#-------------------------------------------------------------------------
Variable:
        addi    sp, sp, -16
        sd      t0,  8(sp)
        sd      ra, (sp)
        jal     SkipAlpha               # 変数名は a1
        slli    s0, a1, 3
        add     t0, gp, s0              # 変数のアドレス
        li      s0, '('
        beq     tp, s0, v_array1        # 1バイト配列
        li      s0, '{'
        beq     tp, s0, v_array2        # 2バイト配列
        li      s0, '['
        beq     tp, s0, v_array4        # 4バイト配列
        li      s0, ';'
        beq     tp, s0, v_array8        # 8バイト配列
        ld      a1, (t0)                # 単純変数
        ld      t0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

    v_array1:
        jal     Exp                     # 1バイト配列
        ld      t0, (t0)
        jal     RangeCheck              # 範囲チェック
        bnez    a2, v_range_err         # 範囲外をアクセス
        add     s0, t0, a0
        lbu     a1, (s0)
        j       v_skip_char

    v_array2:
        jal     Exp                     # 2バイト配列
        ld      t0, (t0)
        jal     RangeCheck              # 範囲チェック
        bnez    a2, v_range_err         # 範囲外をアクセス
        slli    s0, a0, 1
        add     s0, t0, s0
        lhu     a1, (s0)
        j       v_skip_char

    v_array4:
        jal     Exp                     # 4バイト配列
        ld      t0, (t0)
        jal     RangeCheck              # 範囲チェック
        bnez    a2, v_range_err         # 範囲外をアクセス
        slli    s0, a0, 2
        add     s0, t0, s0
        lwu     a1, (s0)
        j       v_skip_char

    v_array8:
        jal     Exp                     # 4バイト配列
        ld      t0, (t0)
        jal     RangeCheck              # 範囲チェック
        bnez    a2, v_range_err         # 範囲外をアクセス
        slli    s0, a0, 3
        add     s0, t0, s0
        ld      a1, (s0)
    v_skip_char:
        jal     GetChar                 # skip )
        j       v_return

    v_range_err:
        jal     RangeError
    v_return:
        ld      t0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 変数値
# a1 に値を返す (先読み無しで呼び出し, 1文字先読みで返る)
#-------------------------------------------------------------------------
Factor:
        addi    sp, sp, -32
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a0,  8(sp)
        sd      ra, (sp)
        jal     GetChar
        jal     IsNum
        bltz    a0, f_bracket
        jal     Decimal                 # 正の10進整数
        mv      a1, a0
        j       f_exit

    f_bracket:
        li      s0, '('
        bne     tp, s0, f_yen
        jal     Exp                     # カッコ処理
        mv      a1, a0                  # 項の値は a1
        jal     GetChar                 # skip )
        j       f_exit

    f_yen:
        li      s0, '\\'                # '\'
        bne     tp, s0, f_rand
        lbu     tp, (t2)                # PeekChar
        li      s0, '\\'                # '\\'
        beq     tp, s0, f_env

        jal     Exp                     # 引数番号を示す式
        ld      a2, argc_vtl            # vtl用の引数の個数
        blt     a0, a2, 2f              # 引数番号 < 引数の数
        ld      a2, argvp               # argvp
        ld      a1, (a2)                # argvp(0)
    1:  lbu     a2, (a1)                # 0を探す
        addi    a1, a1, 1
        bnez    a2, 1b                  # a2!=0 then goto 1b
        addi    a1, a1, -1              # argv(0)のEOLに設定
        j       3f
    2:  la      a2, argp_vtl            # found
        ld      a2, (a2)
        slli    s0, a0, 3
        add     s0, a2, s0
        ld      a1, (s0)                # 引数文字列先頭アドレス
    3:  j       f_exit

    f_env:
        jal     GetChar                 # skip '\'
        jal     Exp
        ld      a2, envp
        li      a1, 0
    4:
        slli    s0, a1, 3
        add     s0, a2, s0
        ld      s4, (s0)                # envp(0)
        beq     s4, zero, 5f            # s4==0 then 5f
        addi    a1, a1, 1
        j       4b
    5:
        bge     a0, a1, 6f              # 引数番号が過大
        slli    s0, a0, 3
        add     s0, a2, s0
        ld      a1, (s0)                # 引数文字列先頭アドレス
        j       f_exit
    6:  slli    s0, a1, 3
        add     a1, a2, s0              # 0へのポインタ(空文字列)
        j       f_exit

    f_rand:
        li      s0, '`'
        bne     tp, s0, f_hex
        jal     genrand                 # 乱数の読み出し
        mv      a1, a0
        jal     GetChar
        j       f_exit

    f_hex:
        li      s0, '$'
        bne     tp, s0, f_time
        jal     Hex                     # 16進数または1文字入力
        j       f_exit

    f_time:
        li      s0, '_'
        bne     tp, s0, f_num
        jal     GetTime                 # 時間を返す
        j       f_exit

    f_num:
        li      s0, '?'
        bne     tp, s0, f_char
        jal     NumInput                # 数値入力
        j       f_exit

    f_char:
        li      s0, 0x27
        bne     tp, s0, f_singnex
        jal     CharConst               # 文字定数
        j       f_exit

    f_singnex:
        li      s0, '<'
        bne     tp, s0, f_neg
        jal     Factor
        li      s0, 0xffffffff
        and     a1, a1, s0              # ゼロ拡張
        j       f_exit

    f_neg:
        li      s0, '-'
        bne     tp, s0, f_abs
        jal     Factor                  # 負符号
        neg     a1, a1
        j       f_exit

    f_abs:
        li      s0, '+'
        bne     tp, s0, f_realkey
        jal     Factor                  # 変数，配列の絶対値
        bgez    a1, 1f
        sub     a1, zero, a1            # a1 < 0 then a1=-a1
    1:  j       f_exit

    f_realkey:
        li      s0, '@'
        bne     tp, s0, f_winsize
        jal     RealKey                 # リアルタイムキー入力
        mv      a1, a0
        jal     GetChar
        j       f_exit

    f_winsize:
        li      s0, '.'
        bne     tp, s0, f_pop
        jal     WinSize                 # ウィンドウサイズ取得
        mv      a1, a0
        jal     GetChar
        j       f_exit

    f_pop:
        li      s0, ';'
        bne     tp, s0, f_label
        ld      a2, -32(gp)             # VSTACK
        addi    a2, a2, -1
        bgeu    a2, zero, 2f            # unsigned higher or same
        li      a2, 2
        sb      a2, -7(gp)              # 変数スタックエラー
        j       1f
    2:  slli    s0, a2, 3
        add     a0, gp, s0
        li      s0, 2048
        add     a0, a0, s0              # gp+a2*8+2048
        ld      a1, (a0)                # 変数スタックから復帰
        sd      a2, -32(gp)             # スタックポインタ更新
    1:  jal     GetChar
        j       f_exit

    f_label:
        li      s0, '^'
        bne     tp, s0, f_dq
.ifdef VTL_LABEL
        jal     LabelSearch             # ラベルのアドレスを取得
        beqz    a0, 2f                  # a0 が0ならa1にラベルアドレス
.endif
        li      a2, 3
        sb      a2, -7(gp)              # ラベルエラー ExpError
    2:  j       f_exit

    f_dq:
        li      s0, 0x22                # '"'
        bne     tp, s0, f_var
        li      a2, 4
        sb      a2, -7(gp)              # No string! ExpError
        li      a1, 0
        j       f_exit

    f_var:
        jal     Variable                # 変数，配列参照
    f_exit:
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# コンソールから数値入力
#-------------------------------------------------------------------------
NumInput:
        addi    sp, sp, -32
        sd      a3, 24(sp)
        sd      a2, 16(sp)
        sd      a0,  8(sp)
        sd      ra, (sp)
        mv      a2, s1                  # EOL状態退避
        li      a0, MAXLINE             # 1 行入力
        mv      a3, t2
        la      a1, input2              # 行ワークエリア
        jal     READ_LINE3
        mv      t2, a1
        lbu     tp, (t2)                # 1文字先読み
        addi    t2, t2, 1
        jal     Decimal
        mv      t2, a3
        mv      a1, a0
        mv      s1, a2                  # EOL状態復帰
        jal     GetChar
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# コンソールから input2 に文字列入力
#-------------------------------------------------------------------------
StringInput:
        addi    sp, sp, -32
        sd      a2, 16(sp)
        sd      a0,  8(sp)
        sd      ra, (sp)
        mv      a2, s1                  # EOL状態退避
        li      a0, MAXLINE             # 1 行入力
        la      a1, input2              # 行ワークエリア
        jal     READ_LINE3
    2:  add     s0, gp, '%' * 8         # %
        sd      a0, (s0)                # 文字数を返す
        mv      s1, a2                  # EOL状態復帰
        jal     GetChar
        ld      a2, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# 文字定数を数値に変換
# a1 に数値が返る
#-------------------------------------------------------------------------
CharConst:
        addi    sp, sp, -32
        sd      a2, 16(sp)
        sd      a0,  8(sp)
        sd      ra, (sp)
        li      a1, 0
        li      a0, 4                   # 文字定数は4バイトまで
    1:
        jal     GetChar
        li      s0, 0x27                # '
        beq     tp, s0, 2f
        slli    s0, a1, 8
        add     a1, tp, s0
        addi    a0, a0, -1
        bnez    a0, 1b
    2:
        jal     GetChar
        ld      a2, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# 16進整数の文字列を数値に変換
# a1 に数値が返る
#-------------------------------------------------------------------------
Hex:
        lbu     tp,(t2)                 # check $$
        li      s0, '$'
        beq     tp, s0, StringInput
        addi    sp, sp, -32
        sd      s2, 24(sp)
        sd      a2, 16(sp)
        sd      a0,  8(sp)
        sd      ra, (sp)
        li      a1, 0
        mv      a2, a1
    1:
        jal     GetChar                 # $ の次の文字
        mv      s2, tp
        jal     IsHexNum
        bltz    a0, 2f
        slli    s0, a1, 4
        add     a1, s0, a0
        addi    a2, a2, 1
        j       1b
    2:
        beqz    a2, CharInput
        ld      s2, 24(sp)
        ld      a2, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#---------------------------------------------------------------------
# s2 の文字が16進数字かどうかのチェック
# 数字なら整数に変換して a0 に返す. 非数字なら a0 に-1を返す
#---------------------------------------------------------------------
IsNum2: li      s0, '0'                 # 0 - 9
        bgeu    s2, s0, 1f
    0:  li      a0, -1
        ret
    1:  li      s0, ':'                 # tp > '9'
        bgeu    s2, s0, 0b
        addi    a0, s2, -'0'            # 整数に変換 Cy=0
    2:  ret

IsHex:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     IsHex1                  # A - F ?
        bgez    a0, 1f                  # yes goto 1f
        jal     IsHex2                  # a - f ?
        bltz    a0, 2f
    1:  addi    a0, a0, 10
    2:  ld      ra, (sp)
        addi    sp, sp, 16
        ret

IsHex1:
        li      s0, 'A'                 # 英大文字(A-F)か?
        bgeu    s2, s0, 2f              # s2 >= 'A'
    1:  li      a0, -1
        ret
    2:  li      s0, 'G'                 # s2 >= 'G' return -1
        bgeu    s2, s0, 1b
        addi    a0, s2, -'A'            # 'A' <= s2 <= 'F'
        ret

IsHex2:
        li      s0, 'a'                 # 英大文字(A-F)か?
        bgeu    s2, s0, 2f              # s2 >= 'a'
    1:  li      a0, -1
        ret
    2:  li      s0, 'g'                 # s2 >= 'g' return -1
        bgeu    s2, s0, 1b
        addi    a0, s2, -'a'            # 'a' <= s2 <= 'f'
        ret

IsHexNum:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     IsNum2                  # 数字か?
        bgez    a0, 1f                  # yes
        jal     IsHex                   # Hexか?
    1:  ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# コンソールから 1 文字入力, a1 に返す
#-------------------------------------------------------------------------
CharInput:
        jal     InChar
        mv      a1, a0
        ld      s2, 24(sp)
        ld      a2, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# 行の編集(メモリ中のソースを行編集バッファにコピーして行編集)
#   a0 行番号
#   tp    次の文字(GetCharが返す)
#   t1    実行時行先頭
#   t2    ソースへのポインタ(getcharで更新)
#   t0    変数のアドレス
#   s1    EOLフラグ
#   s2    変数スタックポインタ
#   gp    変数領域の先頭アドレス
#   s4    局所的な作業レジスタ
#-------------------------------------------------------------------------
LineEdit:
        jal     LineSearch              # 入力済み行番号を探索
        beqz    a1, 4f                  # 見つからないので終了
        la      t2, input2              # 入力バッファ
        lwu     a0, 4(t1)
        jal     PutDecimal              # 行番号書き込み
        li      a0, ' '
        sb      a0, (t2)
        addi    t2, t2, 1               # 行内容の書込み先
        addi    t1, t1, 8               # 行番号の後ろの本文へ
    2:
        lbu     a0, (t1)                # ソース行を読み込み
        sb      a0, (t2)                # 入力バッファにコピー
        addi    t2, t2, 1               # 1文字進める
        addi    t1, t1, 1
        bne     a0, zero, 2b            # 行末か?
    3:
        jal     DispPrompt
        li      a0, MAXLINE             # バッファサイズ
        la      a1, input2              # バッファアドレス
        jal     READ_LINE2              # 初期化済行入力
        mv      t2, a1                  # 入力バッファ先頭
        mv      t1, t2
    4:
        li      s1, 0                   # EOL=no, 入力済み
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret                             # Mainloopにreturn

#-------------------------------------------------------------------------
# ListMore
#   a0 に表示開始行番号
#-------------------------------------------------------------------------
ListMore:
        jal     LineSearch              # 表示開始行を検索
        jal     GetChar                 # skip '+'
        jal     Decimal                 # 表示行数を取得
        bgtz    a0, 1f
        li      a0, 20                  # 表示行数無指定は20行
    1:  mv      a2, t1
    2:  lw      a1, (a2)                # 次行までのオフセット
        bltz    a1, List_all            # コード最終か?
        lw      a3, 4(a2)               # 行番号
        add     a2, a2, a1              # 次行先頭
        addi    a0, a0, -1
        bnez    a0, 2b
        j       List_loop

#-------------------------------------------------------------------------
# List
#  a0 に表示開始行番号
#  t1 表示行先頭アドレス(破壊)
#-------------------------------------------------------------------------
List:
        bnez    a0, 1f                  # partial
        add     s0, gp, '=' * 8         # プログラム先頭
        ld      t1, (s0)
        j       List_all

    1:  jal     LineSearch              # 表示開始行を検索
        jal     GetChar                 # 仕様では -
        jal     Decimal                 # 範囲最終を取得
        bltz    a1, List_all
        mv      a3, a0                  # 終了行番号
        j       List_loop

List_all:
        li      a3, -1                  # 最終まで表示(最大値)
List_loop:
        lw      a2, (t1)                # 次行までのオフセット
        bltz    a2, 6f                  # コード最終か?
        lw      a0, 4(t1)               # 行番号
        bltz    a0, 6f
        jal     PrintLeft               # 行番号表示
        li      a0, ' '
        jal     OutChar
        li      a1, 8
    4:
        add     s0, t1, a1
        lbu     a0, (s0)                # コード部分表示
        beqz    a0, 5f                  # 改行
        jal     OutChar
        addi    a1, a1, 1               # 次の1文字
        j       4b
    5:  jal     NewLine
        add     t1, t1, a2
        j       List_loop               # 次行処理
    6:
        li      s1, 1                   # 次に行入力 EOL=yes
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret                             # Mainloopにreturn

.ifdef DEBUG

#-------------------------------------------------------------------------
# デバッグ用プログラム行リスト <xxxx> 1#
#-------------------------------------------------------------------------
DebugList:
        addi    sp, sp, -16
        sd      t1, 8(sp)
        sd      ra, (sp)
        addi    s0, gp, '=' * 8         # プログラム先頭
        lw      t1, (s0)
        mv      a0, t1
        jal     PrintHex16              # プログラム先頭表示
        li      a0, ' '
        jal     OutChar
        add     s0, gp, '&' * 8         # ヒープ先頭
        lw      a0, (s0)
        jal     PrintHex16              # ヒープ先頭表示
        sub     a2, a0, t1              # プログラム領域サイズ
        li      a0, ' '
        jal     OutChar
        mv      a0, a2
        jal     PrintLeft
        jal     NewLine
        li      a3, -1                  # 最終まで表示(最大値)
    1:
        mv      a0, t1
        jal     PrintHex16              # 行頭アドレス
        lw      a2, (t1)                # 次行までのオフセット
        li      a0, ' '
        jal     OutChar
        mv      a0, a2
        jal     PrintHex8               # オフセットの16進表記
        li      a1, 4                   # 4桁右詰
        jal     PrintRight              # オフセットの10進表記
        li      a0, ' '
        jal     OutChar
        blez    a2, 4f                  # コード最終か?

        lw      a0, 4(t1)               # 行番号
        bltu    a3, a0, 4f
        jal     PrintLeft               # 行番号表示
        li      a0, ' '
        jal     OutChar
        li      a1, 8
    2:
        add     s0, t1, a1
        lbu     a0, (s0)                # コード部分表示
        beq     a0, zero, 3f            # 改行
        jal     OutChar
        addi    a1, a1, 1               # 次の1文字
        j       2b
    3:  jal     NewLine
        add     t1, t1, a2
        j       1b                      # 次行処理

    4:  jal     NewLine
        ld      t1,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

call_DebugList:
        jal     DebugList
        ld      ra, (sp)
        addi    sp, sp, 16
        ret                             # Mainloopにreturn

#-------------------------------------------------------------------------
# デバッグ用変数リスト <xxxx> 1$
#-------------------------------------------------------------------------
VarList:
        addi    sp, sp, -16
        sd      ra, (sp)

        li      a2, 0x21
    1:  mv      a0, a2
        jal     OutChar
        li      a0, ' '
        jal     OutChar
        slli    s0, a2, 3
        add     s0, gp, s0
        ld      a0, (s0)
        jal     PrintHex16
        li      a1, 20
        jal     PrintRight
        jal     NewLine
        addi    a2, a2, 1
        li      s0, 0x7F
        bltu    a2, s0, 1b
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

call_VarList:
        jal     VarList
        ld      ra, (sp)
        addi    sp, sp, 16
        ret                             # Mainloopにreturn

#-------------------------------------------------------------------------
# デバッグ用ダンプリスト <xxxx> 1%
#-------------------------------------------------------------------------
DumpList:
        addi    sp, sp, -16
        sd      tp,  8(sp)
        sd      ra, (sp)
        add     s0, gp, '=' * 8         # プログラム先頭
        ld      a2, (s0)
        andi    a2, a2, 0xfffffffffffffff0  # 16byte境界から始める
        li      tp, 16
    1:  mv      a0, a2
        jal     PrintHex16              # 先頭アドレス表示
        li      a0, ' '
        jal     OutChar
        li      a0, ':'
        jal     OutChar
        li      a3, 16
    2:
        li      a0, ' '
        jal     OutChar
        lbu     a0, (a2)                # 1バイト表示
        addi    a2, a2, 1
        jal     PrintHex2
        addi    a3, a3, -1
        bnez    a3, 2b
        jal     NewLine
        addi    tp, tp, -1
        bnez    tp, 1b                  # 次行処理
   3:
        ld      tp,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

call_DumpList:
        jal     DumpList
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# デバッグ用ラベルリスト <xxxx> 1&
#-------------------------------------------------------------------------
LabelList:
        addi    sp, sp, -16
        sd      ra, (sp)
        la      a4, LabelTable          # ラベルテーブル先頭
        la      a2, TablePointer
        ld      a3, (a2)                # テーブル最終登録位置
    1:
        bgeu    a4, a3, 2f
        ld      a0, 24(a4)
        jal     PrintHex16
        li      a0, ' '
        jal     OutChar
        mv      a0, a4
        jal     OutAsciiZ
        jal     NewLine
        addi    a4, a4, 32
        j       1b
     2:
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

call_LabelList:
        jal     LabelList
        ld      ra, (sp)
        addi    sp, sp, 16
        ret                             # Mainloopにreturn
.endif

#-------------------------------------------------------------------------
#  編集モード
#  Mainloopからcallされる
#       0) 行番号 0 ならリスト
#       1) 行が行番号のみの場合は行削除
#       2) 行番号の直後が - なら行番号指定部分リスト
#       3) 行番号の直後が + なら行数指定部分リスト
#       4) 行番号の直後が ! なら指定行編集
#       5) 同じ行番号の行が存在すれば入れ替え
#       6) 同じ行番号がなければ挿入
#-------------------------------------------------------------------------
EditMode:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     Decimal                 # 行番号取得
        beqz    a0, List                # 行番号 0 ならリスト
        bne     tp, zero, 1f            # 行番号のみでない
        jal     LineDelete              # 行削除(a0)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret                             # 戻って Mainloop

    1:  li      s0, '-'
        beq     tp, s0, List            # 部分リスト
        li      s0, '+'
        beq     tp, s0, ListMore        # 部分リスト 20行
.ifdef DEBUG
        li      s0, '#'
        beq     tp, s0, call_DebugList  # デバッグ用行リスト(#)
        li      s0, '$'
        beq     tp, s0, call_VarList    # デバッグ用変数リスト($)
        li      s0, '%'
        beq     tp, s0, call_DumpList   # デバッグ用ダンプリスト(%)
        li      s0, '&'
        beq     tp, s0, call_LabelList  # デバッグ用ラベルリスト(&)
.endif
        li      s0, '!'
        beq     tp, s0, LineEdit        # 指定行編集
        jal     LineSearch              # 入力済み行番号を探索
        beqz    a1, LineInsert          # 一致する行がなければ挿入
        jal     LineDelete              # 行置換(行削除+挿入)

#-------------------------------------------------------------------------
# 行挿入
# a0 に挿入行番号
# t1 にLineSearchに結果の挿入位置
# t2 は入力バッファの行番号の後ろを示している
# a1-a5 破壊
#-------------------------------------------------------------------------
LineInsert:
        li      a1, 0                   # 挿入する行のサイズを計算
    1:  add     s0, t2, a1              # t2:入力バッファ先頭
        lbu     a2, (s0)                #
        addi    a1, a1, 1               # 次の文字
        bnez    a2,  1b
        addi    a1, a1, 12              # 12=4+4+1+3
        li      s0, 0xfffffffc          # 4バイト境界に整列
        and     a1, a1, s0              # a1:挿入する行のバイト数

        add     s0, gp, '&' * 8         # ヒープ先頭(コード末+1)
        ld      a3, (s0)                # ヒープ先頭アドレス
        mv      a2, a3                  # 元のヒープ先頭
        add     a3, a3, a1              # 新ヒープ先頭計算
        sd      a3, (s0)                # 新ヒープ先頭設定

        sub     a4, a2, t1              # 移動バイト数
        addi    a2, a2, -1              # 始めは old &-1 から
        addi    a3, a3, -1              # new &-1 へのコピー

    2:  # 挿入位置より後ろを挿入バイト数だけ後方へ移動
        lbu     a5, (a2)                # メモリ後部から移動
        sb      a5, (a3)
        addi    a2, a2, -1              # old から
        addi    a3, a3, -1              # new へのコピー
        addi    a4, a4, -1              # tpバイト移動
        bnez    a4, 2b

        sw      a1, (t1)                # 次行へのオフセット設定
        sw      a0, 4(t1)               # 行番号設定
        addi    t1, t1, 8               # 書き込み位置更新

    3:  # 入力バッファから挿入
        lbu     a2, (t2)                # t2:入力バッファ
        sb      a2, (t1)                # t1:挿入位置
        addi    t2, t2, 1
        addi    t1, t1, 1
        bnez    a2, 3b                  # 行末?
        li      s1, 1                   # 次に行入力 EOL=yes
        ld      ra, (sp)
        addi    sp, sp, 16
        ret                             # Mainloopにreturn

#-------------------------------------------------------------------------
# 行の削除
# a0 に検索行番号
# a1-a4 破壊
#-------------------------------------------------------------------------
LineDelete:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     LineSearch              # 入力済み行番号を探索
        beqz    a1, 2f                  # 一致する行がなければ終了

        lw      a2, (t1)                # 次行オフセット取得
        add     a2, t1, a2              # 次行先頭位置取得
        add     s0, gp, '&' * 8         # ヒープ先頭
        ld      a3, (s0)                # プログラム最終位置+1
        sub     a0, a2, t1              # 削除バイト数
        sub     a4, a3, a2              # a4:移動バイト数
        sub     a3, a3, a0              # ヒープ先頭位置更新
        sd      a3, (s0)                # プログラム最終位置更新
        mv      a1, t1
    1:  lbu     a0, (a2)                # a4バイト移動
        sb      a0, (a1)
        addi    a2, a2, 1
        addi    a1, a1, 1
        addi    a4, a4, -1
        bnez    a4, 1b
    2:
        li      s1, 1                   # 次に行入力 EOL=yes
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 入力済み行番号を探索
# a0 に検索行番号、a1, a2 破壊
# t1 = 行番号一致行先頭アドレスまたは次に大きい行番号先頭アドレスに設定
# 同じ行番号があれば a1=1
#-------------------------------------------------------------------------
LineSearch:
        addi    s0, gp, '=' * 8         # プログラム先頭
        ld      t1, (s0)
LineSearch_nextline:
    1:  lw      a1, (t1)                # 次行オフセット
        bltz    a1, 3f                  # コード末なら検索終了
        lw      a2, 4(t1)               # 行番号
        beq     a0, a2, 2f              # 検索行a0 = 注目行a2
        bltu    a0, a2, 3f              # 検索行a0 < 注目行a2
        add     t1, t1, a1              # 次行先頭 (t1=t1+offset)
        j       1b
    2:  li      a1, 1
        ret
    3:  li      a1, 0
        ret

#-------------------------------------------------------------------------
# 10進文字列を整数に変換
# a0 に数値が返る、非数値ならa1に-1
# 1 文字先読み(tp)で呼ばれ、1 文字先読み(tp)して返る
#-------------------------------------------------------------------------
Decimal:
        addi    sp, sp, -32
        sd      a3, 24(sp)              # 数値
        sd      a2, 16(sp)              # １なら負
        sd      ra, (sp)
        li      a2, 0                   # 正の整数を仮定
        li      a3, 0
        li      a1, 10
        li      s0, '+'
        beq     tp, s0, 1f
        li      s0, '-'
        bne     tp, s0, 2f              # 正なら
        li      a2, 1                   # 負の整数
    1:
        jal     GetDigit
        bltz    a0, 4f                  # 数字でなければ返る
        j       3f
    2:
        jal     IsNum                   # a0 に数値
        bltz    a0, 5f                  # 数字でない
    3:
        mul     a3, a3, a1
        add     a3, a3, a0              # a3 = a3*10 + a0
        jal     GetDigit
        bgez    a0, 3b
        beq     a2, zero, 4f            # 数は正か？
        sub     a3, zero, a3            # 負にする
    4:  li      a1, 0
    5:  mv      a0, a3
        ld      a3, 24(sp)
        ld      a2, 16(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# 符号無し10進数文字列 t2 の示すメモリに書き込み
# a0 : 数値
#-------------------------------------------------------------------------
PutDecimal:
        addi    sp, sp, -48
        sd      a4, 40(sp)
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      ra, (sp)
        mv      a4, sp
        addi    sp, sp, -32             # allocate buffer
        li      a2, 0                   # counter
        li      a3, 10                  #
    1:  divu    s0, a0, a3              # a0/a1 = a0...a1
        remu    a1, a0, a3
        mv      a0, s0
        addi    a2, a2, 1               # counter++
        addi    a4, a4, -1
        sb      a1, (a4)                # least digit (reminder)
        bnez    a0, 1b                  # done ?
    2:  lbu     a0, (a4)                # most digit
        addi    a0, a0, '0'             # ASCII
        sb      a0, (t2)                # output a digit
        addi    a4, a4, 1
        addi    t2, t2, 1
        addi    a2, a2, -1              # counter--
        bnez    a2, 2b
        addi    sp, sp, 32              # unalloc buffer
        ld      a4, 40(sp)
        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      ra, (sp)
        addi    sp, sp, 48
        ret

#---------------------------------------------------------------------
# tp の文字が数字かどうかのチェック
# 数字なら整数に変換して a0 に返す. 非数字ならa0に−１を返す
#---------------------------------------------------------------------
IsNum:  li      s0, '0'                 # 0 - 9
        bgeu    tp, s0, 1f
    0:  li      a0, -1                  # tp<'0' or tp>'9' a0=-1
        ret
    1:  li      s0, ':'                 # tp > '9'
        bgeu    tp, s0, 0b              # tp>'9' a0=-1
        addi    a0, tp, -'0'            # '0'<tp<'9' return a0=0..9
        ret

GetDigit:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar                 # 0 - 9
        jal     IsNum
    1:  ld      ra, (sp)
        addi    sp, sp, 16
        ret

IsAlpha:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     IsAlpha1                # A - Z ?
        beqz    a0, 1f                  # yes return a0=0
        jal     IsAlpha2                # a - z ?
    1:  ld      ra, (sp)              # yes return a0=0
        addi    sp, sp, 16
        ret

IsAlpha1:
        li      s0, 'A'                 # 英大文字(A-Z)か?
        bgeu    tp, s0, 1f              # tp >= 'A' goto 1
    0:  li      a0, -1                  # tp<'A' or tp>'Z' a0=-1
        ret
    1:  li      s0, '['
        bgeu    tp, s0, 0b              # tp >= '[' return a0=-1
        li      a0, 0                   # 'A' < tp <'Z' return a0=0
        ret

IsAlpha2:
        li      s0, 'a'                 # 英小文字(a-z)か?
        bgeu    tp, s0, 1f              # tp >= 'a' goto 1
    0:  li      a0, -1                  # tp<'a' or tp>'z' a0=-1
        ret
    1:  li      s0, '{'
        bgeu    tp, s0, 0b              # tp >= '[' return a0=-1
        li      a0, 0                   # 'a' < tp <'z' return a0=0
        ret

IsAlphaNum:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     IsAlpha                 # 英文字なら a0=0
        beqz    a0, 1f
        jal     IsNum                   # 数字か? a0=数値
    1:  ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# ファイルから入力バッファに１行読み込み
#-------------------------------------------------------------------------
READ_FILE:
        addi    sp, sp, -16
        sd      ra, (sp)
        li      a3, 0                   #
        la      a1, input2              # 入力バッファアドレス
    1:
        ld      a0, -16(gp)             # FileDesc
        li      a2, 1                   # 読みこみバイト数
        li      a7, sys_read            # ファイルから読みこみ
        ecall
        jal     CheckError
        beqz    a0, 2f                  # EOF ?

        lbu     a0, (a1)
        li      s0, 10                  # LineFeed ?
        beq     a0, s0, 3f
        addi    a1, a1, 1               # input++
        j       1b
    2:
        ld      a0, -16(gp)             # FileDesc
        jal     fclose                  # File Close
        sb      a3, -4(gp)              # Read from console (0)
        jal     LoadCode                # 起動時指定ファイル有？
        j       4f
    3:  mv      s1, a3                  # EOL=no
    4:  sb      a3, (a1)
        la      t2, input2
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 数値出力 ?
#-------------------------------------------------------------------------
Com_OutNum:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar                 # get next
        li      s0, '='
        bne     tp, s0, 1f
        jal     Exp                     # PrintLeft
        jal     PrintLeft
        j       to_ret

    1:  li      s0, '*'                 # 符号無し10進
        beq     tp, s0, on_unsigned
        li      s0, '$'                 # ?$ 16進2桁
        beq     tp, s0, on_hex2
        li      s0, '#'                 # ?# 16進4桁
        beq     tp, s0, on_hex4
        li      s0, '?'                 # ?? 16進8桁
        beq     tp, s0, on_hex8
        li      s0, '%'                 # ?% 16進16桁
        beq     tp, s0, on_hex16
        mv      a3, tp
        jal     Exp
        andi    a1, a0, 0xff            # 表示桁数(MAA255)設定
        jal     SkipEqualExp            # 1文字を読み飛ばした後 式の評価
        li      s0, '{'                 # ?{ 8進数
        beq     a3 ,s0, on_oct
        li      s0, '!'                 # ?! 2進nビット
        beq     a3 ,s0, on_bin
        li      s0, '('                 # ?( print right
        beq     a3 ,s0, on_dec_right
        li      s0, '['                 # ?[ print right
        beq     a3, s0, on_dec_right0
        j       pop_and_Error           # スタック補正後 SyntaxError

    on_unsigned:
        jal     SkipEqualExp            # 1文字を読み飛ばした後 式の評価
        jal     PrintLeftU
        j       to_ret
    on_hex2:
        jal     SkipEqualExp            # 1文字を読み飛ばした後 式の評価
        jal     PrintHex2
        j       to_ret
    on_hex4:
        jal     SkipEqualExp            # 1文字を読み飛ばした後 式の評価
        jal     PrintHex4
        j       to_ret
    on_hex8:
        jal     SkipEqualExp            # 1文字を読み飛ばした後 式の評価
        jal     PrintHex8
        j       to_ret
    on_hex16:
        jal     SkipEqualExp            # 1文字を読み飛ばした後 式の評価
        jal     PrintHex16
        j       to_ret
    on_oct:
        jal     PrintOctal
        j       to_ret
    on_bin:
        jal     PrintBinary
        j       to_ret
    on_dec_right:
        jal     PrintRight
        j       to_ret
    on_dec_right0:
        jal     PrintRight0
    to_ret:
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 文字出力 $
#-------------------------------------------------------------------------
Com_OutChar:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar                 # get next
        li      s0, '='
        beq     tp, s0, 1f
        li      s0, '$'                 # $$ 2byte
        beq     tp, s0, 2f
        li      s0, '#'                 # $# 4byte
        beq     tp, s0, 4f
        li      s0, '%'                 # $% 8byte
        beq     tp, s0, 5f
        li      s0, '*'                 # $*=StrPtr
        beq     tp, s0, 7f
        j       8f                      # return

    1:  jal     Exp                     # 1バイト文字
        j       3f

    2:  jal     SkipEqualExp            # 2バイト文字
        li      s0, 0x00ff
        and     a1, a0, s0
        li      s0, 0x00ff
        and     a2, a0, s0
        srli    a0, a2, 8               # 上位バイトが先
        jal     OutChar
        mv      a0, a1
    3:  jal     OutChar
        j       8f                      # return

    4:  jal     SkipEqualExp            # 4バイト文字
        mv      a1, a0
        li      a2, 4
        j       6f

    5:  jal     SkipEqualExp            # 8バイト文字
        mv      a1, a0
        li      a2, 8
    6:  srl     a1, a1, 24              # 未検討
        andi    a0, a1, 0xff
        jal     OutChar
        addi    a2, a2, -1
        bne     a2, zero, 6b
        j       8f                      # return

    7:  jal     SkipEqualExp
        jal     OutAsciiZ
    8:  ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 空白出力 .=n
#-------------------------------------------------------------------------
Com_Space:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipEqualExp            # 1文字を読み飛ばした後 式の評価
        mv      a1, a0
        li      a0, ' '
    1:  jal     OutChar
        addi    a1, a1, -1
        bnez    a1, 1b
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 改行出力 /
#-------------------------------------------------------------------------
Com_NewLine:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     NewLine
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 文字列出力 "
#-------------------------------------------------------------------------
Com_String:
        addi    sp, sp, -16
        sd      ra, (sp)
        li      a1, 0
        mv      a0, t2
    1:  jal     GetChar
        li      s0, '"                  # "
        beq     tp, s0, 2f
        li      s0, 1                   # EOL=yes ?
        beq     s1, s0,   2f
        addi    a1, a1, 1
        j       1b
    2:
        jal     OutString
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# GOTO #
#-------------------------------------------------------------------------
Com_GO:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar
        li      s0, '!'
        beq     tp, s0, 2f              # #! はコメント、次行移動
.ifdef VTL_LABEL
        jal     ClearLabel
.endif
        jal     SkipEqualExp2           # = をチェックした後 式の評価
Com_GO_go:
        lbu     s0, -3(gp)              # ExecMode=Direct ?
        beqz    s0, 4f                  # Directならラベル処理へ

.ifdef VTL_LABEL
        add     a1, gp, '^' * 8         # システム変数「^」のチェック
        ld      a2, (a1)
        beqz    a2, 1f                  # 式中でラベル参照が無い場合は行番号
        mv      t1, a0                  # t1 をラベル行の先頭アドレスへ
        sd      zero, (a1)              # システム変数「^」クリア
        j       6f                      # check
.endif

    1: # 行番号
       # #=0 なら次行
        bnez    a0, 3f                  # 行番号にジャンプ
    2: # nextline
        li      s1, 1                   # 次行に移動  EOL=yes
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

    3: # ジャンプ先行番号を検索
        lw      a1, 4(t1)               # 現在の行と行番号比較
        bltu    a0, a1, 5f              # 飛び先が前なので先頭から
        jal     LineSearch_nextline     # 現在行から検索
        j       6f                      # check

    4: # label
.ifdef VTL_LABEL
        jal     LabelScan              # ラベルテーブル作成
.endif

    5: # top:
        jal     LineSearch              # t1 を指定行の先頭へ
    6: # check:
        lw      a0, (t1)                # コード末チェック
        bltz    a0, 7f                  # コード末なら停止
        li      a0, 1
        sb      a0, -3(gp)              # ExecMode=Memory
        jal     SetLineNo2              # 行番号を # に設定
        addi    t2, t1, 8               # 次行先頭
        li      s1, 0                   # EOL=no
        ld      ra, (sp)
        addi    sp, sp, 16
        ret
    7: # stop:
        jal     CheckCGI               # CGIモードなら終了
        jal     WarmInit1              # 入力デバイス変更なし
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

.ifdef VTL_LABEL
#-------------------------------------------------------------------------
# 式中でのラベル参照結果をクリア(ラベル無効化)
#-------------------------------------------------------------------------
ClearLabel:
        addi    s0, gp, '^' * 8
        sd      zero, (s0)              # システム変数「^」クリア
        ret

#-------------------------------------------------------------------------
# コードをスキャンしてラベルとラベルの次の行アドレスをテーブルに登録
# ラベルテーブルは32バイト／エントリで1024個(32KB)
# 24バイトのASCIIZ(23バイトのラベル文字) + 8バイト(行先頭アドレス)
# a0-a4保存, tp,t1 使用
#-------------------------------------------------------------------------
LabelScan:
        addi    sp, sp, -48
        sd      a4, 40(sp)
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra, (sp)
        addi    s0, gp, '=' * 8
        ld      t1, (s0)                # コード先頭アドレス
        lw      tp, (t1)                # コード末なら終了
        addi    tp, tp, 1
        bnez    tp, 1f                  # コード末でない
        j       8f

    1:  la      a3, LabelTable          # ラベルテーブル先頭
        la      a0, TablePointer
        sd      a3, (a0)                # 登録する位置格納

    2:  li      a1, 8                   # テキスト先頭位置
    3:                                  # 空白をスキップ
        add     s0, t1, a1
        lbu     tp, (s0)                # 1文字取得
        beqz    tp, 7f                  # 行末なら次行
        li      s0, ' '                 # 空白読み飛ばし
        bne     tp, s0, 4f              # ラベル登録へ
        add     a1, a1, 1
        j       3b

    4: # nextch
        li      s0, '^'                 # ラベル?
        bne     tp, s0, 7f              # ラベルでなければ
        # ラベルを登録
        add     a1, a1, 1               # ラベル文字先頭
        li      a2, 0                   # ラベル長
    5:
        add     s0, t1, a1
        lbu     tp, (s0)                # 1文字取得
        beqz    tp, 6f                  # 行末
        li      s0, ' '                 # ラベルの区切りは空白
        beq     tp, s0, 6f              # ラベル文字列
        li      s0, 23                  # 最大11文字まで
        beq     a2, s0, 6f              # 文字数
        add     s0, a3, a2
        sb      tp, (s0)                # 1文字登録
        addi    a1, a1, 1
        addi    a2, a2, 1
        j       5b                      # 次の文字

    6: # registerd
        li      tp, 0
        add     s0, a3, a2
        sb      tp, (s0)                # ラベル文字列末
        lw      tp, (t1)                # 次行オフセット
        add     tp, t1, tp              # tpに次行先頭
        sd      tp, 24(a3)              # アドレス登録
        addi    a3, a3, 32
        mv      t1, tp
        sd      a3, (a0)                # 次に登録する位置(TablePointer)

    7:                                  # 次行処理
        lw      tp, (t1)                # 次行オフセット
        add     t1, t1, tp              # t1に次行先頭
        lw      tp, (t1)                # 次行オフセット
        addi    tp, tp, 1
        beqz    tp, 8f                  # スキャン終了
        beq     a3, a0, 8f              # テーブル最終位置ならスキャン終了
        j       2b                      # 次行の処理を繰り返し

    8: # finish:
        ld      a4, 40(sp)
        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 48
        ret

#-------------------------------------------------------------------------
# テーブルからラベルの次の行アドレスを取得
# ラベルの次の行の先頭アドレスを a1 と「^」に設定、tpに次の文字を設定
# して返る。Factorから t2 を^の次に設定して呼ばれる
# t2 はラベルの後ろ(長すぎる場合は読み飛ばして)に設定される
# a0 が 0 なら a1 にラベルアドレス
# a2, a3 は破壊
#-------------------------------------------------------------------------
LabelSearch:
        addi    sp, sp, -16
        sd      a4,  8(sp)
        sd      ra, (sp)
        la      a3, LabelTable          # ラベルテーブル先頭
        la      a6, TablePointer
        ld      a5, (a6)                # テーブル最終登録位置

    1:
        li      a2, 0                   # ラベル長
    2:
        add     s0, t2, a2              # 読み取り中のソース位置
        lbu     tp, (s0)                # ソース1文字取得
        add     s0, a3, a2              # ラベルテーブルの文字位置
        lbu     a4, (s0)                # ラベルテーブルの1文字
        bnez    a4, 3f                  # ラベル文字列の最後でないか
        jal     IsAlphaNum              # tp が[AZat09] なら a0>=0
        bltz    a0, 5f                  # 入力が英数字以外ならラベル発見
    3:  bne     tp, a4, 6f              # 一致しない場合は次のラベル
        addi    a2, a2, 1               # 一致したら次の文字
        li      s0, 24                  # 長さのチェック
        ble     a2, s0, 2b              # 24文字未満なら次の文字を比較

    4:  jal     Skip_excess             # 長過ぎるラベルは後ろを読み飛ばし
    5:  # found
        ld      a1, 24(a3)              # テーブルからアドレス取得
        add     s0, gp, '^' * 8         # システム変数「^」に
        sd      a1, (s0)                # ラベルの次行先頭を設定
        add     t2, t2, a2
        jal     GetChar
        li      a0, 0                   # 見つかった a0 = 0
        ld      a4,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

    6:  # next
        beq     a3, a5, 7f              # 最終エントリまで比較
        addi    a3, a3, 32
        beq     a3, a6, 7f              # テーブル領域最終?
        j       1b                      # 次のテーブルエントリ

    7:  # not found:
        li      a2, 0
        jal     Skip_excess             # ラベルを空白か行末まで読飛ばし
        li      a0, -1
        ld      a4,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

Skip_excess:
        addi    sp, sp, -16
        sd      ra, (sp)
    1:  add     s0, t2, a2
        lbu     tp, (s0)                # 長過ぎるラベルはスキップ
        jal     IsAlphaNum
        bltz    a0, 2f                  # 英数字以外
        addi    a2, a2, 1               # ソース行内の読み込み位置更新
        j       1b
    2:
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

.endif

#-------------------------------------------------------------------------
# = コード先頭アドレスを再設定
#-------------------------------------------------------------------------
Com_Top:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipEqualExp            # = を読み飛ばした後 式の評価
        mv      a3, a0
        jal     RangeCheck              # ',' <= '=' < '*'
        bnez    a2, 4f                  # 範囲外エラー
        add     s0, gp, '=' * 8         # コード先頭
        sd      a3, (s0)                # 式の値を=に設定 ==a3
        add     s0, gp, '*' * 8         # メモリ末
        ld      a2, (s0)                # a2=*
    1: # nextline:                      # コード末検索
        ld      a0, (a3)                # 次行へのオフセット
        addi    a1, a0, 1               # 行先頭が -1 ?
        beq     a1, zero, 2f            # yes
        ble     a0, zero, 3f            # 次行へのオフセット <= 0 不正
        ld      a1, 4(a3)               # 行番号 > 0
        ble     a1, zero, 3f            # 行番号 <= 0 不正
        add     a3, a3, a0              # 次行先頭アドレス
        ble     a2, a3, 3f              # 次行先頭 > メモリ末
        j       1b                      # 次行処理
    2: # found:
        mv      a2, a0                  # コード末発見
        j       Com_NEW_set_end         # & 再設定
    3: # endmark_err:
        la      a0, EndMark_msg         # プログラム未入力
        jal     OutAsciiZ
        jal     WarmInit
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

    4: # range_err
        jal     RangeError
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# コード末マークと空きメモリ先頭を設定 &
#   = (コード領域の先頭)からの相対値で指定, 絶対アドレスが設定される
#-------------------------------------------------------------------------
Com_NEW:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipEqualExp            # = を読み飛ばした後 式の評価
        add     s0, gp, '=' * 8         # コード先頭
        ld      a2, (s0)                # &==*8
        li      a0, -1                  # コード末マーク(-1)
        sd      a0, (a2)                # コード末マーク
Com_NEW_set_end:
        addi    a2, a2, 4               # コード末の次
        add     s0, gp, '&' * 8         # 空きメモリ先頭
        sd      a2, (s0)                #
        jal     WarmInit1               # 入力デバイス変更なし
        ld      ra, (sp)
        addi    sp, sp, 16
       ret

#-------------------------------------------------------------------------
# BRK *
#    メモリ最終位置を設定, brk
#-------------------------------------------------------------------------
Com_BRK:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipEqualExp            # = を読み飛ばした後 式の評価
        li      a7, sys_brk             # メモリ確保
        ecall
        add     s0, gp, '*' * 8         #    メモリ最終位置
        sd      a0, (s0)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# RANDOM '
#-------------------------------------------------------------------------
Com_RANDOM:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipEqualExp            # = を読み飛ばした後 式の評価
        addi    s0, gp, '`' * 8         # 乱数シード設定
        sd      a0, (s0)
        jal     sgenrand
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 範囲チェックフラグ [
#-------------------------------------------------------------------------
Com_RCheck:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipEqualExp            # = を読み飛ばした後 式の評価
        add     s0, gp, '[' * 8         # 範囲チェック
        sd      a0, (s0)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 変数または式をスタックに保存
#-------------------------------------------------------------------------
Com_VarPush:
        addi    sp, sp, -16
        sd      ra, (sp)
        ld      a2, -32(gp)             # VSTACK
        li      a3, VSTACKMAX
        addi    a3, a3, -1              # a3 = VSTACKMAX - 1
        la      a1, VarStack
    1: # next
        bgtu    a2, a3, VarStackError_over
        jal     GetChar
        li      s0, '='                 # +=式
        bne     tp, s0, 2f
        jal     Exp
        slli    s0, a2, 3
        add     s0, a1, s0
        sd      a0, (s0)                # 変数スタックに式を保存
        addi    a2, a2, 1
        j       3f
    2: # push2
        li      s0, ' '
        beq     tp, s0, 3f
        li      s0, 1                   # EOL=yes?
        beq     s1, s0, 3f
        slli    s0, tp, 3
        add     s0, gp, s0
        ld      a0, (s0)                # 変数の値取得
        slli    s0, a2, 3
        add     s0, a1, s0
        sd      a0, (s0)                # 変数スタックに式を保存
        addi    a2, a2, 1
        j       1b                      # 次の変数
    3: # exit
        sd      a2, -32(gp)             # VSTACK更新
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 変数をスタックから復帰
#-------------------------------------------------------------------------
Com_VarPop:
        addi    sp, sp, -16
        sd      ra, (sp)
        ld      a2, -32(gp)             # VSTACK
        la      a1, VarStack
    1: # next:
        jal     GetChar
        li      s0, ' '
        beq     tp, s0, 2f
        li      s0 , 1                  # EOL=yes?
        beq     s1, s0, 2f
        addi    a2, a2, -1
        blt     a2, zero, VarStackError_under
        slli    s0, a2, 3
        add     s0, a1, s0
        ld      a0, (s0)                # 変数スタックから復帰
        slli    s0, tp, 3
        add     s0, gp, s0
        sd      a0, (s0)                # 変数に値設定
        j       1b
    2: # exit:
        sd      a2, -32(gp)             # VSTACK更新
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# ファイル格納域先頭を指定 t0使用
#-------------------------------------------------------------------------
Com_FileTop:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipEqualExp            # = を読み飛ばした後 式の評価
        mv      t0, a0
        jal     RangeCheck              # 範囲チェック
        bnez    a2, 1f                  # Com_FileEnd:1 範囲外をアクセス
        addi    s0, gp, '{' * 8         # ファイル格納域先頭
        sd      a0, (s0)                # ラベル無効化
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# ファイル格納域最終を指定 t0使用
#-------------------------------------------------------------------------
Com_FileEnd:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     SkipEqualExp            # = を読み飛ばした後 式の評価
        mv      t0, a0
        jal     RangeCheck              # 範囲チェック
        bnez    a2, 1f                  # 範囲外をアクセス
        addi    s0, gp, '}' * 8         # ファイル格納域先頭
        sd      a0, (s0)                # ラベル無効化
        ld      ra, (sp)
        addi    sp, sp, 16
        ret
    1: # range_err
        jal     RangeError
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# CodeWrite <=
#-------------------------------------------------------------------------
Com_CdWrite:
        addi    sp, sp, -16
        sd      t2,  8(sp)
        sd      ra, (sp)
        jal     GetFileName
        jal     fwopen                  # open
        beqz    a0, 4f                  # exit
        bltz    a0, 5f                  # error
        sd      a0, -24(gp)             # FileDescW
        add     s0, gp, '=' * 8
        ld      a3, (s0)                # コード先頭アドレス

    1: # loop
        la      t2, input2              # ワークエリア(行)
        lw      a0, (a3)                # 次行へのオフセット
        addi    a0, a0, 1               # コード最終か?
        beqz    a0, 4f                  # 最終なら終了
        lwu     a0, 4(a3)               # 行番号取得
        jal     PutDecimal              # a0の行番号をt2に書き込み
        li      a0, ' '                 # スペース書込み
        sb      a0, (t2)                # Write One Char
        addi    t2, t2, 1
        li      a1, 8
    2: # code:
        add     s0, a3, a1              # コード先頭アドレス
        lbu     a0, (s0)                # コード部分読み込み
        beqz    a0, 3f                  # 行末か? file出力後次行
        sb      a0, (t2)                # Write One Char
        addi    t2, t2, 1
        addi    a1, a1, 1
        j       2b

    3: # next:
        lw      a1, (a3)                # 次行オフセット
        addi    a0, a1, 1               # コード最終か?
        beqz    a0, 4f                  # 最終なら終了
        add     a3, a3, a1              # 次行先頭へ
        li      a0, 10
        sb      a0, (t2)                # 改行書込み
        addi    t2, t2, 1
        sb      zero, (t2)              # EOL

        la      a0, input2              # バッファアドレス
        jal     StrLen                  # a0の文字列長をa1に返す
        mv      a2, a1                  # 書きこみバイト数
        mv      a1, a0                  # バッファアドレス
        ld      a0, -24(gp)             # FileDescW
        li      a7, sys_write           # system call
        ecall
        j       1b                      # 次行処理
    4: # exit:
        ld      a0, -24(gp)             # FileDescW
        jal     fclose                  # ファイルクローズ
        li      s1, 1                   # EOL=yes
        ld      t2,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

    5: # error:
        j       pop_and_Error

#-------------------------------------------------------------------------
# CodeRead >=
#-------------------------------------------------------------------------
Com_CdRead:
        addi    sp, sp, -16
        sd      ra, (sp)
        lbu     a0, -4(gp)
        bnez    a0, 2f
        jal     GetFileName
        jal     fropen                  # open
        beqz    a0, 1f
        bltz    a0, SYS_Error
        sd      a0, -16(gp)             # FileDesc
        li      a1, 1
        sb      a1, -4(gp)              # Read from file
        mv      s1, a1                  # EOL
    1: # exit
        ld      ra, (sp)
        addi    sp, sp, 16
        ret
    2: # error
        la      a0, error_cdread
        jal     OutAsciiZ
        j       SYS_Error_return

#-------------------------------------------------------------------------
# 未定義コマンド処理(エラーストップ)
#-------------------------------------------------------------------------
pop_and_SYS_Error:
        addi    sp, sp, 16              # スタック修正
SYS_Error:
        jal     CheckError
SYS_Error_return:
        addi    sp, sp, 16              # スタック修正
        jal     WarmInit
        j       MainLoop

#-------------------------------------------------------------------------
# システムコールエラーチェック
#-------------------------------------------------------------------------
CheckError:
        addi    sp, sp, -32
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra, (sp)
        addi    s0, gp, '|' * 8         # 返り値を | に設定
        sd      a0, (s0)
.ifdef  DETAILED_MSG
        jal     SysCallError
.else
        bgez    a0, 1f
        la      a0, Error_msg
        jal     OutAsciiZ
.endif
    1:
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

#-------------------------------------------------------------------------
# FileWrite (=
#-------------------------------------------------------------------------
Com_FileWrite:
        addi    sp, sp, -16
        sd      ra, (sp)
        lbu     tp, (t2)                # check (*=\0
        li      s0, '*
        bne     tp, s0, 1f
        jal     GetChar
        jal     GetChar
        li      s0, '='
        bne     tp, s0, pop_and_Error
        jal     Exp                     # Get argument
        j       2f                      # open

    1:  jal     GetFileName
        jal     OutAsciiZ
    2:  jal     fwopen                  # open
        beqz    a0, 3f
        bltz    a0, SYS_Error
        sd      a0, -24(gp)             # FileDescW

        addi    s0, gp, '{' * 8         # 格納領域先頭
        ld      a1, (s0)                # バッファ指定
        addi    s0, gp, '}' * 8         # 格納領域最終
        ld      a3, (s0)                #
        bltu    a3, a1, 3f
        sub     a2, a3, a1              # 書き込みサイズ
        ld      a0, -24(gp)             # FileDescW
        li      a7, sys_write           # system call
        ecall
        jal     fclose
    3: # exit:
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# FileRead )=
#-------------------------------------------------------------------------
Com_FileRead:
        addi    sp, sp, -16
        sd      ra, (sp)
        lbu     tp, (t2)                # check )*=\0
        li      s0, '*
        bne     tp, s0, 1f
        jal     GetChar
        jal     GetChar
        li      s0, '='
        bne     tp, s0, pop_and_Error
        jal     Exp                     # Get argument
        j       2f                      # open

    1:  jal     GetFileName
    2:  jal     fropen                  # open
        beqz    a0, 3f
        bltz    a0, SYS_Error
        sd      a0, -24(gp)             # 第１引数 : fd
        li      a1, 0                   # 第２引数 : offset = 0
        li      a2, SEEK_END            # 第３引数 : origin
        li      a7, sys_lseek           # ファイルサイズを取得
        ecall

        mv      a3, a0                  # file_size 退避
        ld      a0, -24(gp)             # 第１引数 : fd
        li      a1, 0                   # 第２引数 : offset=0
        mv      a2, a1                  # 第３引数 : origin=0
        li      a7, sys_lseek           # ファイル先頭にシーク
        ecall

        addi    s0, gp, '{' * 8         # 格納領域先頭
        ld      a1, (s0)                # バッファ指定
        add     s0, gp, ')' * 8
        sd      a3, (s0)                # 読み込みサイズ設定
        add     a2, a1, a3              # 最終アドレス計算
        add     s0, gp, '}' * 8
        sd      a2, (s0)                # 格納領域最終設定
        add     s0, gp, '*' * 8
        ld      a3, (s0)                # RAM末
        bltu    a3, a1, 3f              # a3<a1 領域不足エラー

        ld      a0, -24(gp)             # FileDescW
        li      a7, sys_read            # ファイル全体を読みこみ
        ecall
        mv      a2, a0
        ld      a0, -24(gp)             # FileDescW
        jal     fclose
        bltz    a2, SYS_Error           # Read Error
    3: # exit
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# 終了
#-------------------------------------------------------------------------
Com_Exit:       #   7E  ~  VTL終了
        jal     RESTORE_TERMIOS
        jal     SET_TERMIOS2            # test
        j       Exit

#-------------------------------------------------------------------------
# ユーザ拡張コマンド処理
#-------------------------------------------------------------------------
Com_Ext:
        addi    sp, sp, -16
        sd      ra, (sp)
.ifndef SMALL_VTL
.include        "ext.s"
func_err:
        j       pop_and_Error
.endif
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# ForkExec , 外部プログラムの実行
#-------------------------------------------------------------------------
Com_Exec:
.ifndef SMALL_VTL
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra, (sp)
        jal     GetChar                 # skip =
        li      s0, '*
        bne     tp, s0, 0f
        jal     SkipEqualExp
        beqz    a0, pop_and_Error
        jal     GetString2
        j       3f

    0:  jal     GetChar                 # skip double quote
        li      s0, '"'                 # "
        beq     tp, s0, 1f
        addi    t2, t2, -1              # ungetc 1文字戻す
    1:
        jal     GetString               # 外部プログラム名取得
        la      a0, FileName            # ファイル名表示
        jal     OutAsciiZ
        jal     NewLine

    3:
        addi    sp, sp, -32
        sd      t0, 24(sp)
        sd      t2, 16(sp)
        sd      t1,  8(sp)
        sd      tp, (sp)
        jal     ParseArg                # コマンド行の解析
#        jal     CheckParseArg
        mv      t1, a1                  # リダイレクト先ファイル名
        addi    a6, a3, 1               # 子プロセスの数
        la      t6, exarg               # char ** argp
        li      t0, 0                   # 先頭プロセス
        li      s0, 1
        bgtu    a6, s0, 2f              # パイプが必要

        # パイプ不要な子プロセスを1つだけ生成
        li      a0, SIGCHLD             # clone_flags
        li      a1, 0                   # newsp
        li      a2, 0                   # parent_tidptr
        li      a3, 0                   # child_tidptr
        li      a4, 0                   # tls_val
        li      a7, sys_clone           # as sys_fork
        ecall
        jal     CheckError
        beqz    a0, child               # pid が 0 なら子プロセスの処理
        j       6f                      # 親は子プロセス終了を待つ処理へ

    2:  # パイプが必要な子プロセスを2つ以上生成する
        la      t2, ipipe               # パイプをオープン
        mv      a0, t2                  # t2 に pipe_fd 配列先頭
        li      a1, 0                   # flag = 0
        li      a7, sys_pipe2           # pipe システムコール
        ecall
        jal     CheckError

        #------------------------------------------------------------
        # fork
        #------------------------------------------------------------
        li      a0, SIGCHLD             # clone_flags
        li      a1, 0                   # newsp
        li      a2, 0                   # parent_tidptr
        li      a3, 0                   # child_tidptr
        li      a4, 0                   # tls_val
        li      a7, sys_clone           # as sys_fork
        ecall
        beqz    a0, child               # pid が 0 なら子プロセスの処理

        #------------------------------------------------------------
        # 親プロセス側の処理
        #------------------------------------------------------------
        beqz    t0, 3f                  # 先頭プロセスか?
        jal     close_old_pipe          # 先頭でなければパイプクローズ
    3:  ld      s4, (t2)                # パイプ fd の移動
        sd      s4, 8(t2)               # 直前の子プロセスのipipe
        ld      s4, 4(t2)
        sd      s4, 12(t2)              # 直前の子プロセスのopipe
        addi    a6, a6, -1              # 残り子プロセスの数
        beqz    a6, 5f                  # 終了

    4:  addi    t6, t6, 8               # 次のコマンド文字列探索
        ld      s4, (t6)
        bnez    s4, 4b                  # コマンド区切りを探す
        addi    t6, t6, 8               # 次のコマンド文字列設定
        addi    t0, t0, 1               # 次は先頭プロセスではない
        j       2b                      # 次の子プロセス生成

    5:  jal     close_new_pipe          #

    6:  # 子プロセスの終了を待つ a0=最後に起動した子プロセスのpid
        la      a1, stat_addr
        li      a2, WUNTRACED           # WNOHANG
        la      a3, ru                  # rusage
        li      a7, sys_wait4           # system call
        ecall
        jal     CheckError
        jal     SET_TERMIOS             # 子プロセスの設定を復帰

        ld      t0, 24(sp)
        ld      t2, 16(sp)
        ld      t1,  8(sp)
        ld      tp, (sp)
        addi    sp, sp, 32
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

        #------------------------------------------------------------
        # 子プロセス側の処理、 execveを実行して戻らない
        #------------------------------------------------------------
child:
        jal     RESTORE_TERMIOS
        addi    a6, a6, -1              # 最終プロセスチェック
        bnez    a6, pipe_out            # 最終プロセスでない
        beqz    t1, pipe_in             # リダイレクト無し, 標準出力
        mv      a0, t1                  # リダイレクト先ファイル名
        jal     fwopen                  # a0 = オープンした fd
        mv      s4, a0
        li      a1, 1                   # 標準出力をファイルに差替え
        li      a2, 0                   # flag = 0
        li      a7, sys_dup3            # dup2 システムコール
        ecall
        jal     CheckError
        mv      a0, s4
        jal     fclose                  # a0 にはオープンしたfd
        j       pipe_in

pipe_out:                               # 標準出力をパイプに
        ld      a0, 4(t2)               # 新パイプの書込み fd
        li      a1, 1                   # 標準出力
        li      a2, 0                   # flag = 0
        li      a7, sys_dup3            # dup2 システムコール
        ecall
        jal     CheckError
        jal     close_new_pipe

pipe_in:
        beqz    t0, execve              # 先頭プロセスならスキップ
                                        # 標準入力をパイプに
        ld      a0, 8(t2)               # 前のパイプの読出し fd
        li      a1, 0                   # new_fd 標準入力
        li      a2, 0                   # flag = 0
        li      a7, sys_dup3            # dup2 システムコール
        ecall
        jal     CheckError
        jal     close_old_pipe

execve:
        ld      a0, (t6)                # char * filename exarg(n)
        mv      a1, t6                  # char **argp     exarg+n
        la      a2, envp                # char ** envp
        li      a7, sys_execve          # system call
        ecall
        jal     CheckError              # 正常ならここには戻らない
        jal     Exit                    # 単なる飾り

close_new_pipe:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra, (sp)
        ld      a0, 4(t2)               # 出力パイプをクローズ
        jal     fclose
        ld      a0, (t2)                # 入力パイプをクローズ
        jal     fclose
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

close_old_pipe:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra, (sp)
        ld      a0, 12(t2)              # 出力パイプをクローズ
        jal     fclose
        ld      a0, 8(t2)               # 入力パイプをクローズ
        jal     fclose
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
.endif
        ret

#-------------------------------------------------------------------------
# デバッグ用
# a3 に パイプの数 (子プロセス数-1)
# a1 にリダイレクト先ファイル名文字列へのポインタ
#-------------------------------------------------------------------------
CheckParseArg:
        addi    sp, sp, -48
        sd      a4, 40(sp)
        sd      a3, 32(sp)
        sd      a2, 24(sp)
        sd      a1, 16(sp)
        sd      a0,  8(sp)
        sd      ra, (sp)
        beqz    a1, 0f
        mv      a0, a1
        jal     OutAsciiZ
        jal     NewLine
    0:
        li      a1, 0                   # 配列インデックス
        la      a2, exarg               # 配列先頭
    1:
        slli    s0, a1, 3
        add     s0, a2, s0              # exarg + i*8
        ld      a4, (s0)
        beqz    a4, 2f
        mv      a0, a1
        jal     PrintLeft
        li      a0, ' '
        jal     OutChar
        mv      a0, a4
        jal     OutAsciiZ
        jal     NewLine
        addi    a1, a1, 1
        j       1b
    2:
        beqz    a3, 3f                  # パイプの数 (子プロセス数-1)
        addi    a1, a1, 1               # 配列インデックス
        addi    a3, a3, -1
        j       1b
    3:
        ld      a4, 40(sp)
        ld      a3, 32(sp)
        ld      a2, 24(sp)
        ld      a1, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 48
        ret

#-------------------------------------------------------------------------
# execve 用の引数を設定
# コマンド文字列のバッファ FileName をAsciiZに変換してポインタの配列に設定
# a3 に パイプの数 (子プロセス数-1) を返す．a0 保存
# a1 にリダイレクト先ファイル名文字列へのポインタを返す．
#-------------------------------------------------------------------------
ParseArg:
        addi    sp, sp, -32
        sd      t1, 24(sp)
        sd      t2, 16(sp)
        sd      a0,  8(sp)
        sd      ra, (sp)
        li      a2, 0                   # 配列インデックス
        li      a3, 0                   # パイプのカウンタ
        li      a1, 0                   # リダイレクトフラグ
        la      t2, FileName            # コマンド文字列のバッファ
        la      t1, exarg               # ポインタの配列先頭
    1:
        lbu     a0, (t2)
        beqz    a0, pa_exit             # 文字列末なら戻る
        li      s0, ' '                 # 連続する空白のスキップ
        bne     a0, s0, 2f              # パイプのチェックへ
        addi    t2, t2, 1               # 空白なら次の文字
        j       1b

    2:  li      s0, '|'                 # パイプ?
        bne     a0, s0, 3f
        addi    a3, a3, 1               # パイプのカウンタ+1
        jal     end_mark                # null pointer書込み
        j       6f

    3:  li      s0, '>'                 # リダイレクト?
        bne     a0, s0, 4f
        li      a1, 1                   # リダイレクトフラグ
        jal     end_mark                # null pointer書込み
        j       6f

    4:  slli    s0, a2, 3
        add     s0, t1, s0
        sd      t2, (s0)                # 引数へのポインタを登録
        addi    a2, a2, 1               # 配列インデックス+1

    5:  lbu     a0, (t2)                # 空白を探す
        beqz    a0, 7f                  # 行末なら終了
        li      s0, ' '                 # 連続する空白のスキップ
        beq     a0, s0, 8f
        addi    t2, t2, 1
        j       5b                      # 空白でなければ次の文字

    8:  sb      zero, (t2)              # スペースを 0 に置換
        bnez    a1, 7f                  # > の後ろはファイル名のみ

    6:  addi    t2, t2, 1
        li      s0, ARGMAX              # 個数チェックして次
        bgeu    a2, s0, pa_exit
        j       1b

    7:  beqz    a1, pa_exit             # リダイレクトフラグ
        addi    a2, a2, -1              # 配列インデックス
        slli    s0, a2, 3
        add     s0, t1, s0
        ld      a1, (s0)                # a1:リダイレクト先ファイル名
        addi    a2, a2, 1
pa_exit:
        slli    s0, a2, 3
        add     s0, t1, s0
        sd      zero, (s0)              # 引数ポインタ配列の最後
        ld      t1, 24(sp)
        ld      t2, 16(sp)
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 32
        ret

end_mark:
        slli    s0, a2, 3
        add     s0, t1, s0
        sd      zero, (s0)              # コマンドの区切り NullPtr
        addi    a2, a2, 1               # 配列インデックス
        ret

#-------------------------------------------------------------------------
# 組み込みコマンドの実行
#-------------------------------------------------------------------------
Com_Function:
.ifndef SMALL_VTL
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar                 # get the next character of "|"
func_c:
        li      s0, 'c'
        bne     tp, s0, func_d
        jal     def_func_c              # |c
        j       func_return
func_d:
func_e:
        li      s0, 'e'
        bne     tp, s0, func_f
        jal     def_func_e              # |e
        j       func_return
func_f:
        li      s0, 'f'
        bne     tp, s0, func_l
        jal     def_func_f              # |f
        j       func_return
func_l:
        li      s0, 'l'
        bne     tp, s0, func_m
        jal     def_func_l              # |l
        j       func_return
func_m:
        li      s0, 'm'
        bne     tp, s0, func_n
        jal     def_func_m              # |m
        j       func_return
func_n:
func_p:
        li      s0, 'p'
        bne     tp, s0, func_q
        jal     def_func_p              # |p
        j       func_return
func_q:
func_r:
        li      s0, 'r'
        bne     tp, s0, func_s
        jal     def_func_r              # |r
        j       func_return
func_s:
        li      s0, 's'
        bne     tp, s0, func_t
        jal     def_func_s              # |s
        j       func_return
func_t:
func_u:
        li      s0, 'u'
        bne     tp, s0, func_v
        jal     def_func_u              # |u
        j       func_return
func_v:
        li      s0, 'v'
        bne     tp, s0, func_z
        jal     def_func_v              # |u
        j       func_return
func_z:
        li      s0, 'z'
        bne     tp, s0, pop_and_Error
        jal     def_func_z              # |z
func_return:
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#------------------------------------
# |c で始まる組み込みコマンド
#------------------------------------
def_func_c:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar
        li      s0, 'a'
        beq     tp, s0, func_ca         # cat
        li      s0, 'd'
        beq     tp, s0, func_cd         # cd
        li      s0, 'm'
        beq     tp, s0, func_cm         # chmod
        li      s0, 'r'
        beq     tp, s0, func_cr         # chroot
        li      s0, 'w'
        beq     tp, s0, func_cw         # pwd
        j       pop2_and_Error
func_ca:
        la      a0, msg_f_ca            # |ca file
        jal     FuncBegin
        ld      a0, (a1)                # filename
        jal     DispFile
        j       func_return2
func_cd:
        la      a0, msg_f_cd            # |cd path
        jal     FuncBegin
        ld      a1, (a1)                # char ** argp
        la      a0, FileName
        jal     OutAsciiZ
        jal     NewLine
        li      a7, sys_chdir           # system call
        ecall
        jal     CheckError
        j       func_return2
func_cm:
        la      a0, msg_f_cm            # |cm 644 file
        jal     FuncBegin
        mv      a2, a1
        ld      a0, 8(a2)               # file name
        jal     fropen                  # open
        jal     CheckError
        bltz    a0, 1f
        mv      a3, a0                  # save fd
        ld      a0, (a2)                # permission
        jal     Oct2Bin
        mv      a1, a0                  # permission
        mv      a0, a3                  # fd
        li      a7, sys_fchmod          # system call
        ecall
        jal     CheckError
    1:  j       func_return2
func_cr:
        la      a0, msg_f_cr            # |cr path
        jal     FuncBegin
        ld      a1, (a1)                # char ** argp
        la      a0, FileName
        jal     OutAsciiZ
        jal     NewLine
        li      a7, sys_chroot          # system call
        ecall
        jal     CheckError
        j       func_return2
func_cw:
        la      a0, msg_f_cw            # |cw
        jal     OutAsciiZ
        la      a0, FileName
        mv      a3, a0                  # save a0
        li      a1, FNAMEMAX
        li      a7, sys_getcwd          # system call
        ecall
        jal     CheckError
        mv      a0, a3                  # restore a0
        jal     OutAsciiZ
        jal     NewLine
        j       func_return2

#------------------------------------
# |e で始まる組み込みコマンド
#------------------------------------
def_func_e:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar
        li      s0, 'x'
        beq     tp, s0, func_ex         # execve
        j       pop2_and_Error
func_ex:
        la      a0, msg_f_ex            # |ex file arg ..
        jal     RESTORE_TERMIOS         # 端末設定を戻す
        jal     FuncBegin               # a1: char ** argp
        ld      a0, (a1)                # char * filename
        la      a2, exarg
        ld      a2, -24(a2)             # char ** envp
        li      a7, sys_execve          # system call
        ecall
        jal     CheckError              # 正常ならここには戻らない
        jal     SET_TERMIOS             # 端末のローカルエコーをOFF
        j       func_return2

#------------------------------------
# |f で始まる組み込みコマンド
#------------------------------------
def_func_f:
.ifdef FRAME_BUFFER
# .include        "vtlfb.s"
.endif

#------------------------------------
# |l で始まる組み込みコマンド
#------------------------------------
def_func_l:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar
        li      s0, 's'
        beq     tp, s0, func_ls         # ls
        j       pop2_and_Error

func_ls:
        la      a0, msg_f_ls            # |ls dir
        jal     FuncBegin
        ld      a2, (a1)
        bnez    a2, 1f
        la      a2, current_dir         # dir 指定なし
    1:  la      a3, DirName
        mv      a0, a3
    2:  lbu     s4, (a2)                # dir をコピー
        sb      s4, (a3)
        addi    a2, a2, 1
        addi    a3, a3, 1
        bnez    s4, 2b
        lbu     s4, -2(a3)              # dir末の/をチェック
        li      a2, '/'
        beq     s4, a2, 3f              # / 有
        sb      a2, -1(a3)              # / 書き込み
        sb      zero, (a3)              # end mark
    3:
        jal     fropen
        bltz     a0, 6f                 # エラーチェックして終了
        addi    sp, sp, -32
        sd      s11, 24(sp)
        sd      t2, 16(sp)
        sd      t1,  8(sp)
        sd      tp, (sp)
        mv      t1, a0                  # fd 保存
        la      s11, DirName            # for GetFileStat (rv6)
    4:  # ディレクトリエントリ取得
        # unsigned int fd, void * dirent, unsigned int count
        mv      a0, t1                  # fd 再設定
        la      a1, dir_ent             # バッファ先頭
        mv      tp, a1                  # tp : struct top (dir_ent)
        li      a2, size_dir_ent
        li      a7, sys_getdents64      # system call
        ecall
        bltz    a0, 6f                  # valid buffer length
        beqz    a0, 7f
        mv      a3, a0                  # a3 : buffer size

    5:  # dir_entからファイル情報を取得
        mv      a1, tp                  # tp : dir_ent
        jal     GetFileStat             # a1:dir_entアドレス
        la      a2, file_stat
        lh      a0, 16(a2)              # file_stat.st_mode
        li      a1, 6
        jal     PrintOctal              # mode
        ld      a0, 48(a2)              # file_stat.st_size
        li      a1, 12
        jal     PrintRight              # file size
        li      a0, ' '
        jal     OutChar
        addi    a0, tp, 19              # dir_ent.filename
        jal     OutAsciiZ               # filename
        jal     NewLine
        lh      a0, 16(tp)              # record length
        sub     a3, a3, a0              # バッファの残り
        beqz    a3, 4b                  # 次のディレクトリエントリ取得
        add     tp, tp, a0              # 次のdir_ent
        j       5b

    6:  jal     CheckError
    7:  mv      a0, t1                  # fd
        jal     fclose
        ld      s11, 24(sp)
        ld      t2, 16(sp)
        ld      t1,  8(sp)
        ld      tp, (sp)
        addi    sp, sp, 32
        j       func_return2

#------------------------------------
# |m で始まる組み込みコマンド
#------------------------------------
def_func_m:
         addi    sp, sp, -16
         sd      ra, (sp)
         jal     GetChar
         li      s0, 'd'
         beq     tp, s0, func_md        # mkdir
         li      s0, 'o'
         beq     tp, s0, func_mo        # mo
         li      s0, 'v'
         beq     tp, s0, func_mv        # mv
         j       pop2_and_Error

func_md:
        la      a0, msg_f_md            # |md dir (777)
        jal     FuncBegin
        mv      a3, a1
        ld      a0, 8(a3)               # permission
        bnez    a0, 1f
        ld      a2, c755
        j       2f
    1:  jal     Oct2Bin
        mv      a2, a0
    2:  li      a0, AT_FDCWD            # dfd
        ld      a1, (a3)                # directory name
        li      a7, sys_mkdirat         # system call
        ecall
        jal     CheckError
        j       func_return2

c755:   .long   0755

func_mo:
        la      a0, msg_f_mo            # |mo dev_name dir fstype
        jal     FuncBegin
        mv      a4, a1                  # exarg
        ld      a0, (a4)                # dev_name
        ld      a1,  8(a4)              # dir_name
        ld      a2, 16(a4)              # fstype
        ld      a3, 24(a4)              # flags
        beqz    a3, 1f                  # Read/Write
        ld      a3, (a3)
        li      a3, MS_RDONLY           # ReadOnly FileSystem
    1:
        li      a4, 0                   # void * data
        li      a7, sys_mount           # system call
        ecall
        jal     CheckError
        j       func_return2
func_mv:
        la      a0, msg_f_mv            # |mv fileold filenew
        jal     FuncBegin
        li      a4, 0                   # flag
        ld      a3, 8(a1)               # new filename
        li      a2, AT_FDCWD
        mv      a0, a2
        ld      a1, (a1)                # old filename
        li      a7, sys_renameat2       # system call
        ecall
        jal     CheckError
        j       func_return2

#------------------------------------
# |p で始まる組み込みコマンド
#------------------------------------
def_func_p:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar
        li      s0, 'v'
        beq     tp, s0, func_pv         # pivot_root
        j       pop2_and_Error

func_pv:
        la      a0, msg_f_pv            # |pv /dev/hda2 /mnt
        jal     FuncBegin
        ld      a0, (a1)
        ld      a1, 8(a1)
        li      a7, sys_pivot_root      # system call
        ecall
        jal     CheckError
        j       func_return2

#------------------------------------
# |r で始まる組み込みコマンド
#------------------------------------
def_func_r:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar
        li      s0, 'd'
        beq     tp, s0, func_rd         # rmdir
        li      s0, 'm'
        beq     tp, s0, func_rm         # rm
        li      s0, 't'
        beq     tp, s0, func_rt         # rt
        j       pop2_and_Error

func_rd:
        la      a0, msg_f_rd            # |rd path
        jal     FuncBegin               # char ** argp
        li      a0, AT_FDCWD
        li      a2, AT_REMOVEDIR
        ld      a1, (a1)                # path
        li      a7, sys_unlinkat        # system call
        ecall
        jal     CheckError
        j       func_return2

func_rm:
        la      a0, msg_f_rm            # |rm path
        jal     FuncBegin               # char ** argp
        ld      a1, (a1)
        li      a0, AT_FDCWD
        li      a2, 0
        li      a7, sys_unlinkat        # system call
        ecall
        jal     CheckError
        j       func_return2

func_rt:                                # reset terminal
        la      a0, msg_f_rt            # |rt
        jal     OutAsciiZ
        jal     SET_TERMIOS2            # cooked mode
        jal     GET_TERMIOS             # termios の保存
        jal     SET_TERMIOS             # raw mode
        j       func_return2

#------------------------------------
# |s で始まる組み込みコマンド
#------------------------------------
def_func_s:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar
        li      s0, 'f'
        beq     tp, s0, func_sf         # swapoff
        li      s0, 'o'
        beq     tp, s0, func_so         # swapon
        li      s0, 'y'
        beq     tp, s0, func_sy         # sync
        j       pop2_and_Error

func_sf:
        la      a0, msg_f_sf            # |sf dev_name
        jal     FuncBegin               # const char * specialfile
        ld      a0, (a1)
        li      a7, sys_swapoff         # system call
        ecall
        jal     CheckError
        j       func_return2

func_so:
        la      a0, msg_f_so            # |so dev_name
        jal     FuncBegin
        ld      a0, (a1)                # const char * specialfile
        li      a1, 0                   # int swap_flags
        li      a7, sys_swapon          # system call
        ecall
        jal     CheckError
        j       func_return2

func_sy:
        la      a0, msg_f_sy            # |sy
        li      a7, sys_sync            # system call
        ecall
        jal     CheckError
        j       func_return2

#------------------------------------
# |u で始まる組み込みコマンド
#------------------------------------
def_func_u:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar
        li      s0, 'm'
        beq     tp, s0, func_um         # umount
        li      s0, 'd'
        beq     tp, s0, func_ud         # URL Decode
        j       pop2_and_Error

func_um:
        la      a0, msg_f_um            # |um dev_name
        jal     FuncBegin               #
        ld      a0, (a1)                # dev_name
        li      a1, 0                   # flag
        li      a7, sys_umount2         # sys_umount2
        ecall
        jal     CheckError
        j       func_return2

func_ud:
        addi    s0, gp, 'u' * 8
        ld      s4, (s0)                # 引数は u(0) - u(3)
        ld      a0, (s4)                # a0 にURLエンコード文字列の先頭設定
        ld      a1,  8(s4)              # a1 に変更範囲の文字数を設定
        ld      a2, 16(s4)              # a2 にデコード後の文字列先頭を設定
        jal     URL_Decode
        sd      a0, 24(s4)              # デコード後の文字数を設定
        j       func_return2

#------------------------------------
# |v で始まる組み込みコマンド
#------------------------------------
def_func_v:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar
        li      s0, 'e'
        beq     tp, s0, func_ve         # version
        li      s0, 'c'
        beq     tp, s0, func_vc         # cpu
        j       pop2_and_Error

func_ve:
        ld      a3, version
        addi    s0, gp, '%' * 8
        sd      a3, (s0)                # バージョン設定
        li      a3, VERSION64
        sw      a3, 4(s0)               # 64bit
        j       func_return2
func_vc:
        li      a3, CPU
        addi    s0, gp, '%' * 8
        sd      a3, (s0)                # cpu
        j       func_return2

version:
        .long   VERSION

#------------------------------------
# |zz システムコール
#------------------------------------
def_func_z:
        addi    sp, sp, -16
        sd      ra, (sp)
        jal     GetChar
        li      s0, 'c'
        beq     tp, s0, func_zc         #
        li      s0, 'z'
        beq     tp, s0, func_zz         # system bl
        j       pop2_and_Error

func_zc:
        la      a1, counter
        ld      a3, (a1)
        add     s0, gp, '%' * 8
        sd      a3, (s0)                # cpu
        j       func_return2

func_zz:
        jal     GetChar                 # skip space
        jal     SystemCall
        jal     CheckError
func_return2:
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# URLデコード
#
# a0 にURLエンコード文字列の先頭設定
# a1 に変更範囲の文字数を設定
# a2 にデコード後の文字列先頭を設定
# a0 にデコード後の文字数を返す
#-------------------------------------------------------------------------
URL_Decode:
        addi    sp, sp, -48
        sd      s4, 40(sp)
        sd      s3, 32(sp)
        sd      s2, 24(sp)
        sd      s1, 16(sp)
        sd      t0,  8(sp)
        sd      ra, (sp)
        mv      a3, a0                  # top of input buffer
        add     s4, a3, a1
        addi    s4, s4, -1              # end of input encoded string
        li      t0, 0
    1:
        lbu     s1, (a3)                # get 1 byte
        add     a3, a3, 1
        li      s0, '+'                 # "space" inside query-string
        bne     s1, s0, 2f              # if s1!='+', goto 2f
        li      s1, ' '                 # s1 = ' '
        add     s0, a2, t0
        sb      s1, (s0)                # output space
        j       4f                      # next input char
    2:  li      s0, '%'
        beq     s1, s0, 3f              # if % encoded, goto 3f
        add     s0, a2, t0
        sb      s1, (s0)                # output character as it is
        j       4f                      # next input char

    3:  li      s1, 0                   # % decode
        lbu     s2, (a3)                # a character next to %
        add     a3, a3, 1
        jal     IsHexNum                # return value or -1 in a0
        bltz    a0, 4f                  # if not hexadecimal, next char

        add     s1, s1, a0
        lbu     s2, (a3)                # Skip one, the next byte
        addi    a3, a3, 1
        jal     IsHexNum                # return value or -1 in a0
        bltz    a0, 4f                  # if not hexadecimal, next char
        slli    s1, s1, 4
        add     s1, s1, a0
        add     s0, a2, t0
        sb      s1, (s0)                # output the % decoded byte
    4:
        addi    t0, t0, 1               # next input char
        ble     a3, s4, 1b

        add     s0, a2, t0
        sb      zero, (s0)              # mark end of line
        mv      a0, t0                  # return length
        ld      s4, 40(sp)
        ld      s3, 32(sp)
        ld      s2, 24(sp)
        ld      s1, 16(sp)
        ld      t0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 48
        ret

#-------------------------------------------------------------------------
# 組み込み関数用
#-------------------------------------------------------------------------
FuncBegin:
        addi    sp, sp, -16
        sd      a0,  8(sp)
        sd      ra, (sp)
        jal     OutAsciiZ
        jal     GetChar                 # get *
        li      s0, '*'
        bne     tp, s0, 1f
        jal     SkipEqualExp            # a0 にアドレス
        mv      a1, t0                  # t0退避
        mv      t0, a0                  # RangeCheckはt0を見る
        jal     RangeCheck              # コピー先を範囲チェック
        mv      t0, a1                  # コピー先復帰
        bnez    a2, 4f                  # 範囲外をアクセス
        jal     GetString2              # FileNameにコピー
        j       3f
    1:  lbu     s4, (t2)
        li      s0, '"'
        bne     s4, s0, 2f
        jal     GetChar                 # skip "
    2:  jal     GetString               # パス名の取得
    3:  jal     ParseArg                # 引数のパース
        la      a1, exarg
        ld      a0,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret
    4:  li      tp, 0xFF                # エラー文字を FF
        j       LongJump                # アクセス可能範囲を超えた

#-------------------------------------------------------------------------
# 8進数文字列を数値に変換
# a0 からの8進数文字列を数値に変換して a0 に返す
#-------------------------------------------------------------------------
Oct2Bin:
        addi    sp, sp, -16
        sd      a2,  8(sp)
        sd      ra, (sp)
        jal     GetOctal               # a1
        bltz    a1, 2f                 # exit
        mv      a2, a1
    1:
        jal     GetOctal
        bltz    a1, 2f                 # exit
        slli    a2, a2, 3
        add     a2, a2, a1
        j       1b
    2:
        mv      a0, a2
        ld      a2,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
        ret

#-------------------------------------------------------------------------
# a0 の示す8進数文字を数値に変換して a1 に返す
# a0 は次の文字に更新される
#-------------------------------------------------------------------------
GetOctal:
        lbu     a1, (a0)
        addi    a0, a0, 1
        addi    a1, a1, -'0'
        bltz    a1, 1f
        li      s0, 7
        ble     a1, s0, 2f
    1:  li      a1, -1
    2:  ret

#-------------------------------------------------------------------------
# ファイル内容表示
# a0 にファイル名
#-------------------------------------------------------------------
DispFile:
        addi    sp, sp, -16
        sd      a6,  8(sp)
        sd      ra, (sp)
        jal     fropen                 # open
        jal     CheckError
        bltz    a0, 3f
        mv      a6, a0                 # FileDesc
        li      a2, 16                 # read 16 byte
        addi    sp, sp, -16
        mv      a1, sp                 # a1 address
    1:
        mv      a0, a6                 # a0  fd
        li      a7, sys_read
        ecall
        jal     CheckError
        beqz    a0, 2f
        mv      a2, a0                 # a2  length
        li      a0, 1                  # a0  stdout
        li      a7, sys_write
        ecall
        j       1b
    2:
        mv      a0, a6
        jal     fclose
        addi    sp, sp, 16
    3:
        ld      a6,  8(sp)
        ld      ra, (sp)
        addi    sp, sp, 16
.endif                                 # .ifndef SMALL_VTL
        ret

#==============================================================
.data
                .align  3
n672274774:     .quad   672274774
mem_init:       .quad   MEMINIT

#-------------------------------------------------------------------------
# コマンド用ジャンプテーブル
#-------------------------------------------------------------------------
TblComm1:
        .quad Com_GOSUB    #   21  !  GOSUB
        .quad Com_String   #   22  "  文字列出力
        .quad Com_GO       #   23  #  GOTO 実行中の行番号を保持
        .quad Com_OutChar  #   24  $  文字コード出力
        .quad Com_Error    #   25  %  直前の除算の剰余または usec を保持
        .quad Com_NEW      #   26  &  NEW, VTLコードの最終使用アドレスを保持
        .quad Com_Error    #   27  '  文字定数
        .quad Com_FileWrite#   28  (  File 書き出し
        .quad Com_FileRead #   29  )  File 読み込み, 読み込みサイズ保持
        .quad Com_BRK      #   2A  *  メモリ最終(brk)を設定, 保持
        .quad Com_VarPush  #   2B  +  ローカル変数PUSH, 加算演算子, 絶対値
        .quad Com_Exec     #   2C  ,  fork & exec
        .quad Com_VarPop   #   2D  -  ローカル変数POP, 減算演算子, 負の十進数
        .quad Com_Space    #   2E  .  空白出力
        .quad Com_NewLine  #   2F  /  改行出力, 除算演算子
TblComm2:
        .quad Com_Comment  #   3A  :  行末まで注釈
        .quad Com_IF       #   3B  ;  IF
        .quad Com_CdWrite  #   3C  <  rvtlコードのファイル出力
        .quad Com_Top      #   3D  =  コード先頭アドレス
        .quad Com_CdRead   #   3E  >  rvtlコードのファイル入力
        .quad Com_OutNum   #   3F  ?  数値出力  数値入力
        .quad Com_DO       #   40  @  DO UNTIL NEXT
TblComm3:
        .quad Com_RCheck   #   5B  [  Array index 範囲チェック
        .quad Com_Ext      #   5C  \  拡張用  除算演算子(unsigned)
        .quad Com_Return   #   5D  )  RETURN
        .quad Com_Comment  #   5E  ^  ラベル宣言, 排他OR演算子, ラベル参照
        .quad Com_USleep   #   5F  _  usleep, gettimeofday
        .quad Com_RANDOM   #   60  `  擬似乱数を保持 (乱数シード設定)
TblComm4:
        .quad Com_FileTop  #   7B  {  ファイル先頭(ヒープ領域)
        .quad Com_Function #   7C  |  組み込みコマンド, エラーコード保持
        .quad Com_FileEnd  #   7D  }  ファイル末(ヒープ領域)
        .quad Com_Exit     #   7E  ~  VTL終了

.ifndef SMALL_VTL
start_msg:      .ascii   "RVTL64 RISC-V v.4.00 2025-07-28,(C)2025 Jun Mizutani\n"
                .ascii   "RVTL may be copied under the terms of the GNU "
                .asciz   "General Public License.\n"
.endif

initvtl:        .asciz   "/etc/init.vtl"
cginame:        .asciz   "wltvr"
err_div0:       .asciz   "\nDivided by 0!\n"
err_doublequote:.asciz   "\nDoublequote in Exp!\n"
err_unknown:    .asciz   "\nUnknown Error!\n"
err_label:      .asciz   "\nLabel not found!\n"
err_vstack:     .asciz   "\nEmpty stack!\n"
err_space:      .asciz   "\nSpace in Expression at line "
err_exp:        .asciz   "\nError in Expression at line "
envstr:         .asciz   "PATH=/bin:/usr/bin"
prompt1:        .asciz   "\n<"
prompt2:        .asciz   "> "
syntaxerr:      .asciz   "\nSyntax error! at line "
stkunder:       .asciz   "\nStack Underflow!\n"
stkover:        .asciz   "\nStack Overflow!\n"
vstkunder:      .asciz   "\nVariable Stack Underflow!\n"
vstkover:       .asciz   "\nVariable Stack Overflow!\n"
Range_msg:      .asciz   "\nOut of range!\n"
no_direct_mode: .asciz   "\nDirect mode is not allowed!\n"

err_str:        .asciz  "^  ["
equal_err:      .asciz  "\n= required."
EndMark_msg:    .asciz  "\n&=0 required.\n"
error_cdread:   .asciz   "\nCode Read (>=) is not allowed!\n"
Error_msg:      .asciz   "\nError!\n"

.ifndef SMALL_VTL
#-------------------------------------------------------------------------
# 組み込み関数用メッセージ
#-------------------------------------------------------------------------
    msg_f_ca:   .asciz  ""
    msg_f_cd:   .asciz  "Change Directory to "
    msg_f_cm:   .asciz  "Change Permission \n"
    msg_f_cr:   .asciz  "Change Root to "
    msg_f_cw:   .asciz  "Current Working Directory : "
    msg_f_ex:   .asciz  "Exec Command\n"
    msg_f_ls:   .asciz  "List Directory\n"
    msg_f_md:   .asciz  "Make Directory\n"
    msg_f_mv:   .asciz  "Change Name\n"
    msg_f_mo:   .asciz  "Mount\n"
    msg_f_pv:   .asciz  "Pivot Root\n"
    msg_f_rd:   .asciz  "Remove Directory\n"
    msg_f_rm:   .asciz  "Remove File\n"
    msg_f_rt:   .asciz  "Reset Termial\n"
    msg_f_sf:   .asciz  "Swap Off\n"
    msg_f_so:   .asciz  "Swap On\n"
    msg_f_sy:   .asciz  "Sync\n"
    msg_f_um:   .asciz  "Unmount\n"
.endif

#==============================================================
.bss
                .align  3
env:            .quad   0, 0

                .align  2
cgiflag:        .quad   0               # when cgiflag=1, cgi-mode
counter:        .quad   0
save_stack:     .quad   0
current_arg:    .quad   0
argc:           .quad   0
argvp:          .quad   0
envp:           .quad   0               # exarg - #24
argc_vtl:       .quad   0
argp_vtl:       .quad   0
exarg:          .skip   (ARGMAX+1)*8    # execve 用
ipipe:          .long   0               # 0   new_pipe
opipe:          .long   0               # +4
ipipe2:         .long   0               # +8 old_pipe
opipe2:         .long   0               # +12
stat_addr:      .quad   0

                .align  2
input2:         .skip   MAXLINE
FileName:       .skip   FNAMEMAX
pid:            .quad   0               # gp-40
VSTACK:         .quad   0               # gp-32
FileDescW:      .quad   0               # gp-24
FileDesc:       .quad   0               # gp-16
FOR_direct:     .byte   0               # gp-8
ExpError:       .byte   0               # gp-7
ZeroDiv:        .byte   0               # gp-6
SigInt:         .byte   0               # gp-5
ReadFrom:       .byte   0               # gp-4
ExecMode:       .byte   0               # gp-3
EOL:            .byte   0               # gp-2
LSTACK:         .byte   0               # gp-1
VarArea:        .skip   256*8           # gp 後半128dwordはLSTACK用
VarStack:       .skip   VSTACKMAX*8     # gp+2048

.ifdef VTL_LABEL
                .align  2
LabelTable:     .skip   LABELMAX*32     # 1024*32 bytes
TablePointer:   .quad   0
.endif
