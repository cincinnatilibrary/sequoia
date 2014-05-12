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
}


#we'll see this whenever morbo restarts automatically for us
app->log->debug( "is this thing on...?" );

# DB Setup
my $db_host = $ENV{'DB_HOST'};;
my $db_port = $ENV{'DB_PORT'};
my $db_user = $ENV{'DB_USER'};
my $db_pass = $ENV{'DB_PASS'};
my $dbh = DBI->connect("DBI:Pg:dbname=iii;host=".$db_host.";port=".$db_port."",$db_user,$db_pass,{'RaiseError'=>0,'pg_enable_utf8'=>1});


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
	$self->render('bib');
};
get '/barcodes.html' => sub {
	my $self = shift;
	$self->render('barcodes');
};
get '/help.html' => sub {
	my $self = shift;
	$self->render('help');
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


#run the app
app->start;
