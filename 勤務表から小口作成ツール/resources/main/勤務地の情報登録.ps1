#
# 勤務表から勤務地を取得し、その勤務地についての情報を登録する
#

# --------------- アセンブリの読み込み ---------------
Add-Type -Assembly System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --------------- 関数定義 ---------------

# 勤務表を保存せずに閉じて、Excelを中断する関数
function breakExcel {
    # Bookを閉じる
    $kinmuhyouBook.close()
    # 使用していた変数の解放
    $excel = $null
    $kinmuhyouBook = $null
    $kinmuhyouSheet = $null
    # ガベージコレクト
    [GC]::Collect()
    # 処理を終了する
    exit
}

# ---------------- 注意画面スクリプトの呼び出し -------------------
. (Join-Path -path $PWD -childpath "..\scripts\注意画面.ps1")

# 注意画面.ps1の関数を実行する
$attentionForm = attentionThisTool

# フォームの可視化
$attentionResult = $attentionForm.ShowDialog()

if ($attentionResult -eq "Cancel") {
    exit 
}
# ---------------- 注意画面スクリプト終了 -------------------

# 現在の年月日を取得する
$targetYear = (Get-Date).Year
$thisMonth = (Get-Date).Month
$today = (Get-Date).Day

# 現在日時から作成するべき勤務表の月次を判定
# 24日までは当月分を作る
if ($today -le 24) {
    # 前の月を小口作成の対象月とする
    $targetMonth = (Get-date).AddMonths(-1).month
}
else {
    # 今月を小口作成の対象月とする
    $targetMonth = $thisMonth
}

# (現在日によって変わるので、get-date -Format Y にはしていない)
$yesNo_yearMonthAreCorrect = [System.Windows.Forms.MessageBox]::Show("【 $targetYear 年 $targetMonth 月 】の勤務表をもとに勤務地を登録をしますか？`r`n`r`n「いいえ」で他の月を選択できます", '作成する小口の対象年月', 'YesNo', 'Question')

# ☆$yesNo_yearMonthAreCorrect -eq 'No'ループ開始☆
if ($yesNo_yearMonthAreCorrect -eq 'No') {

    # ---------------- 勤務表の月選択スクリプトを呼び出し -------------------
    . (Join-Path -Path $PWD -ChildPath "..\scripts\勤務表の月選択.ps1")

    # 勤務表の月選択.ps1の関数を実行
    # choicedMonth[0] : 勤務表の月選択フォーム
    # choicedMonth[1] : 勤務表の月選択コンボボックス
    $choicedMonth = choiceMonth

    # 勤務表の月選択画面を可視化
    $choiceMonthResult = $choicedMonth[0].ShowDialog()

    if ($choiceMonthResult -eq "OK") {
        # ユーザーの回答を"年"で区切る
        $choicedMonth[1].Text -match "(?<year>.+?)年(?<month>.+?)月" | out-null

        # ユーザー指定の年を小口作成の対象年として上書する
        $targetYear = $Matches.year

        # ユーザー指定の月を小口作成の対象月として上書きする
        $targetMonth = $Matches.month

    }
    else {   
        # 処理を終了する
        exit
    }
}
# ---------------- 勤務表の月選択スクリプト終了 -------------------

# ----------- しばらくお待ちくださいスクリプト呼び出し -----------
. (Join-Path -Path $PWD -ChildPath ..\scripts\しばらくお待ちください.ps1)

# しばらくお待ちください.ps1の関数を実行
$waitCatForm = pleaseWait "..\images\お待ちください猫.png"

# しばらくお待ちくださいフォームの可視化
$waitCatForm.show()

# ---------------- 勤務表チェック処理 -------------------
# ポップアップを作成
$popup = new-object -comobject wscript.shell

