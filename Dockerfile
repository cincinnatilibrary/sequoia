#Gets us what we need for Mojo to work
FROM octohost/mojolicious

#Pre-req's
RUN apt-get update
#RUN apt-get install -y cpanminus
#RUN cpanm DBI 
#RUN cpanm DBD::Pg
RUN apt-get install -y libdbd-pg-perl libpdf-api2-perl

#This is necessary, but I'm not 100% why
ADD . /srv/www
WORKDIR /srv/www

#TODO: can this be overridden at run time?
EXPOSE 3000

#DOOOOOOOOOOOOM! 
CMD morbo -l http://0.0.0.0:3000 sequoia.pl
