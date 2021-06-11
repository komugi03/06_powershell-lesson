# 
# 勤務表をもとに小口交通費請求書を作成するPowershell
# 
# 勤務表のファイル名：<3桁の社員番号>_勤務表_m月_<氏名>.xlsx
# 

# ---------------アセンブリの読み込み---------------
Add-Type -Assembly System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# # INPUTのために必要?
# [void][System.Reflection.Assembly]::Load("Microsoft.VisualBasic, Version=8.0.0.0, Culture=Neutral, PublicKeyToken=b03f5f7f11d50a3a")


# ----------------- 関数定義 ---------------------

# 勤務表と小口を保存せずに閉じて、Excelを中断する関数
function breakExcel {
    # Bookを閉じる
    $kinmuhyouBook.close()
    $koguchiBook.close()
    # 使用していたプロセスの解放
    # ↓ もし他の用事でExcelを開いていたら、$nullにするとそれまで閉じてしまうためコメントアウト
    # $excel = $null
    $kinmuhyouBook = $null
    $kinmuhyouSheet = $null
    $koguchiBook = $null
    $koguchiSheet = $null
    $koguchiCell = $null
    # ガベージコレクト
    [GC]::Collect()
    # 処理を終了する
    exit
}

# # シャープを使ったメッセージの表示をする関数
# # 最大文字数を基準にシャープの長さを決定する
# # 引数1 : 文字色
# # 引数2以降 : メッセージ
# function displayMessagesSurroundedBySharp {
#     # 変数の初期化
#     $maxLengths = 0
#     for ($i = 1; $i -lt $Args.length; $i++) {
#         # メッセージの中で一番長い文字数を取得する
#         if ( $maxLengths -lt $Args[$i].length) {
#             $maxLengths = $Args[$i].length
#         }
#     }
#     # メッセージの表示
#     Write-Host ("`r`n" + '#' * ($maxLengths * 2 + 6) + "`r`n") -ForegroundColor $Args[0]
#     for ($i = 1; $i -lt $Args.length; $i++) {
#         Write-Host ('　　' + $Args[$i] + "　　`r`n") -ForegroundColor $Args[0]
#     }
#     Write-Host ('#' * ($maxLengths * 2 + 6) + "`r`n") -ForegroundColor $Args[0]
# }

# # 引数の空白を除きファイル名として使えない文字を消す関数
# # fileName : ファイル名
# function removeInvalidFileNameChars ($fileName) {
#     $fileNameRemovedSpace = $fileName -replace "　", ""　-replace " ", ""
#     $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
#     $regex = "[{0}]" -f [RegEx]::Escape($invalidChars)
#     return $fileNameRemovedSpace -replace $regex
# }

# フォーム全体の設定をする関数
# formText : フォームの本文（文字列）
# formYoko : フォームの横幅
# formTate : フォームの縦幅
function makeForm ($formText, $formYoko, $formTate) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $formText
    $form.Size = New-Object System.Drawing.Size($formYoko,$formTate)
    $form.StartPosition = "CenterScreen"
    $form.font = $Font
}

# ラベルを表示する関数
# $labelText : ラベルに書き込む文字列
# $form : フォームオブジェクト
function makeLabel ($labelText, $form) {
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,10)
    $label.Size = New-Object System.Drawing.Size(270,30)
    $label.Text = $labelText
    $form.Controls.Add($label)
    return $form
}

# -------------------- 主処理の準備 --------------------------

##### 注意書きを表示。問題ない場合にはEnterを押させる。#####

# 現在の年月日を取得する
$thisYear = (Get-Date).Year
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
$yesNo_yearMonthAreCorrect = [System.Windows.Forms.MessageBox]::Show("作成するのは 【 $thisYear 年 $targetMonth 月 】の小口でよろしいですか？`r`n`r`n「いいえ」で他の月を選択できます",'作成する小口の対象年月','YesNo','Question')

# 今年を小口作成の対象年とする
$targetYear = $thisYear

