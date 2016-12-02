#!/bin/bash

set -e
set -x

source /etc/opt/copilot

# Also defined separately in copilot repo "install" file.
# readonly PROG_DIR=$(readlink -m $(dirname $0))

temporary_fixes () {
    echo dnsmasq-base hold |dpkg --set-selections
}

# ==== OS ====

update_os() {
    apt-get -y update
    apt-get -y upgrade
}

# ==== CO-PILOT BASE ====

setup_copilot_env() {
    if grep -q "COPILOT_PROFILE_CONFIG_DIRECTORY" /etc/environment
    then
        echo "Copilot environment already configured. Skipping..."
    else
        # Create global environment variable for copilot to use
        echo "COPILOT_PROFILE_CONFIG_DIRECTORY=${COPILOT_PROFILE_CONFIG_DIRECTORY}" >> /etc/environment
        echo "COPILOT_TEMPORARY_CONFIG_DIRECTORY=${COPILOT_TEMPORARY_CONFIG_DIRECTORY}" >> /etc/environment
        echo "COPILOT_DEFAULT_CONFIG_DIRECTORY=${COPILOT_DEFAULT_CONFIG_DIRECTORY}" >> /etc/environment
    fi
}

# ==== FLASK ====

setup_flask_env() {
    # # Get rid of the application root in the bp_config
    # sed -i '/^APPLICATION_ROOT.*/d' $COPILOT_DIR/instance/bp_config.py
    set RANDFILE="/tmp/.rnd"

    if grep -q "CSRF_SESSION_KEY" $COPILOT_DIR/instance/config.py
    then
        # Add a random CSRF session key.
        local CSRF=$(openssl rand -base64 32)
        sed -i "s@^\(CSRF_SESSION_KEY\s=\s\).*\$@\1\"${CSRF}\"@" $COPILOT_DIR/instance/config.py
        sed -i "s@^\(CSRF_SESSION_KEY\s=\s\).*\$@\1\"${CSRF}\"@" $COPILOT_DIR/instance/bp_config.py
    else
        echo "Random copilot CSRF secret already set. Skipping..."
    fi

    if grep -q "SECRET_KEY" $COPILOT_DIR/instance/config.py
    then
        # Add a random secret key for signing cookies
        local SECRET=$(openssl rand -base64 32)
        sed -i "s@^\(SECRET_KEY\s=\s\).*\$@\1\"${SECRET}\"@" $COPILOT_DIR/instance/config.py
        sed -i "s@^\(SECRET_KEY\s=\s\).*\$@\1\"${SECRET}\"@" $COPILOT_DIR/instance/bp_config.py
    else
        echo "Random copilot secret key already set. Skipping..."
    fi
}

# ==== WSGI ====

setup_nginx() {
    if [[ -a "/etc/nginx/sites-enabled/default" ]]
    then
        rm /etc/nginx/sites-enabled/default
        #service nginx start
        cp  $COPILOT_DIR/templates/nginx_sites /etc/nginx/sites-available/copilot
        ln -s /etc/nginx/sites-available/copilot /etc/nginx/sites-enabled/copilot
        #enable
        update-rc.d nginx enable
        #service nginx restart
    else
        echo "Nginx already setup. Skipping..."
    fi
}

setup_supervisor() {
    if grep -q "PLUGIN_DIR_REPLACE_STRING" /etc/supervisor/conf.d/supervisord.conf
    then
        echo "Supervisor already setup. Skipping...."
    else
        mkdir -p /etc/supervisor/conf.d/
        # replace the various environment variables with the actual value of the vars
        # Using @ as the sed seperator so that we don't get errors when using double quotes
        cat $COPILOT_DIR/templates/supervisor \
            | sed "s@PLUGIN_DIR_REPLACE_STRING@${COPILOT_PLUGINS_DIRECTORY}@" \
            | sed "s@COPILOT_PROFILE_DIR_REPLACE_STRING@${COPILOT_PROFILE_CONFIG_DIRECTORY}@" \
            | sed "s@COPILOT_TEMP_DIR_REPLACE_STRING@${COPILOT_TEMPORARY_CONFIG_DIRECTORY}@" \
            | sed "s@COPILOT_DEFAULT_DIR_REPLACE_STRING@${COPILOT_DEFAULT_CONFIG_DIRECTORY}@" \
                  > /etc/supervisor/conf.d/supervisord.conf
        #enable
        update-rc.d supervisor enable
    fi
}

# ==== AVAHI ====

setup_avahi() {
    update-rc.d avahi-daemon enable
    #service avahi-daemon restart
}

# ==== PLUGINS ====

install_plugins() {
    echo "Installing plugins."

    if grep -q "COPILOT_PLUGINS_DIRECTORY" /etc/environment
    then
        echo "Plugins already added to environment. Skipping..."
    else
        # Create global environment variable for copilot to use
        echo "COPILOT_PLUGINS_DIRECTORY=${COPILOT_PLUGINS_DIRECTORY}" >> /etc/environment
    fi

    cd "${COPILOT_PLUGINS_DIRECTORY}"
    cd plugins

    for path in "${COPILOT_PLUGINS_DIRECTORY}"plugins/*; do
        [ -d "${path}" ] || continue # if not a directory, skip
        dirname="$(basename "${path}")"
        echo "Beginning install of plugin $dirname"
        # Run installation script
        if [ -a "${path}"/install ]; then
            "$path"/install
        fi
        # Add supervisor configs to supervisor
        if [ -a "$path"/supervisor.conf ]; then
            # replace COPILOT_PLUGINS_DIRECTORY with the actual value of the var
            # Using @ as the sed seperator so that we don't get errors when using double quotes
            cat "$path"/supervisor.conf \
                | sed "s@COPILOT_PLUGINS_DIRECTORY@${COPILOT_PLUGINS_DIRECTORY}@" \
                >> /etc/supervisor/conf.d/supervisord.conf
        fi
        echo "Plugin $dirname installed"
    done
    echo "All plugins installed"
}

dependencies() {
    # Lack of entropy slows installing massively
    apt-get install -y haveged
    # Nothing works if the time is way off
    apt-get install -y ntp
    ntpd -gq || true
    # service ntp enable
    #service ntp start
    # CoPilot Dependencies
    # usbmount auto-mounts usb sticks
    apt-get -y install usbmount
    # Install Flask dependencies
    apt-get -y install python-dev
    apt-get -y install curl
    apt-get -y install python-pysqlite2
    apt-get -y install python-pip
    export PATH="/usr/local/bin:$PATH"
    # Bcrypt Dependencies
    apt-get -y install build-essential
    apt-get -y install libssl-dev
    apt-get -y install libffi-dev
    # general plugin dependencies
    apt-get -y install git
}

install() {
    #create setup directory
    mkdir -p $SETUP_DIR
    #Create website Directory
    mkdir -p $WEB_DIR
    setup_copilot_env
    setup_flask_env
    # Avahi
    apt-get -y install avahi-daemon
    # WSGI
    apt-get -y install nginx supervisor
    # python-pip requirements
    # Upgrade is required to get setuptools upgraded
    pip install --upgrade -r $COPILOT_DIR/requirements.txt
}

setup() {
    setup_avahi
    # WSGI
    setup_nginx
    setup_supervisor
}

initial() {
    update_os
    dependencies
    install
    setup
    cd $COPILOT_DIR
    install_plugins
}

#Put here your initialization sentences
echo "This is the first boot. Installing Copilot"
cd /home/www/copilot
initial
echo "Installation Complete!"
exit
