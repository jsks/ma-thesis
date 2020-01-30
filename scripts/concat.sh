#!/bin/sh

set -e

usage() {
    printf "Usage: ./$(basename $0) [-h] [-o <dir>] <input...>\n"
    exit 127
}

get_ids() {
    echo "$headers" | grep -En "$1" | cut -d ':' -f1 | paste -s -d ','
}

parse() {
    echo "$headers" | paste -s -d ',' | cut -d ',' -f "$1"
    sed '/^[#l]/d' $files | cut -d ',' -f "$1"
}



help() {
cat <<EOF
$(usage)

Concatenates posterior csv files from Stan into a single compressed
file.

Options:
        -h Useless help message
        -o Output directory
EOF

exit
}

while getopts 'ho:' opt; do
    case $opt in
        h)
            help;;
        o)
            OUTDIR=$OPTARG;;
        *)
            usage;;
    esac
done

shift $(( $OPTIND - 1 ))
([ -z "$1" ] || [  ! -d "$OUTDIR" ]) && usage

files="$@"

re='_est[.]|__$|^raw_|_unif[.]?|nu'
headers=$(sed '/^[#]/d' $1 | head -n 1 | tr ',' '\n')

err_ids=$(get_ids '^lg_est[.][[:digit:]]*[.]1$|^nonlg_est[.][[:digit:]]*[.]1$')
fa_ids=$(get_ids '^lambda|^gamma|^psi|^delta|^eta|^theta')
reg_ids=$(get_ids '^alpha|^beta|^sigma|^Z_|^p_hat|^log_lik')

parse "$err_ids" | gzip > $OUTDIR/err_posteriors.csv.gz
parse "$fa_ids" | gzip > $OUTDIR/fa_posteriors.csv.gz
parse "$reg_ids" | gzip > $OUTDIR/reg_posteriors.csv.gz
