#!/bin/bash
for i in $(seq 1 9); do
    output_file="output_${i}.txt"
    answer_file="answer_${i}.txt"

    if [ ! -f "$output_file" ]; then
        echo "Error: File $output_file does not exist."
        exit 1
    fi

    if [ ! -f "$answer_file" ]; then
        echo "Error: File $answer_file does not exist."
        exit 1
    fi

    if diff -q "$output_file" "$answer_file" > /dev/null; then
        echo "[PASS] $output_file and $answer_file are the same."
    else
        echo "[FAIL] $output_file and $answer_file are different."
    fi

done
