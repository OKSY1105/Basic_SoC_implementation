#!/bin/bash

# 파일 존재 여부 확인
if [ ! -f "output.txt" ]; then
    echo "Error: File output.txt does not exist."
    exit 1
fi

if [ ! -f "answer.txt" ]; then
    echo "Error: File answer.txt does not exist."
    exit 1
fi

# 문자, 헤더, 공백을 제외하고 '숫자'만 추출하여 비교
# grep -o '[0-9]\+' : 각 줄에서 숫자 값만 추출
val_out=$(grep -o '[0-9]\+' output.txt)
val_ans=$(grep -o '[0-9]\+' answer.txt)

if [ "$val_out" == "$val_ans" ] && [ -n "$val_out" ]; then
    echo "[PASS] The files are the same."
else
    echo "[FAIL] The files are different."
fi