# ファイル名の勤務表_のあとの表記
$targetMonth00 = "{0:00}" -f [int]$targetMonth
$fileNameMonth = ("$targetYear" + "$targetMonth00")
# 勤務表ファイルを取得
$kinmuhyou = Get-ChildItem "..\..\01_ダウンロードした勤務表" -Recurse -File | ? Name -Match ("[0-9]{3}_勤務表_" + $fileNameMonth + "_.+") 
# 該当勤務表ファイルの個数確認
if ($kinmuhyou.Count -lt 1) {
    
    # しばらくお待ちください画面を閉じる
    $waitCatForm.Close()

    # ポップアップを表示
    $popup.popup("$targetMonth 月の勤務表ファイルが存在しません", 0, "やり直してください", 48) | Out-Null
    exit
}
elseif ($kinmuhyou.Count -gt 1) {
    
    # しばらくお待ちください画面を閉じる
    $waitCatForm.Close()

    # ポップアップを表示
    $popup.popup("$targetMonth 月の勤務表ファイルが多すぎます`r`n1つにしてください", 0, "やり直してください", 48) | Out-Null
    exit
}
# ---------------- 勤務表チェック処理終了 -------------------

# ----------------------Excelの起動処理--------------------------------

# Excelプロセスが起動してなければ新たに起動する
$excel = New-Object -ComObject "Excel.Application" 

# Excelがメッセージダイアログを表示しないようにする
$excel.DisplayAlerts = $false
$excel.visible = $false

# 勤務表のフルパス
$kinmuhyouFullPath = $kinmuhyou.FullName 

# 勤務表ブックを開く
$kinmuhyouBook = $excel.workbooks.open($kinmuhyouFullPath)
$kinmuhyouSheet = $kinmuhyouBook.worksheets.item([String]$targetMonth + '月')


# ---------------勤務地情報リストを読み込む処理---------------------

# ---------------配列定義---------------------
# 入力内容をまとめて入れておくための配列
$inputContentsArray = @()
# 今回登録する勤務地を格納する配列
$workPlaceArray = @()
# すでに勤務地情報リストに書いてある勤務地を格納する配列
$registeredWorkPlaceArray = @()


# 勤務地情報リストが書いてあるテキスト
$infoTextFileName = "..\user_info\ツール用引数.txt"
$infoTextFileFullpath = "$PWD\$infoTextFileName"

# 勤務地情報リストテキストが存在したときの処理
if (Test-Path $infoTextFileFullpath) {

    # 勤務地情報リストテキストの内容を取得
    $argumentText = (Get-Content $infoTextFileFullpath)
    
    # 勤務地情報リストテキストにすでに書かれている情報を取得する
    for ($i = 0; $i -lt $argumentText.Length; $i++) {
        $argumentText[$i] -Match "(?<workplace>.+?)_" | Out-Null
        # すでに配列に入っている勤務地は追加しない
        if (!$registeredWorkPlaceArray.Contains($Matches.workplace)) {
            # 配列にない勤務地を配列に追加する
            $registeredWorkPlaceArray += $Matches.workplace
        }
    }
}

# 勤務表から勤務地一覧を取得する
# $kinmunaiyou : 勤務内容列セル
# $kinmujisseki : 勤務実績列セル
# $sagyoubasho : 作業場所セル
for ($Row = 14; $Row -le 44; $Row++) {
    # 「勤務内容」欄の文字列を取得
    $kinmunaiyou = $kinmuhyouSheet.cells.item($Row, 26).text
    # 「勤務実績」欄の終了時刻の文字列を取得
    $kinmujisseki = $kinmuhyouSheet.cells.item($Row, 7).text
    # 「作業場所」欄の文字列を取得
    $sagyoubasho = $kinmuhyouSheet.cells.item(7, 7).text

    # 勤務実績が空値でない＝出勤してる日
    if ($kinmujisseki -ne "") {

        # 勤務内容が空値でない＝勤務地などが書いてある
        if ($kinmunaiyou -ne "") {
            # 勤務内容から勤務地を持ってくる
            $workPlace = $kinmunaiyou        
        }
        else {
            # 出勤してるけど勤務内容に勤務地が書いてない場合
            # 作業場所から勤務地を持ってくる
            $workPlace = $sagyoubasho
        }   
    }

    # 今回登録する勤務地にまだ登録されてないかつ、ツール用引数.txtにまだ登録されていない場合は、今回登録する勤務地配列に追加する
    if (!$workPlaceArray.Contains($workPlace) -and !$registeredWorkPlaceArray.Contains($workPlace)) {
        $workPlaceArray += @($workPlace)
    }
}

