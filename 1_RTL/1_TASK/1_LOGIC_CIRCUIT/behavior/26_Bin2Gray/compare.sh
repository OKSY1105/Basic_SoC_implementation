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

# 1. 파일에서 알파벳과 특수 문자를 지우고, 순수 데이터(숫자, x, = 등)와 공백만 남깁니다.
# 2. tr -d '[:space:]'로 모든 공백 및 줄바꿈을 지워 하나의 순수 값 문자열로 압축합니다.
data_output=$(sed 's/[a-zA-Z_]//g' output.txt | tr -d '[:space:]')
data_answer=$(sed 's/[a-zA-Z_]//g' answer.txt | tr -d '[:space:]')

# 데이터 값만 비교
if [ "$data_output" = "$data_answer" ]; then
    echo "[PASS] Data values match perfectly!"
else
    echo "[FAIL] Data values are different."
fi