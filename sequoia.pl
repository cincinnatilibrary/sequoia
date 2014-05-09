use Mojolicious::Lite;

#we got this via a cpanm command in our Dockerfile
use Config::Simple;


#load locally created Modules
#FindBin gets things into @INC for us
use FindBin;
use lib "$FindBin::Bin/./lib";
#name of our local Module located in ./lib/
use Fake;


#the .cfg file lives at ./ of our app
my $db_cfg = new Config::Simple('./db.cfg');
my $dbhost = $db_cfg->param("DatabaseHost");


#get ENV variables
# 	with docker this can be set via one of two ways:
#	1)
#	in the dockerfile put: ENV MYCOLOR purple
#   2)
#   when you run the container like this:  docker run -e "MYCOLOR=purple" imagename
# 	
my $color = $ENV{'MYCOLOR'};


#create a file with a random name and put it in the static directory ./public/
my $file_name = int(rand(10)) . ".txt";
open FILE, '>'.'./public/'.$file_name;
print FILE "My favorite color is ".$color."\n";
close FILE;


#mojolicous log what the name we generated was
app->log->debug("file name: " . $file_name );


#simplest render just text, tell us the name of the file we randomly created
get '/' => {text => 'I ♥ Mojolicious! '.$file_name };


# this renders via the which.html.ep template
get '/which' => sub {
  my $self = shift;
  #use stash to make variables available in the template
  $self->stash(author     => 'Dave');
  $self->stash(file_name => $file_name);
  $self->stash(db_host => $dbhost);
  $self->render('which');
};

#how to get a url param ( should work for GET or POST ) and how to render some json
any '/jfoo' => sub {
	my $self = shift;
	my $bn = $self->param('bn');
	$self->render(json => {
		$bn => {
		 bs => ['abcde', 'test', 'blah'],
		 title => 'example title',
		 num_items_found => '1'
		}
	});
};



#run the app
app->start;
