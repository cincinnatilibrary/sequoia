#!/usr/bin/perl
use Mojolicious::Lite;

use DBI;

BEGIN{
	#load locally created Modules
	#FindBin gets things into @INC for us
	use FindBin;
	use lib "$FindBin::Bin/./lib/";
	#name of our local Module located in ./lib/
	use Sequoia::BibItems;
	use Sequoia::ItemsInfo;
	use Sequoia::LabelSet;
	use Sequoia::ReplacementRequests;
}

#we'll see this whenever morbo restarts automatically for us
app->log->debug( "is this thing on...?" );

# Rotate passphrases
# you should change these http://mojolicio.us/perldoc/Mojolicious#secrets
app->secrets(['new_passw0rd', 'old_passw0rd', 'very_old_passw0rd']);

# DB Setup
# my $db_host = $ENV{'DB_HOST'};
# my $db_port = $ENV{'DB_PORT'};
# my $db_user = $ENV{'DB_USER'};
# my $db_pass = $ENV{'DB_PASS'};

# pull config paramaters in from config file instead of using env:
use Config::Simple;
my $cfg = new Config::Simple('./sequoia.cfg');

my $db_host = $cfg->param("db_host");
my $db_port = $cfg->param("db_port");
my $db_user = $cfg->param("db_user");
my $db_pass = $cfg->param("db_pass");

my $dbh = DBI->connect("DBI:Pg:dbname=iii;host=".$db_host.";port=".$db_port."",$db_user,$db_pass,{'RaiseError'=>0,'pg_enable_utf8'=>1});

my $archive_password = $ENV{'ARCHIVE_PASSWORD'};

# this is needed in order to tell hypnotoad what port to listen on:
app->config(hypnotoad => {
	listen => ['http://127.0.0.1:8080'],
	proxy => 1,
	}
);

#routes for the template pages
#-----------------------------
get '/' => sub {
	my $self = shift;
	$self->stash( db_host => $db_host );
	$self->render('index');
};
get '/index.html' => sub {
	my $self = shift;
	$self->stash( db_host => $db_host );
	$self->render('index');
};
get '/bib.html' => sub {
	my $self = shift;
	$self->stash( db_host => $db_host );
	$self->render('bib');
};
get '/barcodes.html' => sub {
	my $self = shift;
	$self->stash( db_host => $db_host );
	$self->render('barcodes');
};
get '/help.html' => sub {
	my $self = shift;
	$self->stash( db_host => $db_host );
	$self->render('help');
};
get '/history.html' => sub {
	my $self = shift;
	my $delete_old = $self->param('delete_old');
	#do the deleting here, not in the template
	# delete_old_pdfs();  put this in a module?

	$self->stash( db_host => $db_host );
	$self->render('history');
};

get '/replace.html' => sub {
	my $self = shift;
	$self->stash( db_host => $db_host );
	$self->render('replace');
};



#routes for the "API methods"
#----------------------------
any '/bibitems' => sub {
	my $self = shift;
	my $bibnumber = $self->param('bibnumber');
	my $icode1 = $self->param('icode1');

	$self->render( json => Sequoia::BibItems::items_for_bib_number( $dbh, $bibnumber, $icode1 ) );
};

any '/itemsinfo' => sub {
	my $self = shift;
	my $barcodes_list = $self->param('barcodes');
	my @barcodes = split( ',' , $barcodes_list );

	$self->render( json => Sequoia::ItemsInfo::items_info( $dbh, @barcodes ) );
};

any '/labels' => sub {
	my $self = shift;
	my $barcodes_list = $self->param('barcodes');
	my @barcodes = split( ',' , $barcodes_list );

	$self->render(json => Sequoia::LabelSet::label_set( $dbh, @barcodes ) );
};

any 'addreplacementrequest' => sub {
	my $self = shift;
	my $barcode = $self->param('barcode');
	my $title = $self->param('title');

	# stash the barcodes to somewhere
	Sequoia::ReplacementRequests::add_request_to_request_list( $barcode, $title );

	# return the current ( now updated ) list of requests in JSON
	$self->render( json => Sequoia::ReplacementRequests::request_list() );
};

any 'archivereplacementrequests' => sub {
	my $self = shift;
	my $barcodes_list = $self->param('barcodes');
	my @barcodes = split( ',', $barcodes_list );
	my $password = $self->param('password');
	$self->stash( db_host => $db_host );

	if ( $password eq $archive_password ){
		#move requests from replacementrequests.json to archivedreqests.json
		$self->render( json => Sequoia::ReplacementRequests::archive_requests( @barcodes ) );
	}
	else{
		#do nothing
		$self->render( json => { 'error' => 'bad password' } );
	}
};

#run the app
app->start;
