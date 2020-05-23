#!/bin/sh
#
# ./test.sh <test_dir>
#
# Quick script to test the `extract` program.
###

TEST_DIR="$1"
if [ -z "$1" ]; then
    printf "Missing test directory argument\n"
    exit 1
fi

reset="\e[0m"
red="\e[31m"
green="\e[32m"

cross="${red}✘${reset} "
check="${green}✔${reset}"

pass=0
fail=0

checksum() {
    md5sum $1 | awk '{print $1}'
}

compare() {
    [ "$(checksum $1)" == "$(checksum $2)" ]
}

describe() {
    DESC_STR="$*"
}

check() {
    unset opt n OPTIND
    getopts 'n:' opt
    if [ "$opt" != "?" ]; then
        n=$OPTARG
        shift $(($OPTIND - 1))
    fi

    ./extract -n ${n:-2000} -s $1 $2 > $TEST_DIR/output.csv

    if ! compare "$TEST_DIR"/output.csv $3; then
        fail=$((fail + 1))
        printf "%s...$cross\n" "$DESC_STR"
    else
        pass=$((pass + 1))
    fi
}

describe "Match single column in small matrix"
check '^alpha$' "$TEST_DIR"/small_matrix.csv "$TEST_DIR"/alpha.csv

describe "Match single column by letter count in small matrix"
check '\S{6,}' "$TEST_DIR"/small_matrix.csv "$TEST_DIR"/alpha_beta.csv

describe "Matching two or more leading digits"
check -n 2000 '^[0-9]{2,}_\S$' "$TEST_DIR"/large_matrix.csv \
      "$TEST_DIR"/multiple_digit_all_rows.csv

describe "Matching single digit"
check -n 100 '^[0-9]_\S$' "$TEST_DIR"/large_matrix.csv \
      "$TEST_DIR"/single_digit_100_rows.csv

describe "Matching multiple digits and any letter not 'a'"
check -n 100 '[0-9]_[^a]$' "$TEST_DIR"/large_matrix.csv \
      "$TEST_DIR"/multiple_digits_not_a_100_rows.csv

printf "Finished: %d $check, %d $cross\n" $pass $fail

if (( fail > 0 )); then
    exit 127
fi
