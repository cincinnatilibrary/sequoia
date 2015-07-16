# switched to trusty because it's LTS
FROM ubuntu:trusty

MAINTAINER Dave Menninger <dave.menninger@gmail.com>

#Pre-req's
RUN apt-get update && apt-get install -y \
	build-essential \
	cpanminus \
	libpq-dev \
	postgresql
RUN cpanm DBD::Pg \
	Mojolicious \
	PDF::API2

#add app dir
ADD . /srv/www
WORKDIR /srv/www

# expose port
EXPOSE 3000

# start server
CMD morbo -l http://0.0.0.0:3000 sequoia.pl
