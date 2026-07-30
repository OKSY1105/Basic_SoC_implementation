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

# sed를 이용하여 '변수명=' 부분을 모두 지우고 값만 남겨서 비교
if diff -q <(sed 's/[a-zA-Z_]*=//g' output.txt) <(sed 's/[a-zA-Z_]*=//g' answer.txt) > /dev/null; then
    echo "[PASS] The files are the same."
else
    echo "[FAIL] The files are different."
fi
