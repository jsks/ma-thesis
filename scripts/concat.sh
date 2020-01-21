#!/bin/sh

set -e

usage() {
    printf "Usage: ./$(basename $0) [-h] [-o <file>] <input...>\n"
    exit 127
}

help() {
cat <<EOF
$(usage)

Concatenates posterior csv files from Stan into a single compressed
file.

Options:
        -h Useless help message
        -o Output file
EOF

exit
}

while getopts 'ho:' opt; do
    case $opt in
        h)
            help;;
        o)
            OUTPUT=$OPTARG;;
        *)
            usage;;
    esac
done

shift $(( $OPTIND - 1 ))
([ -z "$1" ] || [  -z "$OUTPUT" ]) && usage

re='_est[.]|__$|^raw_|_unif[.]?|nu'
headers=$(sed '/^[#]/d' $1 | head -n 1 | tr ',' '\n')
ids=$(echo "$headers" | grep -Evn "$re" | cut -d ':' -f1 | paste -s -d ',')

{ echo "$headers" | paste -s -d ','  | cut -d ',' -f "$ids";
    sed '/^[#l]/d' $@ | cut -d ',' -f "$ids"; } | gzip > $OUTPUT
