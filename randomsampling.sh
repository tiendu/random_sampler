#!/bin/bash
####################################
## Copyright (C) by DU HOANG TIEN ##
## E-mail: tiendu107@gmail.com    ##
####################################

# Remove return-carriage characters to be used with Windows.
tr -d '\015' $0 > temp_$0 && mv temp_$0 $0

usage() {
cat << EOF
Usage:
    --input, -i
        absolute file path e.g., $PWD/
    --size, -s
        subsampling size
    --count, -c
        number of count
EOF
}

cmdline() {
    local arg=
    for arg; do
        local delim=""
        case "$arg" in
            '--input') args="${args}-i" ;;
            '--size')  args="${args}-s" ;;
            '--count') args="${args}-c" ;;
            '--help') args="${args}-h" ;;
            *) [[ "${arg:0:1}" == "-" ]] || delim="\""
                args="${args}${delim}${arg}${delim} " ;;
        esac
    done

    # Indexing option for later.
    OPTIND=1

    # Reset the positional parameters to the short options.
    eval set -- $args

    while getopts "i:s:c:h" OPTION; do
        case $OPTION in
            'i') readonly INPUT_PATH="${OPTARG}" ;;
            's') readonly SIZE="${OPTARG}" ;;
            'c') readonly COUNT="${OPTARG}" ;;
            'h') usage; exit 0 ;;
        esac
    done

    shift "$((OPTIND-1))"

    if [ $OPTIND -eq 1 ] || [ $OPTIND -lt 7 ]; then
        usage
        exit 0
    fi

    echo "Input.............: ${INPUT_PATH}"
    echo "Subsampling size..: ${SIZE}"
    echo "Count.............: ${COUNT}"
    echo "==================================="
}

function input_check {
    local count=$(awk 'NR > 1 { for (i=2; i<=NF; i++) sum[i] += $i } END { for (i in sum) print sum[i] }' $INPUT_PATH)
    local smallest=$(sort -nr <<< $count | head -n 1)
    if [ $COUNT -ge $smallest ]; then
        echo "Please enter \"count\" less than ${smallest}!"
        exit 0
    fi
}

function prepare_temp {
    awk 'NR > 1 { print $0 }' $INPUT_PATH > headerless
    awk 'NR == 1 { print $0 }' $INPUT_PATH > header
}


function sampling {
    local ncol=$1
    local num=$2
    for i in `seq -w 2 $num`; do
        awk '{ print $1 }' headerless > name_$i;
        cut -f1,$i headerless |
            awk '{ i=$2; while (i--) print $1 }' |
            shuf |
            head -n $COUNT |
            awk -v OFS='\t' '{ count[$1]++ } END { for (word in count) print word, count[word] }' |
            sort -t$'\t' -k1,1 -n > tmp_${i}_${num}
        awk '
            FNR == NR { a[$1] = $0; next }
            { print ($1 in a ? a[$1] : $1 "\t" 0) }
            ' tmp_${i}_${num} name_$i > tmp_f_${i}_${num}
    done
}

main() {
    # Call the cmdline function to process command-line arguments
    cmdline $@

    # Prepare header and headerless file.
    prepare_temp

    # Check if count suffices the condition.
    input_check

    local ncol=$(awk 'NR == 2 { print NF }' $INPUT_PATH)
    for ((i=SIZE; i>0; i--)); do
        sampling $ncol $i
    done

    # Merging subsampling columns.
    for i in `seq -w 2 $ncol`; do
        awk -v OFS='\t' '
            FNR == NR { a[FNR] = $0; next }
            { a[FNR] = a[FNR] OFS $2 }
            END { for (i=1; i<=FNR; i++) print a[i] }
            ' tmp_f_${i}_* > col_$i
    done

    # Merging sampling columns.
    local readonly files=(col_*)
    local file=${files[0]}
    for i in "${files[@]:1}"; do
        paste -d'\t' $file <(cut -d$'\t' -f2- $i) > _file.tmp && mv _file.tmp file.tmp
        file=file.tmp
    done

    # Place header.
    local header_string=$(
    for k in `cat header`
            do for i in `seq -w 1 $SIZE`
                do printf "${k}_${i}\t"
            done
        done | sed -E 's/^/\t/; s/\t$/\n/'
        )

    sed -i "1s/^/${header_string}\n/" file.tmp

    readarray -td"." a <<< $INPUT_PATH
    mv file.tmp subsampled_${a[0]}_${SIZE}_${COUNT}.${a[1]}
 
    # Remove carriage-return character (happens if one opens the file in Windows and saves it).
    sed -i 's/\r//g' subsampled_${a[0]}_${SIZE}_${COUNT}.${a[1]}

    # Finishing up.
    rm header*
    rm name_*
    rm tmp_*
    rm col_*

    echo "Result: subsampled_${a[0]}_${SIZE}_${COUNT}.${a[1]}"
}

# Call the main function to start the subsampling process
main $@
