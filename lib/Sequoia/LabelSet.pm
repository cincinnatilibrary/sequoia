package Sequoia::LabelSet;
  
use strict;
use warnings;
 
use PDF::API2;

BEGIN
{
	use Sequoia::MakeLabelPDF qw( get_info_for_requested_items produce_and_distribute_labels );
}


sub label_set {	
	my ( $dbh , @barcodes ) = @_ ;
	
	#various timestamps used for various purposes
	my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
	my $yyyymmdd = sprintf  "%.4d%.2d%.2d", $year+1900, $mon+1, $mday;
	my $hhmmss = sprintf "%.2d%.2d%.2d", $hour, $min, $sec;
	my $hhmmss_colons = sprintf "%.2d:%.2d:%.2d", $hour, $min, $sec;
	
	#=============
	#PRODUCE A PDF
	#
	# to use MakeLabelPDF.pm you do this:
	
	my %label_requests;
	my %item_info_for;
	
	# label_requests is shaped like this:
	#
	#  $date = YYYYMMDD
	#  $uacs = any username/string/number
	#  $barcode = the barcode requested
	#  $time = HHMMSS 
	#
	#  $label_request_ref->{$date}{$uacs}{$barcode} = $time;
	
	foreach my $barcode (@barcodes)
	{
		#TODO: error checking / input validation
		$label_requests{$yyyymmdd}{'OnDemand'}{$barcode} = $hhmmss;
	}
	
	# this takes your requests and fills up the %item_info_for hash
	get_info_for_requested_items(
		$dbh, 
		\%label_requests, 
		\%item_info_for
	);

	#directory perl can access and create subdirs, files, etc
	my $work_dir = './public';
	
	my %results;
	
	# this takes the requests hash and the info hash and builds pdf files in work_dir
	%results = produce_and_distribute_labels(
		\%label_requests, 
		\%item_info_for, 
		{
			'workdir'=> $work_dir
		}
	);
	# after this, in theory the pdf should be in 
	#  /$work_dir
	#TODO: figure out how to clean up the old pdf files
	
	#return json response
	
	#TODO: some sort of success/failure status in the return message?
	# return which barcodes were actually produced versus which were requested
	# return request begin timestamp and request completed timestamp
	
	return json => { 
		'bookpdf' => '/' . $results{'bookfilename'} , 
		'discpdf' => '/' . $results{'discfilename'} , 
		'barcodes' => \@barcodes , 
		'timestamp' => $hhmmss_colons ,
		'donelabels' => $results{'donelabels'}
		};
}

1;
