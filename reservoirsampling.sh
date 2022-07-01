## Reservoir sampling
#!/bin/bash
while getopts i:s:f: option; do
	case ${option} in
		i) filepath=${OPTARG};;
		s) size=${OPTARG};;
		f) format=${OPTARG};;
	esac
done

if [ $format = "paired-end-fastq" ] || [ $format = "paired-end-fasta"  ]
then
	readarray -td'_' a <<< "${filepath}"
	filename=${a[0]}
	readarray -td'.' a <<< "${filepath}"
	fileextension=$(printf ".%s" "${a[@]:1}")
elif [ $format = "single-end-fastq" ] || [ $format = "single-end-fasta" ]
then
	readarray -td'.' a <<< "${filepath}"
	filename=${a[0]}
	fileextension=$(printf ".%s" "${a[@]:1}")
fi

tmp1=${filename}_tmp1
tmp2=${filename}_tmp2

function paired_end_fastq_input {
	fr=${filename}_1${fileextension}
	rr=${filename}_2${fileextension}
	echo "Processing paired end fastq ${fr} and ${rr}"
	paste $fr $rr | awk '{printf("%s", $0); n++; if (n%4==0) {printf("\n");} else {printf("\t");}}' > $tmp1
}

function paired_end_fasta_input {
	fr=${filename}_1${fileextension}
	rr=${filename}_2${fileextension}
	echo "Processing paired end fasta ${fr} and ${rr}"
	paste <(awk '/^>/ {printf("\n%s\n", $0); next;} {printf("%s", $0);} END {printf("\n");}' < $fr) <(awk '/^>/ {printf("\n%s\n", $0); next;} {printf("%s",$0);} END {printf("\n");}' < $rr) | awk 'NR>1 {printf("%s", $0); n++; if (n%2==0) {printf("\n");} else {printf("\t");}}' > $tmp1
}

function single_end_fastq_input {
	echo "Processing single end fastq ${filepath}"
	cat $filepath | awk '{printf("%s", $0); n++; if (n%4==0) {printf("\n");} else {printf("\t");}}' > $tmp1
}

function single_end_fasta_input {
	echo "Processing single end fasta ${filepath}"
	awk '/^>/ {printf("\n%s\n",$0);next; } {printf("%s",$0);} END {printf("\n");}' < $filepath | awk 'NR>1{printf("%s",$0); n++; if(n%2==0) {printf("\n");} else {printf("\t");}}' > $tmp1
}

function sampling {
	echo "Sampling ${filename} with size = ${size}"
	awk -v k=$size -v t=$tmp2 'BEGIN {srand(systime() + PROCINFO["pid"]); for (i=1; i<=k*2; i++) {s=i<=k?i-1:int(rand()*i); if (s<k) R[s]=i}; n=asort(R)} {if (NR==1) l=1; if (NR==R[l]) {print $0 >> t;l++}}' $tmp1
}

function paired_end_fastq_output {
	fr_o=${filename}_1_sub${fileextension}
	rr_o=${filename}_2_sub${fileextension}
	awk -v f=$fr_o -v r=$rr_o -F'\t' '{print $1"\n"$3"\n"$5"\n"$7 > f; print $2"\n"$4"\n"$6"\n"$8 > r}' $tmp2
}

function paired_end_fasta_output {
	fr_o=${filename}_1_sub${fileextension}
	rr_o=${filename}_2_sub${fileextension}
	awk -v f=$fr_o -v r=$rr_o -F'\t' '{print $1"\n"$3 > f; print $2"\n"$4 > r}' $tmp2
}

function single_end_fastq_output {
	r_o=${filename}_sub${fileextension}
	awk -v r=$r_o -F'\t' '{print $1"\n"$2"\n"$3"\n"$4 > r}' $tmp2
}

function single_end_fasta_output {
	r_o=${filename}_sub${fileextension}
	awk -v r=$r_o -F'\t' '{print $1"\n"$2 > r}' $tmp2
}

if [ $format = "paired-end-fastq" ]
then
	paired_end_fastq_input
	sampling
	paired_end_fastq_output
elif [ $format = "paired-end-fasta" ]
then
	paired_end_fasta_input
	sampling
	paired_end_fasta_output
elif [ $format = "single-end-fastq" ]
then
	single_end_fastq_input
	sampling
	single_end_fastq_output
elif [ $format = "single-end-fasta" ]
then
	single_end_fasta_input
	sampling
	single_end_fasta_output
fi

echo "Finishing..."
rm $tmp1
rm $tmp2
