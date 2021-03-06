FROM debian:jessie
MAINTAINER Peter Alber Atkins "peter.atkins85@gmail.com"
LABEL org.label-schema.vcs-url="https://github.com/nouchka/docker-symfony"
LABEL version="latest"

ARG PHPVERSION=7.1
ARG	PHPCONF=/etc/php/7.1

ENV SYMFONY_ENV=dev \
	SYMFONY_DIRECTORY=/var/www/

ENV APACHE_RUN_USER=www-data \
	APACHE_RUN_GROUP=www-data \
	APACHE_LOG_DIR=/var/log/apache2 \
	APACHE_LOCK_DIR=/var/lock/apache2 \
	APACHE_RUN_DIR=/var/run/apache2 \
	APACHE_PID_FILE=/var/run/apache2/apache2.pid


RUN apt-get update
RUN apt-get install lsb-release -y
RUN apt-get install apt-transport-https ca-certificates -y
RUN echo 'deb https://packages.sury.org/php/ jessie main' >> /etc/apt/sources.list
RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get -q --yes --force-yes install php${PHPVERSION}-xml php${PHPVERSION}-memcache php${PHPVERSION}-mysql php${PHPVERSION}-zip php${PHPVERSION}-redis php${PHPVERSION} php${PHPVERSION}-cli php${PHPVERSION}-curl curl git apache2 libapache2-mod-php${PHPVERSION} php${PHPVERSION}-gd imagemagick php${PHPVERSION}-imagick php${PHPVERSION}-intl php${PHPVERSION}-mcrypt php${PHPVERSION}-xdebug php${PHPVERSION}-apcu memcached php${PHPVERSION}-memcached && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
	php /usr/local/bin/composer self-update

RUN curl -LsS https://symfony.com/installer -o /usr/local/bin/symfony && \
	chmod a+x /usr/local/bin/symfony

RUN curl http://get.sensiolabs.org/php-cs-fixer.phar -o /usr/local/bin/php-cs-fixer && \
	chmod a+x /usr/local/bin/php-cs-fixer

RUN curl -LsS https://phar.phpunit.de/phpunit.phar  -o /usr/local/bin/phpunit && \
	chmod a+x /usr/local/bin/phpunit


##Apache
RUN a2enmod rewrite && \
	a2dissite 000-default && \
	usermod -u 1000 www-data && \
	groupmod -g 1000 www-data && \
	usermod -s /bin/bash www-data

##PHP date.timezone
RUN echo "date.timezone = UTC" >> ${PHPCONF}/cli/php.ini && \
	echo "date.timezone = UTC" >> ${PHPCONF}/apache2/php.ini


##in start.sh with conf on name and port
RUN sed -i 's/session.save_handler = files/session.save_handler = redis/g' ${PHPCONF}/apache2/php.ini &&\
	echo 'session.save_path = tcp://redis:6379' >> ${PHPCONF}/apache2/php.ini && \
	echo 'memory_limit = 1000M ' >> ${PHPCONF}/apache2/php.ini



COPY  xdebug.ini /etc/php/7.1/mods-available/xdebug.ini
RUN phpenmod xdebug

COPY start.sh /start.sh
COPY init.sh  /var/www/init.sh
COPY oni-sys-vhost.conf /etc/apache2/sites-enabled/oni-sys-vhost.conf

RUN chmod +x /start.sh
RUN chmod +x /var/www/init.sh

COPY check.sh /check.sh
RUN chmod +x /check.sh
HEALTHCHECK CMD /check.sh

WORKDIR /var/www

EXPOSE 80
CMD /start.sh
