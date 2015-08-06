package Sequoia::ReplacementRequests;

use strict;
use warnings;

use Mojo::JSON;

sub request_list {
	# local .json file
	my $work_dir = './public/';
	my $filename = 'replacementrequests.json';
	my $json;

	#open file
	open my $fh, "<", $work_dir.$filename;
	$json = <$fh>;
	close $fh;

	my $replacement_requests = Mojo::JSON::decode_json($json);

	return json => $replacement_requests;
}

sub add_request_to_request_list {
	my ( $barcode, $title ) = @_;

	# Alter local .json file
	my $work_dir = './public/';
	my $filename = 'replacementrequests.json';
	my $json;

	#open file
	open my $fh, "<", $work_dir.$filename;
	$json = <$fh>;
	close $fh;

	my $replacement_requests = Mojo::JSON::decode_json($json);

	my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
	my $yyyymmdd_hyphens = sprintf  "%.4d-%.2d-%.2d", $year+1900, $mon+1, $mday;
	my $hhmmss_colons = sprintf "%.2d:%.2d:%.2d", $hour, $min, $sec;
	my $timestamp = $yyyymmdd_hyphens . ' ' . $hhmmss_colons;

	$replacement_requests->{$barcode}->{'request_timestamp'} = $timestamp ;
	$replacement_requests->{$barcode}->{'title'} = $title;

	#write changes to file
	open $fh, ">", $work_dir.$filename;
	print $fh Mojo::JSON::encode_json($replacement_requests);
	close $fh;

	return json => $replacement_requests;
}

1;
