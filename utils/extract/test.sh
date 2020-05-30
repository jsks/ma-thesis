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

reset="\033[0m"
red="\033[31m"
green="\033[32m"

cross="${red}✘${reset} "
check="${green}✔${reset}"

pass=0
fail=0

checksum() {
    md5sum $1 | awk '{print $1}'
}

describe() {
    DESC_STR="$*"
}

check() {
    # OPTIND resets for each function call in zsh and dash, but not
    # bash. Set to 1, since OPTIND can't be unset in dash.
    OPTIND=1

    unset opt n
    getopts 'n:' opt
    if [ "$opt" != "?" ]; then
        n=$OPTARG
        shift $(( OPTIND - 1 ))
    fi

    ./extract -n ${n:-2000} -s $1 $2 > $TEST_DIR/output.csv

    if [ "$(checksum $TEST_DIR/output.csv)" != "$(checksum $3)" ]; then
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

describe "Matching two or more leading digits and letter a"
check -n 5 '^[0-9]{2,}_a$' "$TEST_DIR"/large_matrix.csv \
      "$TEST_DIR"/multiple_digit_a.csv

describe "Matching single digit with 2 rows"
check -n 2 '^[0-9]_\S$' "$TEST_DIR"/large_matrix.csv \
      "$TEST_DIR"/single_digit_2_rows.csv

describe "Matching multiple digits not starting with 1"
check -n 5 '^[^1]' "$TEST_DIR"/large_matrix.csv \
      "$TEST_DIR"/multiple_digits_not_1.csv

printf "Finished: %d $check, %d $cross\n" $pass $fail

if [ "$fail" -gt 0 ]; then
    exit 127
fi