# ☆$yesNo_yearMonthAreCorrect -eq 'No'ループ開始☆
if($yesNo_yearMonthAreCorrect -eq 'No'){
    
    # フォントの指定
    $Font = New-Object System.Drawing.Font("メイリオ",8)

    # フォーム全体の設定
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "作成する小口の対象年月"
    $form.Size = New-Object System.Drawing.Size(265,200)
    $form.StartPosition = "CenterScreen"
    $form.font = $Font

    # ラベルを表示
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,10)
    $label.Size = New-Object System.Drawing.Size(270,30)
    $label.Text = "作成したい小口の年月を選択してください"
    $form.Controls.Add($label)

    # OKボタンの設定
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(40,100)
    $OKButton.Size = New-Object System.Drawing.Size(75,30)
    $OKButton.Text = "OK"
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    # キャンセルボタンの設定
    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(130,100)

    $CancelButton.Size = New-Object System.Drawing.Size(75,30)
    $CancelButton.Text = "Cancel"
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    # コンボボックスを作成
    $Combo = New-Object System.Windows.Forms.Combobox
    $Combo.Location = New-Object System.Drawing.Point(50,50)
    $Combo.size = New-Object System.Drawing.Size(150,30)
    # リスト以外の入力を許可しない
    $Combo.DropDownStyle = "DropDownList"
    $Combo.FlatStyle = "standard"
    # $Combo.font = $Font
    $Combo.BackColor = "#005050"
    $Combo.ForeColor = "white"
        
    # -----------コンボボックスに項目を追加-----------
    for($counterForMove = (-6); $counterForMove -le 6; $counterForMove++){
        $date = get-date (get-date).AddMonths($counterForMove) -Format Y
        [void] $Combo.Items.Add("$date")
    }
    
    # フォームにコンボボックスを追加
    $form.Controls.Add($Combo)
    $Combo.SelectedIndex = 6
    
    # フォームを最前面に表示
    $form.Topmost = $True
    
    # フォームを表示＋選択結果を変数に格納
    $result = $form.ShowDialog()

    # 選択後、OKボタンが押された場合、選択項目を表示
    if ($result -eq "OK"){
        # ユーザーの回答を"年"で区切る
        $Combo.Text -match "(?<year>.+?)年(?<month>.+?)月" | out-null

        # ユーザー指定の年を小口作成の対象年として上書する
        $targetYear = $Matches.year

        # ユーザー指定の月を小口作成の対象月として上書きする
        $targetMonth = $Matches.month

    }else{
        # 処理を終了する
        exit
    }

# ☆$yesNo_yearMonthAreCorrect -eq 'No'ループ終了☆
}

echo "$targetYear 年の"
echo "$targetMonth 月の小口を作成します"

# ポップアップを作成
$popup = new-object -comobject wscript.shell

# -------（場所迷い中）---------------小口テンプレを取得------------------------
$koguchiTemplate = Get-ChildItem -Recurse -File | ? Name -Match "小口交通費・出張旅費精算明細書_テンプレ.xlsx"
# 小口テンプレの個数確認
if ($koguchiTemplate.Count -lt 1) {
    # ポップアップを表示
    $popup.popup("小口ファイルのテンプレートが存在しません`r`nダウンロードし直してください",0,"やり直してください",48) | Out-Null    
    exit
}
elseif ($koguchiTemplate.Count -gt 1) {
    # ポップアップを表示
    $popup.popup("小口ファイルのテンプレートが多すぎます`r`n1つにしてください",0,"やり直してください",48) | Out-Null
    exit
}

# 作成した小口を格納するフォルダに、テンプレートをコピーする

# 小口格納フォルダが存在していない場合は作成する
if(!(Test-Path $PWD"\作成した小口交通費請求書")){
    New-Item -Path $PWD"\作成した小口交通費請求書" -ItemType Directory | Out-Null
}

$koguchi = Join-Path $PWD "作成した小口交通費請求書" | Join-Path -ChildPath "小口交通費・出張旅費精算明細書_コピー.xlsx"
Copy-Item -path $koguchiTemplate.FullName -Destination $koguchi

# ------（ユーザー指定の月が必要だから、コンボボックスより後）----------テンプレートから小口交通費請求書を作成する---------------------

# ファイル名の勤務表_のあとの表記
$fileNameMonth = "$targetMonth 月"

# もし「勤務表_202104」のような表記にするなら ↑ をコメントアウトして ↓ のコメントアウトをぬく
# $targetMonth00 = "{0:00}" -f [int]$targetMonth
# $fileNameMonth = ($targetYear + $targetMonth00)

# 勤務表ファイルを取得
$kinmuhyou = Get-ChildItem -Recurse -File | ? Name -Match "[0-9]{3}_勤務表_$fileNameMonth_.+"

# 該当勤務表ファイルの個数確認
if ($kinmuhyou.Count -lt 1) {
    
    # ポップアップを表示
    $popup.popup("$targetMonth 月の勤務表ファイルが存在しません",0,"やり直してください",48) | Out-Null
    # 小口のテンプレのコピーを削除する
    Remove-Item -Path $koguchi
    exit
}
elseif ($kinmuhyou.Count -gt 1) {
    # ポップアップを表示
    $popup.popup("$targetMonth 月の勤務表ファイルが多すぎます`r`n1つにしてください",0,"やり直してください",48) | Out-Null
    # 小口のテンプレのコピーを削除する
    Remove-Item -Path $koguchi
    exit
}


# 処理中のダイアログを表示させる（バーとかでるといいね）

# displaySharpMessage "White" ([string]$targetMonth + " 月の小口交通費請求書を作成します") "しばらくお待ちください。"

