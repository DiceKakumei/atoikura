#!/usr/bin/env bash
# エミュレーター上でAPKを実際にインストールして操作し、画面を録画する
set -x
APP=io.github.dicekakumei.atoikura
OUT=out; mkdir -p $OUT
mark() { echo "$1 $(date +%s.%N)" >> $OUT/marks.txt; }

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
adb shell settings put system accelerometer_rotation 0 || true

adb shell input keyevent KEYCODE_HOME
sleep 3
adb exec-out screencap -p > $OUT/00_home.png

adb shell "screenrecord --size 720x1600 --bit-rate 8000000 --time-limit 150 /sdcard/demo.mp4" &
sleep 3
mark rec_start

# 起動
adb shell monkey -p $APP -c android.intent.category.LAUNCHER 1
sleep 6
mark launched
adb exec-out screencap -p > $OUT/01_launched.png
python3 demo/ui.py dump $OUT/ui_launched.xml

# 1 予算
python3 demo/ui.py tap-edit 0; sleep 1
mark budget_start
adb shell input text 12000; sleep 3
adb exec-out screencap -p > $OUT/02_budget.png
mark budget_end

# 2 使った金額
python3 demo/ui.py tap-edit 1; sleep 1
mark spend1_start
adb shell input text 480; sleep 1
python3 demo/ui.py tap-text 使った; sleep 3
adb exec-out screencap -p > $OUT/03_spend1.png
python3 demo/ui.py tap-edit 1; sleep 1
adb shell input text 1200; sleep 1
adb shell input keyevent 66; sleep 3
for i in 1 2 3; do python3 demo/ui.py tap-text +500; sleep 1; done
python3 demo/ui.py tap-text 使った; sleep 3
adb exec-out screencap -p > $OUT/04_spend_done.png
python3 demo/ui.py dump $OUT/ui_after.xml
mark spend_end
sleep 3

# 3 アプリを閉じて開き直す（保存されているか）
adb shell am force-stop $APP; sleep 1
mark closed
adb shell input keyevent KEYCODE_HOME; sleep 3
mark reopen
adb shell monkey -p $APP -c android.intent.category.LAUNCHER 1
sleep 6
adb exec-out screencap -p > $OUT/05_reopened.png
mark reopened_shown
sleep 4
mark rec_end

adb shell pkill -2 screenrecord || true
sleep 4
wait || true
adb pull /sdcard/demo.mp4 $OUT/demo.mp4 || true
adb logcat -d -t 300 > $OUT/logcat_tail.txt || true
ls -l $OUT
