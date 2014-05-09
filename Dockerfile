#Get's us what we need for Mojo to work
FROM octohost/mojolicious

#Get a Perl module from CPAN
RUN apt-get install -y cpanminus
RUN cpanm Config::Simple

#This is necessary, but I'm not 100% why
ADD . /srv/www
WORKDIR /srv/www

#TODO: can this be overridden at run time?
EXPOSE 3000

#set an ENV variable that the app can see
ENV MYCOLOR purple

#DOOOOOOOOOOOOM! 
CMD morbo -l http://0.0.0.0:3000 sequoia.pl
