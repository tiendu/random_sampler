# random sampler

The script randomsampling.pl is used for random sampling / rarefying.

To use it, please follows this instruction.

@ 	S1	S2	S3
@ A1	2	4	0	
@ A2	3	12	0	
@ A3	5	0	0	
@ A5	0	0	12	
@ B1	10	5	4	
@ B2	3	8	0	
@ B3	0	3	8	
@ B4	0	0	2	
@ B5	0	0	9	

--input or -i: file input in the above format in TSV (the @ indicates the row, nothing more, please look into the script, there's an example how it should look).
--size or -s: the number of subsamples.
--count or -c: the total counts must be less than the smallest sample.
