use strict;
use warnings;
use Getopt::Long;

GetOptions(
    "input|i=s" => \my $file_path,
    "size|s=i" => \my $size,
    "count|c=i" => \my $count,
);

# Example:
# 	S1	S2	S3
# A1	2	4	0
# A2	3	12	0
# A3	5	0	0
# A5	0	0	12
# B1	10	5	4
# B2	3	8	0
# B3	0	3	8
# B4	0	0	2
# B5	0	0	9

my $file_path_cp = $file_path;
$file_path_cp =~ s/.*\///;
my ($file_name, $file_extension) = $file_path_cp =~ /^(.+)\.([^.]+)$/;

print "Input: ${file_path}\n";
print "Parameters:\n\t- Number of subsamples: ${size}\n\t- Total count: ${count}\n";
print "=" x 30 . "\n";
print "Running now! Please wait...\n";

open my $file, "<:utf8", $file_path or die;
my @headers;
my %records;
while (<$file>) {
    chomp;
    @headers = split("\t", $_) if $. == 1;
    next if $. == 1;
    my @fields = split "\t";
    for my $i (1 .. $#fields) {
        $records{$headers[$i]}{$fields[0]} = $fields[$i] unless $fields[$i] == 0;
    };
};
close $file;

for my $key1 (keys %records) {
    for my $key2 (keys %{$records{$key1}}) {
        open my $tmp, ">>:utf8", "${key1}_${file_name}.tmp";
        my $count = $records{$key1}{$key2};
        while ($count > 0) {
            print $tmp "$key2\n";
            $count--;
        };
    };
};
my $iter = 0;
while ($iter < $size) {
    for my $header (@headers[1 .. $#headers]) {
        open my $input, "<:utf8", "${header}_${file_name}.tmp";
        open my $output, ">:utf8", "separated_${header}${iter}_${file_name}.tmp";
        my @records;
        while (<$input>) {
            chomp;
            push @records, $_;
        };
        @records = fisher_yates_shuffle(@records);
        print $output "\t${header}${iter}\n";
        print $output join("\n", @records[0 .. $count-1]);
        close $input;
        close $output;
    };
    $iter++;
};

for my $file (glob("separated_*_${file_name}.tmp")) {
    my %counter;
    open my $input, "<:utf8", $file;
    my $header;
    while (<$input>) {
        chomp;
        $header = $_ if $. == 1;
        next if $. == 1;
        $counter{$_}++;
    };
    close $file;
    open my $output, ">:utf8", "count_${file}";
    print $output "$header\n";
    for my $key (sort keys %counter) {
        print $output join("\t", $key, $counter{$key}, "\n");
    };
};

my @count_files = glob("count_*_${file_name}.tmp");
my %records;
my $tally = 0;
for my $file (@count_files) {
    open my $count_file, "<:utf8", $file or die;
    while (<$count_file>) {
        chomp;
        my ($column_1, $column_2) = split "\t";
        $records{$column_1}[$tally] = $column_2;
    };
    $tally++;
    close $count_file;
};

open my $merged, ">:utf8", "subsampled_${file_name}_${size}_${count}.tsv";
for my $key (sort keys %records) {
    my @values = @{$records{$key}};
    print $merged join("\t", $key, map { $_ // 0 } @values[0 .. $tally - 1], "\n");
};
close $merged;

print "=" x 30 . "\n";
print "Output: subsampled_${file_name}_${size}_${count}.tsv\n";

foreach (glob("*.tmp")) {
    unlink "$_";
};

sub fisher_yates_shuffle {
    my $index = @_;
    while ($index--) {
        my $new_index = int rand ($index+1);
        @_[$index, $new_index] = @_[$new_index, $index] unless $new_index == $index;
    };
    return @_;
};
