#!/bin/bash

# N8N Wizard Script
#
# Copyright (C) 2025 - Author: DevItBash
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# wget https://raw.githubusercontent.com/devitbash/n8n/main/wizard.sh


NODE_VERSION=22;
SSL_DIR='/etc/ssl/n8n';
LETS_ENC_LIVE_DIR='/etc/letsencrypt/live';
INVOKER=$(whoami | tr -d '\n');

if [ -z $2 ]; then
    DOMAIN='localhost';
else
    DOMAIN=$2;
    if [ -z $3 ]; then
        echo "el parametro email es requerido!"
    else
        EMAIL=$3;
    fi
fi

show_progress() {
    sleep 1;
    process_name="$1"
    process_label="$2"
    percentage=0
    filled=$(( percentage / 2 ))
    empty=$(( 50 - filled ))

    echo '';
    echo $process_label;
    echo '';

    while pidof $process_name >/dev/null; do
        if [ $percentage -lt 99 ]; then
            percentage=$((percentage + 1))
        fi

        filled=$(( percentage / 2 ))
        empty=$(( 50 - filled ))

        bar="["
        for i in $(seq 1 $filled); do
            bar="$bar#"
        done
        for i in $(seq 1 $empty); do
            bar="$bar-"
        done
        bar="$bar]"

        tput cuu1;
        tput el;
        echo "$bar $percentage%"
        sleep 1
    done

    bar="["
    for i in $(seq 1 50); do
        bar="$bar#"
    done
    bar="$bar]"
    tput cuu1;
    tput el;
    echo "$bar 100%"
    echo "Completado!"
}

fn_node_install(){
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash > /dev/null 2>&1 &
    show_progress "curl" "Instalando Node por medio de NVM...";

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

    nvm install $NODE_VERSION

    curl -fsSL https://get.pnpm.io/install.sh | sh -

    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    pnpm setup
    export PATH="$PNPM_HOME:$PATH"

    echo 'export NVM_DIR="$HOME/.nvm"' >> "$HOME/.bashrc"
    echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> "$HOME/.bashrc"
    echo '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"' >> "$HOME/.bashrc"

    echo 'export PNPM_HOME="$HOME/.local/share/pnpm"' >> "$HOME/.bashrc"
    echo 'export PATH="$PNPM_HOME:$PATH"' >> "$HOME/.bashrc"

    source $HOME/.bashrc

    if [ $? -eq 0 ]; then
        echo "Node version: " $(node -v)
        echo "NVM version: " $(nvm current)
        echo "PNPM version:" $(pnpm -v)
        echo "Node instalado con éxito"
        return 0
    else
        echo "No fue posible instalar Node"
        exit 1;
    fi
}

fn_db_install(){
    echo 'Instalando base de datos SQLite...';
    npm install -g sqlite3 --save
    if [ $? -eq 0 ]; then
        echo "sqlite3 instalado con éxito"
        return 0
    else
        echo "No fue posible instalar Sqlite3"
        exit 1;
    fi
}

fn_server_install(){
    echo 'Instalando N8N Server...';

    NODE_VER=$(node --version | tr -d '\n');

    if [ -d "$HOME/.nvm/versions/node/${NODE_VER}/lib/node_modules/n8n" ]; then
        echo "La carpeta de la instalacion global de n8n ya existe."
        read -p "Desea eliminarla antes de continuar? (s/n): " respuesta </dev/tty

        if [[ "$respuesta" =~ ^[Ss]$ ]]; then
            rm -rf "$HOME/.nvm/versions/node/${NODE_VER}/lib/node_modules/n8n" > /dev/null 2>&1 &
            show_progress "rm" "Eliminando carpeta...";
        else
            echo "No se puede continuar, por favor elimine el directorio de instalacion global de n8n"
            echo "Luego intente nuevamente o ejecute este asistente en una instalacion nueva"
            exit 1
        fi
    fi

    pnpm add -g n8n;
    if [ $? -eq 0 ]; then
        echo "pnpm instalado con éxito"
        return 0
    else
        echo "No fue posible instalar pnpm"
        exit 1;
    fi

}

fn_server_update(){
    echo "Creando bakcup...";
    tar --exclude="$HOME/.n8n/nodes/node_modules" -cvzf backup_$(date +"%Y%m%d%H%M%S").tar.gz $HOME/.n8n;
    echo "Actualizando N8N...";
    pnpm update -g n8n;
    if [ $? -eq 0 ]; then
        echo "Se actualizó N8N"
        return 0
    else
        echo "No fue posible actualizar N8N"
        exit 1;
    fi
}

fn_autossl_generate(){
    sudo mkdir -p $SSL_DIR;
    sudo chmod 700 $SSL_DIR;
    sudo openssl genpkey -algorithm RSA -out ${SSL_DIR}/private.key;
    sudo openssl req -new -key ${SSL_DIR}/private.key -out ${SSL_DIR}/csr.pem -subj "/C=CO/ST=Estado/L=Ciudad/O=MiEmpresa/OU=MiUnidad/CN=mi-dominio.com";
    sudo openssl x509 -req -in ${SSL_DIR}/csr.pem -signkey ${SSL_DIR}/private.key -out ${SSL_DIR}/certificate.pem;
    sudo chown $INVOKER ${SSL_DIR}/csr.pem ${SSL_DIR}/certificate.pem
    sudo chmod +x ${SSL_DIR}
    sudo chmod 640 ${SSL_DIR}/private.key
    sudo chmod 640 ${SSL_DIR}/csr.pem
    sudo chmod 644 ${SSL_DIR}/certificate.pem
}

