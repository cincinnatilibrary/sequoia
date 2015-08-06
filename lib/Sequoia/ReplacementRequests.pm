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
	#my $yyyymmdd = sprintf  "%.4d%.2d%.2d", $year+1900, $mon+1, $mday;
	my $yyyymmdd_hyphens = sprintf  "%.4d-%.2d-%.2d", $year+1900, $mon+1, $mday;
	#my $hhmmss = sprintf "%.2d%.2d%.2d", $hour, $min, $sec;
	my $hhmmss_colons = sprintf "%.2d:%.2d:%.2d", $hour, $min, $sec;
	my $timestamp = $yyyymmdd_hyphens . ' ' . $hhmmss_colons;
	
	#if( defined $form{barcode} && $form{barcode} ne '' )
	#{
		#$rlog->debug("barcode received was: ".$form{barcode} );	
		$replacement_requests->{$barcode}->{'request_timestamp'} = $timestamp ;
		#$replacement_requests->{$form{barcode}}->{'title'} = "hello world" ;
	#}

	#if( defined $form{title} && $form{title} ne '' )
	#{
		#$rlog->debug("title received was: ".$form{title} );	
		$replacement_requests->{$barcode}->{'title'} = $title;
	#}

	#write changes to file
	#$rlog->debug("writing json to file: ".$work_dir.$filename);
	open $fh, ">", $work_dir.$filename;
	print $fh Mojo::JSON::encode_json($replacement_requests);
	close $fh;
	
	#return json response
	#$r->content_type('application/json');
	#print to_json( 
	#		$replacement_requests
	#	 );

	return json => $replacement_requests;
	
}

1;
