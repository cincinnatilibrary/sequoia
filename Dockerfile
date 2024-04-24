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
	Config::Simple \
	PDF::API2

# expose port
EXPOSE 3000

#add app dir
WORKDIR /srv/www
COPY . /srv/www

# start server
ENTRYPOINT [ "morbo" ]
CMD [ "-l http://0.0.0.0:3000", "sequoia.pl" ]
