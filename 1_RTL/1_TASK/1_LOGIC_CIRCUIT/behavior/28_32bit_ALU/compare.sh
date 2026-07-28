#!/bin/bash

# 파일 존재 여부 확인
if [ ! -f "output.txt" ] || [ ! -f "answer.txt" ]; then
    echo "Error: output.txt or answer.txt does not exist."
    exit 1
fi

# 콜론(:) 뒤에 나오는 값(16진수 및 숫자)만 정확히 추출하는 함수
extract_pure_values() {
    # 1. grep -oE로 콜론 뒤의 알파벳/숫자 값만 잘라냅니다.
    # 2. tr -d로 공백/엔터를 없애서 하나의 데이터 줄로 만듭니다.
    grep -oE ':[[:space:]]*[0-9a-fA-F]+' "$1" | tr -d ':[:space:]'
}

data_output=$(extract_pure_values "output.txt")
data_answer=$(extract_pure_values "answer.txt")

# 데이터 값만 비교
if [ "$data_output" = "$data_answer" ]; then
    echo "[PASS] All 16-hex data values match perfectly!"
else
    echo "[FAIL] Data values are different."
fi
