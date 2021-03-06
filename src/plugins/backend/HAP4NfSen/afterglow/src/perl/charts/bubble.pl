#!/usr/bin/perl
use perlchartdir;
#use strict;

my $filename="bubble.png";
my $title="";
my $print=0;
my $logScale=0;
my $trendLine=0;
my $seriesLabel=0;
my $bar=0;

&init;

my %labels;
my @series;
my $max;
# input: label,series1,...,seriesn
while (<STDIN>) {
	chomp;
	my @input=split/,/;
	my $label=shift @input;
	$labels{$label}=1;
	for my $in (@input) {
		push @$label, $in;	
	}
}

if ($print) {
	print join("\n",@labels);
}

my $c = new XYChart(600, 300);
$c->setPlotArea(45, 45, 500, 200, 0xffffff, -1, 0xffffff, $perlchartdir::Transparent, $perlchartdir::Transparent);
$c->addTitle($title, "arialb.ttf", 14);
$c->xAxis()->setWidth(1);
$c->yAxis()->setWidth(1);
if ($logScale) {$c->xAxis()->setLogScale();}
if ($logScale) {$c->yAxis()->setLogScale();}
$c->xAxis()->setLabels(\@labels);
$c->addLegend(50, 30, 0, "arialbd.ttf", 9)->setBackground($perlchartdir::Transparent);

$c->addScatterLayer(\@var, $dataY0, "Daily Risk", $perlchartdir::CircleSymbol,
    9, 0x80ff3333, 0x80ff3333)->setSymbolScale(10);
    #9, 0x80ff3333, 0x80ff3333)->setSymbolScale($dataZ0);

exit;



my $layer;
if ($bar) {
	$layer = $c->addBarLayer();
	$layer->setBorderColor($perlchartdir::Transparent);
	$layer->setBarGap(0.1);
} else { 
	$layer = $c->addLineLayer();
	$layer->setLineWidth(1);
}
my $i=0;
my @foo = keys %labels;
my $foo = $#foo +1;
print STDERR "max:$foo\n";
for my $var (keys %labels) {
	#print STDERR join "/",@$var;
	my ($label1,$trend1);
	if ($seriesLabel) { $label1=$var; $trend1="Trend ".$var}
	$i++;
	my $color = int 256 - ($i * ( 256 / $foo )) ;       
        $color = ($color * 256 * 256) + ($color * 256) + $color;
	$layer->addDataSet(\@$var, $color, $label1)->setDataSymbol($perlchartdir::SquareSymbol, 5);
}

$c->makeChart($filename);

exit;

sub init() {
    my %opt;
    use Getopt::Std;
    getopts("abhlpsf:t:", \%opt ) or usage();

    # Help?
    usage() if $opt{h};
    
    $filename = $opt{f} if $opt{f};
    $title = $opt{t} if $opt{t};
    $print = 1 if $opt{p};
    $logScale = 1 if $opt{l};
    $trendLine = 1 if $opt{a};
    $seriesLabel = 1 if $opt{s};
    $bar = 1 if $opt{b};
}

sub usage() {

    print STDERR << "EOF";

Usage: cat file.csv | bubble.pl [-abhlps] -f outputfile [-t title]");

-a	     : show trend line
-a	     : use a bar chart instead of a line chart
-f	     : output file name, ending in .PNG
-h           : this (help) message
-l	     : use log scale on y-axis
-p           : print the labels
-s	     : show series label
-t	     : chart title

EOF
    exit;
}
    
