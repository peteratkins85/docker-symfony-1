#!/bin/bash

[ ! -f "$APACHE_PID_FILE" ] || rm -f $APACHE_PID_FILE

##Generate apache conf with secrets from docker
APACHE_SECRETS_CONF_FILE="/etc/apache2/conf-enabled/secrets.conf"
[ ! -f "$APACHE_SECRETS_CONF_FILE" ] || rm -f $APACHE_SECRETS_CONF_FILE
find /var/run/secrets/ -type f| while read secret
do
	name=`basename $secret`
	value=`cat $secret`
	echo "SetEnv $name $value" >> /etc/apache2/conf-enabled/secrets.conf
done

initSf () {
	CURRENT_DIR=`dirname $SYMFONY_DIRECTORY/$1`
	cd $CURRENT_DIR
	ENV_NAME="$(basename `pwd`)"
	INIT_NAME="SYMFONY_INIT_${ENV_NAME,,}"
	PRE_NAME="SYMFONY_PREV_${ENV_NAME,,}"
	POST_NAME="SYMFONY_POST_${ENV_NAME,,}"
	echo $ENV_NAME
	if [ ${!PRE_NAME} ]; then
		if [ -f ${!PRE_NAME} ]; then
			chmod +x ${!PRE_NAME}
			${!PRE_NAME}
		else
			echo "File missing "${!PRE_NAME}
		fi
	fi
	if [ ${!INIT_NAME} ]; then
		if [ "$SYMFONY_ENV" == "dev" ]; then
			su www-data -c "composer install"
		elif [ "$SYMFONY_ENV" == "test" ]; then
			su www-data -c "composer install"
		else
			if [ ! -f "app/console" ]; then
				CONSOLE="app/console"
				mkdir -p app/
				cd app/
				ln -s $CURRENT_DIR/bin/console console
				cd ..
			fi
			su www-data <<'EOF'
composer install --no-dev --optimize-autoloader
composer dump-autoload --no-dev -o
php app/console cache:clear --env=$SYMFONY_ENV --no-debug
php app/console assetic:dump --env=$SYMFONY_ENV --no-debug
EOF
		fi
	fi
	if [ ${!POST_NAME} ]; then
		if [ -f ${!POST_NAME} ]; then
			chmod +x ${!POST_NAME}
			${!POST_NAME}
		else
			echo "File missing "${!POST_NAME}
		fi
	fi
	chown -R www-data: .
}
export -f initSf

if [ "$SYMFONY_ENV" == "dev" ]; then
	echo "Env "$SYMFONY_ENV
elif [ "$SYMFONY_ENV" == "test" ]; then
	echo "Env "$SYMFONY_ENV
else
	echo "Env "$SYMFONY_ENV
	phpdismod xdebug
fi


chown -R www-data: $SYMFONY_DIRECTORY
cd $SYMFONY_DIRECTORY
mkdir -p /var/www/.composer
chown -R www-data: /var/www/.composer

if [ -f "composer.json" ]; then
	initSf composer.json
else
	find . -maxdepth 2 -name 'composer.json' -exec bash -c 'initSf "$0"' {} \;
fi

if [ $1 ]; then
	exit 0
fi

/usr/sbin/apache2 -D FOREGROUND
