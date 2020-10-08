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
	print STDOUT "IN SUB: add_request_to_request_list\n";

	my ( $barcode, $title, $reqestLocation ) = @_;
	# my ( $barcode, $title ) = @_;

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

	# RV add reqestLocation
	$replacement_requests->{$barcode}->{'reqestLocation'} = $reqestLocation;
	print STDERR "replacement_requests -> reqestLocation :";
	print STDERR $replacement_requests->{$barcode}->{'reqestLocation'} . "\n";

	#write changes to file
	open $fh, ">", $work_dir.$filename;
	print $fh Mojo::JSON::encode_json($replacement_requests);
	close $fh;

	return json => $replacement_requests;
}

sub archive_requests {
	my ( @barcodes ) = @_;

	# Alter local .json file
	my $work_dir = './public/';
	my $filename = 'replacementrequests.json';
	my $json;

	#open requests file
	open my $fh, "<", $work_dir.$filename;
	$json = <$fh>;
	close $fh;

	my $replacement_requests = Mojo::JSON::decode_json($json);

	# Alter local .json file
	my $archive_work_dir = './public/';
	my $archive_filename = 'archivedrequests.json';
	my $archive_json;

	#open archive file
	open my $archive_fh, "<", $archive_work_dir.$archive_filename;
	$archive_json = <$archive_fh>;
	close $archive_fh;

	my $archive_replacement_requests = Mojo::JSON::decode_json($archive_json);

	my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
	my $yyyymmdd_hyphens = sprintf  "%.4d-%.2d-%.2d", $year+1900, $mon+1, $mday;
	my $hhmmss_colons = sprintf "%.2d:%.2d:%.2d", $hour, $min, $sec;
	my $timestamp = $yyyymmdd_hyphens . ' ' . $hhmmss_colons;

	for my $barcode ( @barcodes ){
		#remove from requests list
		my $title = $replacement_requests->{$barcode}->{'title'};
		my $request_timestamp = $replacement_requests->{$barcode}->{'request_timestamp'};
		delete $replacement_requests->{$barcode};
		#add to archive list
		$archive_replacement_requests->{$barcode}->{'archive_timestamp'} = $timestamp ;
		$archive_replacement_requests->{$barcode}->{'request_timestamp'} = $request_timestamp ;
		$archive_replacement_requests->{$barcode}->{'title'} = $title;

	}

	#write changes to file
	open $fh, ">", $work_dir.$filename;
	print $fh Mojo::JSON::encode_json($replacement_requests);
	close $fh;

	#write changes to file
	open $archive_fh, ">", $archive_work_dir.$archive_filename;
	print $archive_fh Mojo::JSON::encode_json($archive_replacement_requests);
	close $archive_fh;

	return json => $archive_replacement_requests;
}

1;
