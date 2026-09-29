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

# 값만 비교 (공백/줄바꿈 무시 옵션 추가)
# -w : 모든 공백(스페이스, 탭) 무시
# -B : 빈 줄 무시
# --strip-trailing-cr : 윈도우 개행문자(\r) 무시
if diff -w -B --strip-trailing-cr -q "output.txt" "answer.txt" > /dev/null 2>&1; then
    echo "[PASS] The files are the same."
else
    echo "[FAIL] The files are different."
fi