# ----------------------Excelを起動する--------------------------------
try {
    # 起動中のExcelプロセスを取得
    $excel = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Excel.Application")
}
catch {
    $excel = New-Object -ComObject "Excel.Application" 
}

# Excelがメッセージダイアログを表示しないようにする
$excel.DisplayAlerts = $false
$excel.visible = $true

# 勤務表のフルパス
$kinmuhyouFullPath = $kinmuhyou.FullName 

# 勤務表ブックを開く
$kinmuhyouBook = $excel.workbooks.open($kinmuhyouFullPath)
write-host ([String]$targetMonth + '月')
$kinmuhyouSheet = $kinmuhyouBook.worksheets.item([String]$targetMonth + '月')
echo "($kinmuhyouSheet).name シート"

# 小口ブックを開く
$koguchiBook = $excel.workbooks.open($koguchi)
$koguchiSheet = $koguchiBook.sheets(1)

echo "book開けてるよ"


# ------------- 勤務表の中身を小口にコピーする ----------------
# 「勤務内容」欄に書かれている勤務地を参考にして、勤務地情報リストファイルから該当情報を小口に記入する

# 小口の行カウンター
$koguchiRowCounter = 11

# 勤務表の1日〜月末まで1行ずつ繰り返す
for ($row = 14; $row -le 44; $row++) {
    # 勤務地判定のために「勤務内容」欄の文字列を取得
    $workPlace = $kinmuhyouSheet.cells.item($row, 26).formula
    Write-Host ("勤務地：" + $workPlace)
    
    # 在宅か休みの時以外の場合、小口に記入
    if ($workPlace -ne "" -and $workPlace -ne '在宅') {
        
        # ------------- 変数定義 ---------------
        # 適用(開始位置)
        $tekiyou = 6
        # 区間(開始位置)
        $kukan = 18
        # 交通機関(開始位置)
        $koutsukikan = 26
        # 金額(開始位置)
        $kingaku = 30
        
        # ---------------勤務地情報リストを読み込む---------------------
        # 勤務地情報リストが書いてあるテキスト
        $infoTextFileName = "ツール用引数.txt"
        $infoTextFileFullpath = "$PWD\$infoTextFileName"
        
        # 勤務地情報リストテキストが存在したときの処理
        if(Test-Path $infoTextFileFullpath){
            
            $argumentText = (Get-Content $infoTextFileFullpath)
            
            # 「勤務内容」欄の文字列にマッチした勤務地の情報を、リストから取得 ( 配列の中身　[0]:適用　[1]:区間　[2]:交通機関　[3]:金額 )
            $workPlaceInfo = $argumentText | Select-String -Pattern ($workPlace + '_')
            Write-Host ("勤務地list：" + $workPlaceInfo)
            
            # 「勤務内容」欄の内容が勤務の情報リストになかった場合、ポップアップを表示し終了する
            if($workPlaceInfo -eq $null){
                # ポップアップを表示
                $popup.popup("勤務地の情報が登録されていない`r`n初期設定もしくは上書きし、やり直してください or ボタンを押して設定してね",0,"やり直してください",48) | Out-Null
                
                # 処理を中断し、終了
                breakExcel
                exit
                
            }
            
            # 在宅フラグ(適用部分に1)が立っている場合、小口には記入しない
            elseif(([String]$workPlaceInfo[0]) -eq '1'){
                # 小口に記入しない
            }
            
            # 上記以外の場合、小口に書き込む
            else{
                # 空白なら記入、埋まってたら下の段に移動する
                if($koguchiSheet.Cells.item($koguchiRowCounter,2).text -eq ""){
                    
                    # 「月」に記入
                    # B11、14、17...にユーザーが入力した対象月を入れる
                    $koguchiSheet.cells.item($koguchiRowCounter, 2) = $targetMonth
                    
                    # 「日」に記入
                    # 勤務表のC列をコピペ
                    $koguchiSheet.cells.item($koguchiRowCounter, 4) = $kinmuhyouSheet.cells.item($row, 3).text
                    
                    # 「適用（行先、要件）」に記入
                    $tekiyouText = ([String]$workPlaceInfo[0]).Substring(4, ([String]$workPlaceInfo[0]).Length - 4)
                    $koguchiSheet.Cells.item($koguchiRowCounter,6) = $tekiyouText

                    # 「区間」に記入
                    $kukanText = ([String]$workPlaceInfo[1]).Substring(4, ([String]$workPlaceInfo[1]).Length - 4)
                    $koguchiSheet.Cells.item($koguchiRowCounter,18) = $kukanText

                    # 「交通機関」に記入
                    # ☆交通機関の改行がうまく入力されない！☆
                    $koutsukikanText = "([String]$workPlaceInfo[2]).Substring(4, ([String]$workPlaceInfo[2]).Length - 4)"
                    $koguchiSheet.Cells.item($koguchiRowCounter,26) = $koutsukikanText
                    
                    # 4行以上なら交通機関の行幅を増やす(5行目までなら読める高さ)
                    if($koguchiSheet.Cells.item($koguchiRowCounter,26).text -match "^.+\n.+\n.+\n.+"){
                        $koguchiSheet.Range("Z$koguchiRowCounter").RowHeight = 40
                    }

                    # 「金額」に記入
                    $kingakuText = ([String]$workPlaceInfo[3]).Substring(4, ([String]$workPlaceInfo[3]).Length - 4)
                    $koguchiSheet.Cells.item($koguchiRowCounter,30) = $kingakuText

                }

                # 小口の行カウンターに3を追加し、次の行にする
                $koguchiRowCounter = $koguchiRowCounter + 3

            }
            
        # 勤務地情報リストテキストが存在したときの処理終了
        }else{
            # ポップアップを表示
            $popup.popup("勤務地の情報リストが見つかりません`r`nやり直してください",0,"やり直してください",48) | Out-Null
        }
        
        # 「勤務内容」欄が空欄or在宅の処理終了
    }

}