# 今回登録するものがない場合はpopupを表示して終了
if ($workPlaceArray.Length -eq 0) {
    
    # しばらくお待ちください画面を閉じる
    $waitCatForm.Close()
    
    # ポップアップを表示
    $popup.popup("$targetmonth 月の勤務地はすべて登録されています。", 0, "登録済み", 64) | Out-Null
    breakExcel    
    exit
}

# --------------- Excelの終了処理 ---------------------

# Bookを閉じる
$kinmuhyouBook.close()

# 使用していたプロセスの解放
$excel = $null
# 使用していた変数の解放
$kinmuhyouBook = $null
$kinmuhyouSheet = $null
$outputTekiyou = $null
$outputKukan = $null
$koutsukikan1 = $null
$koutsukikan2 = $null
$koutsukikan3 = $null
$koutsukikan4 = $null
$koutsukikan5 = $null
$koutsukikan6 = $null
$inputKoutsukikan = $null
$koutsukikans = $null
$outputKoutsukikans = $null
$outputKingaku = $null

# ガベージコレクト
[GC]::Collect()

# =========================== 入力画面 ===========================

# ---------------- 変数定義 ----------------

# フォントを指定
$bigFont = New-Object System.Drawing.Font("Yu Gothic UI", 20)

# フォームごとの要素を格納する配列
$forms = @()
# 適用
$outputTekiyous = @()
# 区間
$outputKukans = @()
# 交通機関
$outputKoutsukikans = @()
# 金額
$outputKingakus = @()

# 交通機関
$koutsukikan1 = @()
$koutsukikan2 = @()
$koutsukikan3 = @()
$koutsukikan4 = @()
$koutsukikan5 = @()
$koutsukikan6 = @()

# form上のどのボタンが押されたかがはいる配列
$inputContentsResults = @(1..$workPlaceArray.Length)

# 金額が半角数字でなかった時のエラーメッセージ
$kingakuErrorMessages = @()

# ユーザ入力が空白だった時のエラーメッセージ
$blankErrorMessages = @()


# ---------------- 関数定義 ----------------

# フォームを作成する関数
# Args[0] : タイトルに表示する文字列
function drawForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "勤務地の情報登録"
    $form.Size = New-Object System.Drawing.Size(570, 730)
    $form.StartPosition = "CenterScreen"
    $form.font = $font
    $form.Topmost = $True
    $form.formborderstyle = "FixedSingle"
    $form.icon = (Join-Path -Path $PWD -ChildPath "../images/会社アイコン.ico")
    return $form
}


# ラベルを作成する関数
# Args[0] : フォーム内の設定座標（横の位置）
# Args[1] : フォーム内の設定座標（縦の位置。高さ）
# Args[2] : ラベルを表示する幅
# Args[3] : ラベルを表示する高さ
# Args[4] : ラベルに表示する文字列
# Args[5] : ラベルを表示するフォーム
# Args[6] : ラベルのフォント
function drawLabel {
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point($Args[0], $Args[1])
    $label.Size = New-Object System.Drawing.Size($Args[2], $Args[3])
    $label.Text = $Args[4]
    $label.forecolor = "black"
    $label.font = $Args[6]
    if ($Args[6] -ne $null) {
        $Args[6]
    }
    $Args[5].Controls.Add($label)
    return $label
}

# OK/登録ボタンを作成する関数
# Args[0] : フォーム内の設定座標（横の位置）
# Args[1] : フォーム内の設定座標（縦の位置。高さ）
# Args[2] : ボタンを表示する横幅
# Args[3] : ボタンを表示する縦幅
# Args[4] : OK/登録ボタンに表示する文字列
# Args[5] : OK/登録ボタンを表示するフォーム
# result  : OK
function drawOKButton {
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point($Args[0], $Args[1])
    $OKButton.Size = New-Object System.Drawing.Size($Args[2], $Args[3])
    $OKButton.Text = $Args[4]
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $Args[5].AcceptButton = $OKButton
    $Args[5].Controls.Add($OKButton)
}

