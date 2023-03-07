#!/bin/bash
##################
#Copyright (C) by DU HOANG TIEN
###################
usage() { printf "Usage:\n--input\t\tfilepath\n--size\t\tsample size\n--count\t\tnumber of count\n"; exit; }

for arg in "$@"; do
	shift
	case "$arg" in
		'--input')  set -- "$@" '-i' ;;
		'--size')  set -- "$@" '-s' ;;
		'--count') set -- "$@" '-c' ;;
		'--help') set -- "$@" '-h' ;;
		'--') usage ${arg}; exit 2 ;;
		'-') usage ${arg}; exit 2 ;;
		*) set -- "$@" "$arg" ;;
	esac
done

OPTIND=1
while getopts "i:s:c:h" option; do
	case "$option" in 
		'i') filepath=${OPTARG} ;;
		's') size=${OPTARG} ;;
		'c') count=${OPTARG} ;;
		'h') usage; exit 0 ;;
		'?') usage >&2; exit 1 ;;
	esac
done

shift "$((OPTIND-1))"

echo "input = ${filepath}"
echo "sampling size = ${size}"
echo "count = ${count}"

ncol=$(awk 'NR==2 { print NF }' $filepath)
awk 'NR > 1 { print $0 }' $filepath > headerless
awk 'NR==1 { print $0 }' $filepath > header

function sampling {
	num=$s
	for i in $(seq -w 2 $ncol); do
		awk '{ print $1 }' headerless > name_$i; 
		cut -f1,$i headerless | 
			awk '{ i=$2; while (i--) print $1 }' | 
			shuf | 
			head -n $count | 
			awk -v OFS='\t' '{ count[$1]++ } END {for (word in count) print word, count[word]}' | 
			sort -t$'\t' -k1,1 -n > tmp_${i}_${num}; 
			awk 'FNR==NR {a[$1]=$0; next} {print ($1 in a ? a[$1]: $1"\t"0)}' tmp_${i}_${num} name_$i > tmp_f_${i}_${num}; 
	done
}

for ((s=size; s>0; s--)); do 
	sampling $s;
	echo "Sampling ${s}"
done

for i in $(seq -w 2 $ncol); do 
	echo "Merging subsampling columns ${i}"
	awk -v OFS='\t' 'FNR==NR {a[FNR]=$0; next} {a[FNR]=a[FNR] OFS $2} END {for (i=1; i<=FNR; i++) print a[i]}' tmp_f_${i}_* > col_$i;
done

files=(col_*)
file="${files[0]}"

echo "Merging sampling columns"
for f in "${files[@]:1}"; do
	paste -d'\t' "$file" <(cut -d$'\t' -f2- "$f") > _file.tmp && mv _file.tmp file.tmp
	file=file.tmp
done

header_string=$(for k in $(cat header); do for i in $(seq -w 0 $((size-1))); do echo -e -n "${k}${i}\t"; done; done | sed -e 's/^/\t/' | sed -e 's/\t$/\n/')
sed -i "1s/^/${header_string}\n/" file.tmp

echo "Completed!"
readarray -td"." a <<< "${filepath}"
mv file.tmp subsampled_${a[0]}_${size}_${count}.${a[1]}

echo "Cleaning up..."
rm header*
rm name_*
rm tmp_*
rm col_*

echo "Result: subsampled_${a[0]}_${size}_${count}.${a[1]}"
