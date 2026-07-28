#!/bin/bash

# 파일 존재 여부 확인
if [ ! -f "output.txt" ] || [ ! -f "answer.txt" ]; then
    echo "Error: output.txt or answer.txt does not exist."
    exit 1
fi

# 알파벳(변수 이름)과 공백을 모두 지우고 숫자 및 로직값(=, x 등)만 남겨서 비교
file1_data=$(sed 's/[a-zA-Z_]//g' output.txt | tr -d '[:space:]')
file2_data=$(sed 's/[a-zA-Z_]//g' answer.txt | tr -d '[:space:]')

if [ "$file1_data" = "$file2_data" ]; then
    echo "[PASS] Data values are identical!"
else
    echo "[FAIL] Data values are different."
fi