# 在宅ボタンを作成する関数
# Args[0] : フォーム内の設定座標（縦の位置。高さ）
# Args[1] : 在宅ボタンに表示する文字列
# Args[2] : 在宅ボタンを表示するフォーム
# result  : Yes
function drawAtHomeButton {
    $local:AtHomeButton = New-Object System.Windows.Forms.Button
    $AtHomeButton.Location = New-Object System.Drawing.Point(160, $Args[0])
    $AtHomeButton.Size = New-Object System.Drawing.Size(180, 30)
    $AtHomeButton.Text = $Args[1]
    $AtHomeButton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $AtHomeButton.Backcolor = "paleturquoise"
    $Args[2].Controls.Add($AtHomeButton)
}

# 戻るボタンを作成する関数
# Args[0] : フォーム内の設定座標（縦の位置。高さ）
# Args[1] : 戻るボタンに表示する文字列
# Args[2] : 戻るボタンを表示するフォーム
# result  : Retry
function drawReturnButton {
    $ReturnButton = New-Object System.Windows.Forms.Button
    $ReturnButton.Location = New-Object System.Drawing.Point(440, $Args[0])
    $ReturnButton.Size = New-Object System.Drawing.Size(90, 30)
    $ReturnButton.Text = $Args[1]
    $ReturnButton.DialogResult = [System.Windows.Forms.DialogResult]::Retry
    # 1番目のフォームではボタンを非活性にする
    if ($i -eq 0) {
        $ReturnButton.Enabled = $false; 
    }
    else {
        $ReturnButton.Enabled = $True;
    }
    $Args[2].Controls.Add($ReturnButton)
}

# 登録済み勤務地から選択ボタンを作成する関数
# result : No
function drawRegisteredButton {
    $registeredButton = New-Object System.Windows.Forms.Button
    $registeredButton.Location = New-Object System.Drawing.Point(350, $Args[0])
    $registeredButton.Size = New-Object System.Drawing.Size(180, 30)
    $registeredButton.Text = $Args[1]
    $registeredButton.DialogResult = [System.Windows.Forms.DialogResult]::No
    # ツール用引数.txt が存在していない or 中身が空の時はボタンを非活性にする
    if (!(Test-Path $infoTextFileFullpath) -or ($argumentText.Length -eq 0)) {
        $registeredButton.Enabled = $false; 
    }else {
        $registeredButton.Enabled = $True;
    }
    $Args[2].Controls.Add($registeredButton)
}

# テキストボックスを作成する関数
# Args[0] : フォーム内の設定座標（横の位置）
# Args[1] : フォーム内の設定座標（縦の位置。高さ）
# Args[2] : テキストボックスの横幅
# Args[3] : テキストボックスの高さ
# Args[4] : テキストボックスを表示するフォーム
function drawTextBox {
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point($Args[0], $Args[1])
    $textBox.Size = New-Object System.Drawing.Size($Args[2], $Args[3])
    $textBox.BackColor = "white"
    $Args[4].Controls.Add($textBox)
    return $textBox
}

# しばらくお待ちください画面を閉じる
$waitCatForm.Close()

# ---------------- 主処理 ----------------