fn_certbot_install(){
    sudo apt install -y certbot > /dev/null 2>&1 &
    show_progress "apt" "Installando Certbot...";
}

fn_ssl_generate(){
    if [ -z $DOMAIN ]; then
        echo "El dominio es requerido y no fue pasado como parámetro";
        exit 1;
    fi

    echo "Generando certificado SSL con Certbot..."
    sudo certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email $EMAIL;
}

fn_ssl_install(){
    if [ -z $DOMAIN ]; then
        echo "El dominio es requerido y no fue pasado como parámetro";
        exit 1;
    fi

    sudo cp -L $LETS_ENC_LIVE_DIR/$DOMAIN/cert.pem $SSL_DIR/certificate.pem
    sudo cp -L $LETS_ENC_LIVE_DIR/$DOMAIN/privkey.pem $SSL_DIR/private.key
    sudo cp -L $LETS_ENC_LIVE_DIR/$DOMAIN/fullchain.pem $SSL_DIR/fullchain.pem

    sudo chown $INVOKER $SSL_DIR/certificate.pem
    sudo chown $INVOKER $SSL_DIR/private.key
    
    if [ $? -eq 0 ]; then
        echo "Certificados instalados"
        return 0
    else
        echo "No fue posible mover los certificados SSL para el dominio ${DOMAIN}"
        exit 1;
    fi
}

fn_service_create(){
    NODE_VER=$(node --version | tr -d '\n');
    echo "[Unit]
Description=n8n Workflow Automation
After=network.target

[Service]
Environment=\"N8N_PROTOCOL=https\"
Environment=\"N8N_SSL_CERT=/etc/ssl/n8n/certificate.pem\"
Environment=\"N8N_SSL_KEY=/etc/ssl/n8n/private.key\"
Environment=\"WEBHOOK_URL=https://$DOMAIN\"
Environment=\"PATH=/home/$INVOKER/.nvm/versions/node/$NODE_VER/bin:/home/$INVOKER/.local/share/pnpm:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"
ExecStart=/home/$INVOKER/.local/share/pnpm/n8n start
Restart=always
User=$INVOKER
Group=sudo
WorkingDirectory=/home/$INVOKER
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$INVOKER

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/n8n.service > /dev/null;
    echo "Servicio creado."
    echo "Habilitando servicio..."
    sudo systemctl daemon-reload;
    sudo systemctl enable n8n;
}

fn_install_full(){
    start_time=$(date +%s);

    sudo apt update -y > /dev/null 2>&1 &
    show_progress "apt" "Actualizando el sistema con apt...";

    fn_node_install;
    fn_db_install;
    fn_server_install;

    if [ ! -z $2 ]; then
        fn_certbot_install;
        fn_ssl_generate;
        fn_ssl_install;
    else
        fn_autossl_generate;
    fi
    
    fn_service_create;

    source ~/.bashrc
    NODE_VER=$(node --version | tr -d '\n');
    echo "::: Aplicando configuraciones finales :::"

    sudo iptables -I INPUT -m state --state NEW -p tcp --dport 5678 -j ACCEPT
    sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 5678
    sudo netfilter-persistent save

    end_time=$(date +%s);

    elapsed_time=$(( (end_time - start_time) / 60 ));
    echo '';
    echo '';
    echo "La instalacion ha finalizado, tu servidor esta listo para usar y solo te tomo $elapsed_time minutos ;). La automatizacion es fantastica.";
    [ -z $2 ] && { echo 'Para iniciar el servicio use: sudo systemctl status n8n'; }
}

fn_patch_sqlite(){
    #npm list -g sqlite3 --depth=0
    cp -r /home/$INVOKER/.nvm/versions/node/$NODE_VER/lib/node_modules/sqlite3/build /home/$INVOKER/.local/share/pnpm/global/5/.pnpm/sqlite3\@5.1.7/node_modules/sqlite3/
}

clear;
echo "==================================="
echo "  N8N Wizard v.0.0.2"
echo "  Creado por: DevItBash"
echo "  Licencia: GNU GPL v3"
echo "  Encuentrame en redes como: @devitbash"
echo "==================================="

case $1 in
    'install')
        fn_install_full;
        ;;
    'install-node')
        fn_node_install;
    ;;
    'install-sqlite')
        fn_db_install;
    ;;
    'install-n8n')
        fn_server_install;
    ;;
    'ssl-self')
        fn_autossl_generate;
    ;;
    'install-certbot')
        fn_certbot_install;
    ;;
    'ssl-generate')
        fn_ssl_generate;
    ;;
    'ssl-install')
        fn_ssl_install;
    ;;
    'service-create')
        fn_service_create
        echo 'Para ver el estado del servicio: sudo systemctl status n8n';
    ;;
    'patch-sqlite')
        fn_patch_sqlite;
    ;;
    'update')
        fn_server_update;
        ;;
    *)
        echo "Uso: wizard.sh {install|update} [dominio] [email]"
        echo
        echo "Opciones:"
        echo "  install   Instalacion por defecto (completa)"
        echo "  Update    Actualiza a la ultima version estable de n8n"
        echo "  Backup    (aun no funciona, muy pronto disponible)"
        echo
        echo "Parameters:"
        echo "  domain    Tu dominio, requerido para la generacion del ssl con certbot"
        echo "  email     Tu email, requerido para la generacion del ssl con certbot"
        exit 0
    ;;
esac