# ------------- 個人情報欄のコピー --------------
# 1. 年月日のコピー
$koguchiSheet.cells.item(78, 4) = $thisYear
$koguchiSheet.cells.item(78, 8) = $month

# 月の最終日を日付欄に設定
$koguchiSheet.cells.item(78, 11) = (Get-Date "$thisYear/$month/1").AddMonths(1).AddDays(-1).Day

# 2. 名前のコピー
$koguchiSheet.cells.item(82, 21) = $kinmuhyouSheet.cells.range("W7").text
# 勤務表の名前が空白だった場合処理を中断する
if ($koguchiSheet.cells.item(82, 21).text -eq "") {
    Write-Host ("`r`n" + $month + "月の勤務表に名前が記載されていません`r`n処理を中断します`r`n") -ForegroundColor Red
    endExcel
}

# 3. 所属のコピー
$affiliation = $kinmuhyouSheet.cells.range("W6").text
# "部" を削除する
$affiliation -match "(?<affliationName>.+?)部" | Out-Null
$koguchiSheet.cells.item(80, 6) = $Matches.affliationName
# 勤務表の所属が空白だった場合処理を中断する
if ($koguchiSheet.cells.item(80, 6).text -eq "") {
    Write-Host ("`r`n" + $month + "月の勤務表に所属が記載されていません`r`n処理を中断します`r`n") -ForegroundColor Red
    endExcel
}
# 4. 印鑑のコピー
# 印鑑がないかもしれないフラグ
$haveNotStamp = $false
# 勤務表の印鑑のあるセルをクリップボードにコピー
$kinmuhyouSheet.range("AA7").copy() | Out-Null
# 小口シートに印鑑をペースト
$koguchiCell = $koguchiSheet.range("AD82")
$koguchiSheet.paste($koguchiCell)
# ペースト先を編集
$koguchiSheet.range("AD82").formula = ""
$koguchiSheet.range("AD82").interior.colorindex = 0
# 罫線を編集するための宣言
$LineStyle = "microsoft.office.interop.excel.xlLineStyle" -as [type]
# 罫線をなしにする
$koguchiSheet.range("AD82").borders.linestyle = $linestyle::xllinestylenone
# 印鑑（オブジェクト）が増えてなさそうなら、メッセージを表示する
$numberOfObject = 79
if ($koguchiSheet.shapes.count -eq $numberOfObject) {
    $haveNotStamp = $true
}

# 印鑑がないかもしれない場合注意喚起
if ($haveNotStamp) {

    displaySharpMessage "Blue" "印鑑が勤務表に入っていない、または既定のセルからずれている可能性があります" "確認してください"
}

# 文字色の変更（全部黒に）
$koguchiSheet.range("A1:BN90").font.colorindex = 1

# ×ボタンを押したとき、処理途中のものを削除しよう


# 最後は「開く」「終了」の2択
# 開く→できあがったところのエクスプローラーを表示する


# $kinmuhyouBook.save()
$koguchiBook.save()

$kinmuhyouBook.close()
$koguchiBook.close()

# Rename-Item -path $koguchi -NewName $newKoguchiPath -ErrorAction:Stop

# 勤務表からとってくる勤務地の情報は「勤務内容」の列からだけでOK



# 最終的に、バッチファイルの形にする（.batにする）
# バッチファイルをたたいてもpowershellぽい画面が出ないようにする。

# 志村のテキスト作成バッチで各作業場所の詳細設定 → 松澤のバッチ　→　
# ★READMEをつくる      どういう形式にするかは迷い中。
# ★ショートカットを作る    バッチファイルのショートカットを作成。簡単に作れるのであれば作らない。