# switched to trusty because it's LTS
FROM ubuntu:trusty

#Pre-req's
RUN apt-get update
RUN apt-get install -y build-essential
RUN apt-get install -y cpanminus
RUN apt-get install -y postgresql libpq-dev
RUN cpanm Mojolicious
RUN cpanm PDF::API2
RUN cpanm DBD::Pg

#add app dir
ADD . /srv/www
WORKDIR /srv/www

#TODO: can this be overridden at run time?
EXPOSE 3000

#DOOOOOOOOOOOOM!
CMD morbo -l http://0.0.0.0:3000 sequoia.pl
