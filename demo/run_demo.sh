#!/usr/bin/env bash
# エミュレーター上でAPKを実際にインストールして操作し、画面を録画する
set -x
APP=io.github.dicekakumei.atoikura
OUT=out; mkdir -p $OUT
mark() { echo "$1 $(date +%s.%N)" >> $OUT/marks.txt; }
ime_visible() { adb shell dumpsys input_method | grep -q 'mInputShown=true'; }
hide_kb() { if ime_visible; then adb shell input keyevent 4; sleep 0.8; fi; }
type_digits() { for d in $(echo "$1" | sed 's/./& /g'); do adb shell input text "$d"; sleep 0.25; done; }

adb root || true
sleep 3
adb wait-for-device
# 日付を9/10に固定（残り日数21日の計算例にするため）
adb shell settings put global auto_time 0 || true
adb shell settings put global auto_time_zone 0 || true
adb shell "date 091012002026.00" || true
adb shell date
adb install -r atoikura.apk
adb shell pm list packages | grep atoikura
adb shell wm size
adb shell wm density

# 一度起動してWebViewを温め、閉じてホームに戻す（録画には入れない）
adb shell monkey -p $APP -c android.intent.category.LAUNCHER 1
sleep 5
python3 demo/ui.py dump $OUT/warmup.xml
adb shell am force-stop $APP
sleep 1
adb shell pm clear $APP

adb shell "screenrecord --size 720x1600 --bit-rate 8000000 --time-limit 150 /sdcard/demo.mp4" &
sleep 2
mark rec_start

adb shell monkey -p $APP -c android.intent.category.LAUNCHER 1
sleep 4
mark launched
adb exec-out screencap -p > $OUT/01_launched.png
python3 demo/ui.py dump $OUT/ui_launched.xml >/dev/null

# 1 予算
python3 demo/ui.py tap-edit 0; sleep 0.8
mark budget_start
type_digits 12000; sleep 2.2
adb exec-out screencap -p > $OUT/02_budget.png
mark budget_end

# 2 使った金額
python3 demo/ui.py tap-edit 1; sleep 0.6
mark spend_start
type_digits 480; sleep 0.5
python3 demo/ui.py tap-text 使った; sleep 2
adb exec-out screencap -p > $OUT/03_spend1.png
python3 demo/ui.py tap-edit 1; sleep 0.5
type_digits 1200; sleep 0.4
adb shell input keyevent 66; sleep 2
hide_kb
for i in 1 2 3; do
  python3 demo/ui.py tap-text +500; sleep 0.8
  hide_kb
done
python3 demo/ui.py tap-text 使った; sleep 2.5
adb exec-out screencap -p > $OUT/04_spend_done.png
mark spend_end
sleep 3
mark result_shown

# 3 アプリを閉じて開き直す（保存されているか）
adb shell am force-stop $APP
mark closed
sleep 1.5
adb shell monkey -p $APP -c android.intent.category.LAUNCHER 1
mark reopen
sleep 5
adb exec-out screencap -p > $OUT/05_reopened.png
mark reopened_shown
sleep 3.5
mark rec_end

adb shell pkill -2 screenrecord || true
sleep 4
wait || true
adb pull /sdcard/demo.mp4 $OUT/demo.mp4 || true
python3 demo/ui.py dump $OUT/ui_final.xml >/dev/null || true
adb logcat -d -t 200 > $OUT/logcat_tail.txt || true
ls -l $OUT