# =============================== input ===============================
# ユーザの入力フォームを作成する処理
# $workPlaceArray : 今回登録する勤務地を格納する配列
for ($local:i = 0; $i -lt $workPlaceArray.Length; $i++) {

    # 勤務地の数だけformを作成する
    $forms += drawForm $workPlaceArray[$i]

    # 勤務地表示
    drawLabel 15 5 550 40 ("『" + $workPlaceArray[$i] + "』の情報を教えてください") $forms[$i] $bigFont | Out-Null

    # 登録ボタン作成関数呼び出し
    drawOKButton 20 605 130 30 "登 録" $forms[$i]

    # 戻るボタン作成関数呼び出し
    drawReturnButton 650 "戻る" $forms[$i]

    # 在宅ボタン作成関数呼び出し
    drawAtHomeButton 605 "在宅勤務 / 定期" $forms[$i]

    # 登録済み勤務地から選択ボタン作成関数呼び出し
    drawRegisteredButton 605 "登録済みの勤務地から選択" $forms[$i]


    # ---------------- 適用（行先、要件） ----------------- 
    # 適用ラベルのフォーム内の設定座標の高さ
    $tekiyouLabelLocate = 72
    # 適用テキストボックスのフォーム内の設定座標の高さ
    $tekiyouTextBoxLocate = 132

    # ラベル関数呼び出し
    drawLabel 10 $tekiyouLabelLocate 470 15 ("１．【 適用 】 適用 (行先、要件) を入力してください") $forms[$i] | Out-Null
    drawLabel 30 ($tekiyouLabelLocate + 20) 470 15 "ex.  自宅←→田町本社" $forms[$i] | Out-Null
    drawLabel 30 ($tekiyouLabelLocate + 40) 470 15 "      通常勤務(品川)" $forms[$i] | Out-Null

    # テキストボックス関数呼び出し
    $outputTekiyou = drawTextBox 30 $tekiyouTextBoxLocate 300 20  $forms[$i]

    # 適用テキストボックスを配列に追加
    $outputTekiyous += $outputTekiyou

    # ---------------- 区間 ----------------- 
    # 区間ラベルのフォーム内の設定座標の高さ
    $kukanLabelLocate = 172
    # 区間テキストボックスのフォーム内の設定座標の高さ
    $kukanTextBoxLocate = 232

    # ラベル関数呼び出し
    drawLabel 10 $kukanLabelLocate 550 15 ("２．【 区間 】 区間（自宅の最寄り駅←→勤務地の最寄り駅）を入力してください") $forms[$i] | Out-Null
    drawLabel 30 ($kukanLabelLocate + 20) 470 15 "ex.  <自宅の最寄り駅>←→田町 (往復の場合)" $forms[$i] | Out-Null
    drawLabel 30 ($kukanLabelLocate + 40) 670 15 "      <自宅の最寄り駅>→品川→東京テレポート→<自宅の最寄り駅> (勤務地複数の場合)" $forms[$i] | Out-Null

    # テキストボックス関数呼び出し
    $outputKukan = drawTextBox 30 $kukanTextBoxLocate 430 20 $forms[$i]

    # 区間テキストボックスを配列に追加
    $outputKukans += $outputKukan

    # ---------------- 交通機関 -----------------
    # 交通機関ラベルのフォーム内の設定座標の高さ
    $koutsukikanLabelLocate = 317
    # 交通機関テキストボックスのフォーム内の設定座標の高さ
    $koutsukikanTextBoxLocate = 315

    # ラベル関数呼び出し
    drawLabel 10 272 500 15 ("３．【 交通機関 】 利用する交通機関を入力してください") $forms[$i] | Out-Null
    drawLabel 30 292 500 15 "ex. JR山手線" $forms[$i] | Out-Null
    drawLabel 30 $koutsukikanLabelLocate 80 15 "交通機関１：" $forms[$i] | Out-Null
    drawLabel 30 ($koutsukikanLabelLocate + 35) 80 15 "交通機関２：" $forms[$i] | Out-Null
    drawLabel 30 ($koutsukikanLabelLocate + 70) 80 15 "交通機関３：" $forms[$i] | Out-Null
    drawLabel 30 ($koutsukikanLabelLocate + 105) 80 15 "交通機関４：" $forms[$i] | Out-Null
    drawLabel 30 ($koutsukikanLabelLocate + 140) 80 15 "交通機関５：" $forms[$i] | Out-Null
    drawLabel 30 ($koutsukikanLabelLocate + 175) 80 15 "交通機関６：" $forms[$i] | Out-Null

    # テキストボックス関数呼び出し
    $koutsukikan1 = drawTextBox 110 $koutsukikanTextBoxLocate 200 20 $forms[$i]
    $koutsukikan2 = drawTextBox 110 ($koutsukikanTextBoxLocate + 35) 200 20 $forms[$i]
    $koutsukikan3 = drawTextBox 110 ($koutsukikanTextBoxLocate + 70) 200 20 $forms[$i]
    $koutsukikan4 = drawTextBox 110 ($koutsukikanTextBoxLocate + 105) 200 20 $forms[$i]
    $koutsukikan5 = drawTextBox 110 ($koutsukikanTextBoxLocate + 140) 200 20 $forms[$i]
    $koutsukikan6 = drawTextBox 110 ($koutsukikanTextBoxLocate + 175) 200 20 $forms[$i]

    # 後の処理で使いやすくするため、各交通機関を配列に格納する
    $inputkoutsukikan = @($koutsukikan1, $koutsukikan2, $koutsukikan3, $koutsukikan4, $koutsukikan5, $koutsukikan6)
    $outputKoutsukikans += , @($inputkoutsukikan)

    # ---------------- 金額 -----------------
    # 金額ラベルのフォーム内の設定座標の高さ
    $kingakuLabelLocate = 532
    # 金額テキストボックスのフォーム内の設定座標の高さ
    $kingakuTextBoxLocate = 572

    # ラベル関数呼び出し
    drawLabel 10 $kingakuLabelLocate 500 15 ("４．【 金額 】 交通費（往復代金）を入力してください") $forms[$i] | Out-Null
    drawLabel 30 ($kingakuLabelLocate + 20) 470 15 "ex.  750 （半角数字）" $forms[$i] | Out-Null

    # テキストボックス関数呼び出し
    $outputKingaku = drawTextBox 30 $kingakuTextBoxLocate 100 20 $forms[$i]

    # 金額テキストボックスを配列に追加
    $outputKingakus += $outputKingaku

    
    # ----------------- エラーメッセージ定義 -----------------
    # 金額が半角数字だった場合に表示されるエラーメッセージ
    $kingakuErrorMessage = drawLabel 130 $kingakuTextBoxLocate 270 15 " " $forms[$i]
    $kingakuErrorMessage.foreColor = "red"
    
    # 金額が半角数字ではなかった場合のエラーメッセージを配列に追加
    $kingakuErrorMessages += $kingakuErrorMessage
    
    # 空白だった場合に表示されるエラーメッセージ
    $blankErrorMessage = drawLabel 15 47 270 15 " " $forms[$i]
    $blankErrorMessage.foreColor = "red"
    
    # 項目が１つでも空白だった場合のエラーメッセージを配列に追加
    $blankErrorMessages += $blankErrorMessage
    
}

