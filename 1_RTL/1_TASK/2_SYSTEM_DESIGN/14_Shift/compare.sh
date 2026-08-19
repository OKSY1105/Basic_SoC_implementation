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

# 텍스트 라벨을 제외하고 실제 데이터 값(0, 1, x, z 등)만 추출하여 비교
val_out=$(grep -o '[0-9xzXZ]\+' output.txt)
val_ans=$(grep -o '[0-9xzXZ]\+' answer.txt)

if [ "$val_out" == "$val_ans" ] && [ -n "$val_out" ]; then
    echo "[PASS] The files are the same."
else
    echo "[FAIL] The files are different."
fi
