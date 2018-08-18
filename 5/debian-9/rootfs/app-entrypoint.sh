#!/bin/bash -e
. /opt/bitnami/base/functions

print_welcome_page

INIT_SEM=/tmp/initialized.sem

fresh_container() {
  [ ! -f $INIT_SEM ]
}

app_present() {
  [ -f /app/config/database.php ]
}

wait_for_db() {
  mariadb_address=$(getent hosts mariadb | awk '{ print $1 }')
  counter=0
  log "Connecting to mariadb at $mariadb_address"
  while ! curl --silent mariadb:3306 >/dev/null; do
    counter=$((counter+1))
    if [ $counter == 30 ]; then
      log "Error: Couldn't connect to mariadb."
      exit 1
    fi
    log "Trying to connect to mariadb at $mariadb_address. Attempt $counter."
    sleep 5
  done
}

setup_db() {
  log "Configuring the database"
  sed -i "s/utf8mb4/utf8/g" /app/config/database.php
  php artisan migrate
}

if [ "${1}" == "php" -a "$2" == "artisan" -a "$3" == "serve" ]; then
  if ! app_present; then
    log "Creating laravel application"
    cp -r /tmp/app/ /
  fi

  log "Installing/Updating Laravel dependencies (composer)"
  composer install
  log "Dependencies updated"

  wait_for_db

  if ! fresh_container; then
    echo "#########################################################################"
    echo "                                                                         "
    echo " App initialization skipped:                                             "
    echo " Delete the file $INIT_SEM and restart the container to reinitialize     "
    echo " You can alternatively run specific commands using docker-compose exec   "
    echo " e.g docker-compose exec myapp php artisan make:console FooCommand       "
    echo "                                                                         "
    echo "#########################################################################"
  else
    setup_db
    log "Initialization finished"
    touch $INIT_SEM
  fi
fi

exec tini -- "$@"