# =============================== output ===============================
# user_info\ツール用引数.txtにユーザの入力内容を記載する処理
:EMPTY for ($local:i = 0; $i -lt $workPlaceArray.Length; $i++) {
    
    # 可視化
    $inputContentsResults[$i] = $forms[$i].ShowDialog()

    # --------------- OKボタンを押したら ---------------
    if ($inputContentsResults[$i] -eq "OK") {

        #  ---------------- 空白エラー判定 -----------------

        # 以下の変数をリセットする
        #
        # nullOrEmptyCount  : 交通機関テキストボックスの空の個数
        # koutsukikans      : 複数の交通機関テキストボックスを一つにまとめるための変数
        # outputKoutsukikan : 編集したkoutsukikansを代入する
        # isEmpty           : 空白エラーを起こすためのフラグ
        #
        $nullOrEmptyCount = 0
        $koutsukikans = ""
        $outputKoutsukikan = ""
        $isEmpty = $false

        # テキストボックスの色を白に戻す
        $outputTekiyous[$i].BackColor = "white"
        $outputKukans[$i].BackColor = "white"
        $outputKingakus[$i].BackColor = "white"
        $outputKoutsukikans[$i][0].BackColor = "white"

        for ($l = 0; $l -lt $outputKoutsukikans[$i].length; $l++) {
            # 交通機関テキストボックスから空ではないものを抜き出す
            if ([string]::IsNullOrEmpty($outputKoutsukikans[$i][$l].text)) {
                # NULL や '' の場合
                $nullOrEmptyCount++
            }
            else {
                # 上記以外は設定された文字列を出力
                $koutsukikans += ($outputKoutsukikans[$i][$l].text + '`r`n')
            }
        }

        # 想定内のエラーを一時的にエラー出力させない
        $ErrorActionPreference = "silentlycontinue"
        
        # 末尾の「`r`n」を消す
        $outputKoutsukikan += $koutsukikans.Substring(0, $koutsukikans.Length - 4)

        # エラー出力を戻す
        $ErrorActionPreference = "continue"

        while ($True) {
            # 交通機関が全て空だった場合の処理
            if ($nullOrEmptyCount -eq 6) {
                $outputKoutsukikans[$i][0].BackColor = "#ff99cc"
                $isEmpty = $True
            }
    
            # ユーザ入力に空白があった場合の処理
            $inputtedTextBoxes = @($outputTekiyous[$i], $outputKukans[$i], $outputKingakus[$i])

            # ユーザ入力に１つでも空白があった場合の処理
            foreach ($inputtedTextBox in $inputtedTextBoxes) {
                if ($inputtedTextBox.text -eq "") {
                    $inputtedTextBox.BackColor = "#ff99cc"
                    $checkBlank = 0
                    if (![int]::TryParse($inputtedTextBox.text, [ref]$checkBlank)) {
                        $blankErrorMessages[$i].text = "※未記入の項目があります"
                    }
                    $isEmpty = $True
                }    
            }

            # 金額が数字ではなかった時の処理
            $checkKingaku = 0
            if (![int]::TryParse($outputKingakus[$i].text, [ref]$checkKingaku)) {
                $outputKingakus[$i].BackColor = "#ff99cc"
                $kingakuErrorMessages[$i].text = "※半角数字で記入してください"
                $isEmpty = $True
            }

            # 空白があった場合これ以降の処理をスキップする
            if ($isEmpty) {
                # 交通機関の空白カウントを初期化
                $nullOrEmptyCount = 0
                $i = $i - 1
                continue EMPTY
            }
            $kingakuErrorMessages[$i].text = "　"
            $blankErrorMessages[$i].text = "　"
            
            # エラーがない場合はループから抜ける
            break
        }
        

        # ---------------- 適用（行先、要件） -----------------

        $inputContentsArray += @($workPlaceArray[$i] + "_" + $outputTekiyous[$i].text)

        # ---------------- 区間 -----------------

        $inputContentsArray += @($workPlaceArray[$i] + "_" + $outputKukans[$i].text)

        # ---------------- 交通機関 -----------------

        $inputContentsArray += @($workPlaceArray[$i] + "_" + $outputKoutsukikan)

        # ---------------- 金額 -----------------

        $inputContentsArray += @($workPlaceArray[$i] + "_" + $outputKingakus[$i].text)

        # --------------- 戻るボタンを押したら ---------------
    }
    elseif ($inputContentsResults[$i] -eq "Retry") {
        
        # 繰り返しの条件を2戻す
        # 例えば、1画面目が田町（$i = 1）2画面目がお台場（$i = 2）だったとき、田町の画面に戻りたいときは $i = 1 にしたい
        # for文の条件式？でインクリメントされているため、$iから2を引く必要がある
        $i = $i - 2
        # 配列になにも入っていない時（固定配列なので、最初の要素は空にするだけにした）
        if ($inputContentsArray.Length -le 4) {
            for ($j = 1; $j -lt 5; $j++) {
                $inputContentsArray[($inputContentsArray.Length - $j)] = ""
            }
            # 戻るボタンを押したら、テキストファイルに出力する要素を削除する    
        }
        else {
            $inputContentsArray = $inputContentsArray[0..($inputContentsArray.Length - 5)]
        }
        
        # --------------- 在宅/定期ボタンを押したら ---------------
    }
    elseif ($inputContentsResults[$i] -eq "Yes") {
        $inputContentsArray += @($workPlaceArray[$i] + "_1")
        $inputContentsArray += @($workPlaceArray[$i] + "_1")
        $inputContentsArray += @($workPlaceArray[$i] + "_1")
        $inputContentsArray += @($workPlaceArray[$i] + "_1")

    }
    # 登録済み勤務地から選択する場合
    elseif ($inputContentsResults[$i] -eq "No") {
        # 登録済み勤務地選択用フォームを作成
        $selectForm = New-Object System.Windows.Forms.Form
        $selectForm.Text = "登録済みの勤務地から選択"
        $selectForm.Size = New-Object System.Drawing.Size(300, 200)
        $selectForm.StartPosition = "CenterScreen"

        # ラベル作成関数呼び出し
        drawLabel 10 10 550 15 ("【 " + $workPlaceArray[$i] + " 】と同じ勤務地を") $selectForm | Out-Null
        drawLabel 10 27 550 15 ("登録済みの勤務地から選択してください") $selectForm | Out-Null


        # OKボタン作成関数呼び出し
        # Args[0] : フォーム内の設定座標（縦の位置。高さ）
        # Args[1] : OKボタンに表示する文字列
        # Args[2] : OKボタンを表示するフォーム
        # result : OK
        drawOKButton 20 100 75 30 "OK" $selectForm

        # キャンセルボタンの設定
        $CancelButton = New-Object System.Windows.Forms.Button
        $CancelButton.Location = New-Object System.Drawing.Point(130, 100)
        $CancelButton.Size = New-Object System.Drawing.Size(85, 30)
        $CancelButton.Text = "フォームに戻る"
        $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $selectForm.CancelButton = $CancelButton
        $selectForm.Controls.Add($CancelButton)
        
        # コンボボックスを作成
        $Combo = New-Object System.Windows.Forms.Combobox
        $Combo.Location = New-Object System.Drawing.Point(50, 50)
        $Combo.size = New-Object System.Drawing.Size(150, 30)
        # リスト以外の入力を許可しない
        $Combo.DropDownStyle = "DropDownList"
        $Combo.FlatStyle = "standard"
        $Combo.BackColor = "#005050"
        $Combo.ForeColor = "white"
            
        # コンボボックスに項目を追加
        # すでに ツール用引数.txt に記載されている勤務地をコンボボックスの項目に追加
        # for($counterForMove = (-6); $counterForMove -le 6; $counterForMove++){
        foreach ($registeredWorkPlace in $registeredWorkPlaceArray) {
            [void] $Combo.Items.Add($registeredWorkPlace)
        }
        
        # コンボボックスの初期値を配列の一番最初にしておく
        $Combo.SelectedIndex = 0

        # フォームにコンボボックスを追加
        $selectForm.Controls.Add($Combo)
        
        # 可視化
        $selectResult = $selectForm.ShowDialog()

        # 選択後、OKボタンが押された場合
        if ($selectResult -eq "OK") {
            $selectForm.Visible = $false
            $selectForm.Close()

            # ユーザーが選択した勤務地の情報を、リストから取得 ( 配列の中身　[0]:適用　[1]:区間　[2]:交通機関　[3]:金額 )
            $workPlaceInfo = $argumentText | Select-String -Pattern ($Combo.text + '_')

            # 「選択された勤務地の文字数 + _ 」の総文字数
            $trimWordCount = $Combo.text.Length + 1

            # 適用（行先、要件）
            $inputContentsArray += @($workPlaceArray[$i] + "_" + ([String]$workPlaceInfo[0]).Substring($trimWordCount, ([String]$workPlaceInfo[0]).Length - $trimWordCount))
            # 区間
            $inputContentsArray += @($workPlaceArray[$i] + "_" + ([String]$workPlaceInfo[1]).Substring($trimWordCount, ([String]$workPlaceInfo[1]).Length - $trimWordCount))
            # 交通機関
            $inputContentsArray += @($workPlaceArray[$i] + "_" + ([String]$workPlaceInfo[2]).Substring($trimWordCount, ([String]$workPlaceInfo[2]).Length - $trimWordCount))
            # 金額
            $inputContentsArray += @($workPlaceArray[$i] + "_" + ([String]$workPlaceInfo[3]).Substring($trimWordCount, ([String]$workPlaceInfo[3]).Length - $trimWordCount))
        
        }
        else {
            # OKボタン以外が押された場合
            # 繰り返しの条件を1戻す
            # 例えば、選択ボタンを押したときの画面が田町（$i = 1）だったとき、$i = 1 の画面を表示したい
            # for文の条件式？でインクリメントされているため、$iから1を引く必要がある
            $i = $i - 1
        }
    
    }
    else {
        exit
    }    
}
# 配列をテキストに出力する
foreach ($inputContent in $inputContentsArray) {
    $inputContent >> ..\user_info\ツール用引数.txt
}

# 勤務地の登録完了画面
$popup.popup("勤務地の登録が完了しました`r`n小口請求書の作成を行ってください", 0, "勤務地の登録が完了しました", 64)| Out-Null

# 小口を作成するバッチファイルがあるフォルダを開く
$createKoguchiFilePath = join-path -Path $PWD -ChildPath ..\..\
Start-Process $createKoguchiFilePath

# 変数の解放
$outputTekiyou = $null
$outputKukan = $null
$koutsukikan1 = $null
$koutsukikan2 = $null
$koutsukikan3 = $null
$koutsukikan4 = $null
$koutsukikan5 = $null
$koutsukikan6 = $null
$inputKoutsukikan = $null
$koutsukikans = $null
$outputKoutsukikans = $null
$outputKingaku = $null