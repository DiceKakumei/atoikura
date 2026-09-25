#!/usr/bin/env python3
"""エミュレーターのUI(uiautomator)を読んでタップする小さな補助スクリプト。"""
import re, subprocess, sys
import xml.etree.ElementTree as ET

def sh(*a):
    return subprocess.run(['adb', 'shell', *a], capture_output=True, text=True).stdout

def dump():
    for _ in range(4):
        sh('uiautomator', 'dump', '/sdcard/ui.xml')
        x = subprocess.run(['adb', 'exec-out', 'cat', '/sdcard/ui.xml'], capture_output=True, text=True).stdout
        if '<hierarchy' in x:
            return x
    raise SystemExit('uiautomator dump failed')

def nodes(xml):
    return list(ET.fromstring(xml).iter('node'))

def center(n):
    x1, y1, x2, y2 = map(int, re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.get('bounds')).groups())
    return (x1 + x2) // 2, (y1 + y2) // 2

def label(n):
    return (n.get('text') or '') + '|' + (n.get('content-desc') or '')

def tap(n):
    x1, y1, x2, y2 = map(int, re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.get('bounds')).groups())
    if y2 <= y1 or x2 <= x1:
        raise SystemExit('element not visible: ' + label(n))
    x, y = center(n)
    print('tap', x, y, label(n))
    sh('input', 'tap', str(x), str(y))

cmd = sys.argv[1]
if cmd == 'dump':
    open(sys.argv[2], 'w', encoding='utf-8').write(dump())
elif cmd == 'tap-edit':
    idx = int(sys.argv[2])
    edits = [n for n in nodes(dump()) if n.get('class') == 'android.widget.EditText']
    print('edits', len(edits))
    tap(edits[idx])
elif cmd == 'tap-text':
    want = sys.argv[2]
    ns = nodes(dump())
    exact = [n for n in ns if want in [n.get('text'), n.get('content-desc')]]
    part = [n for n in ns if want in label(n)]
    hit = (exact or part)
    if not hit:
        raise SystemExit('not found: ' + want)
    tap(hit[0])
