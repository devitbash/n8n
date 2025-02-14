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
NGINX_SITES_ENABLED='/etc/nginx/sites-enabled/';
INVOKER=$(whoami | tr -d '\n');

if [ -z $2 ]; then
    DOMAIN='your-domain.com';
else
    DOMAIN=$2;
    if [ -z $3 ]; then
        echo "el parametro email es requerido!"
    else
        EMAIL=$3;
    fi
fi;

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
        return 0
    else
        echo "No fue posible instalar Node."
        exit 1;
    fi
}

fn_db_install(){
    echo 'Instalando base de datos SQLite...';
    npm install sqlite3 --save
}

fn_nginx_install(){
    sudo apt install -y nginx > /dev/null 2>&1 &
    show_progress "apt" "Instalando Nginx Server...";
}

fn_server_install(){
    echo 'Instalando N8N Server...';

    NODE_VER=$(node --version | tr -d '\n');

    if [ -d "/root/.nvm/versions/node/${NODE_VER}/lib/node_modules/n8n" ]; then
        echo "La carpeta de la instalacion global de n8n ya existe."
        read -p "Desea eliminarla antes de continuar? (s/n): " respuesta </dev/tty

        if [[ "$respuesta" =~ ^[Ss]$ ]]; then
            rm -rf "/root/.nvm/versions/node/${NODE_VER}/lib/node_modules/n8n" > /dev/null 2>&1 &
            show_progress "rm" "Eliminando carpeta...";
        else
            echo "No se puede continuar, por favor elimine el directorio de instalacion global de n8n"
            echo "Luego intente nuevamente o ejecute este asistente en una instalacion nueva"
            exit 1
        fi
    fi

    pnpm add -g n8n --verbose

}

fn_server_update(){
    pnpm update -g n8n;
}

fn_ssl_generate(){
    sudo mkdir -p $SSL_DIR;
    sudo chmod 700 $SSL_DIR;
    sudo openssl genpkey -algorithm RSA -out ${SSL_DIR}/private.key;
    sudo openssl req -new -key ${SSL_DIR}/private.key -out ${SSL_DIR}/csr.pem -subj "/C=CO/ST=Estado/L=Ciudad/O=MiEmpresa/OU=MiUnidad/CN=mi-dominio.com";
    sudo openssl x509 -req -in ${SSL_DIR}/csr.pem -signkey ${SSL_DIR}/private.key -out ${SSL_DIR}/certificate.pem;
    sudo chown $INVOKER:$INVOKER ${SSL_DIR}/csr.pem ${SSL_DIR}/certificate.pem
    sudo chmod +x ${SSL_DIR}
    sudo chmod 640 ${SSL_DIR}/private.key
    sudo chmod 640 ${SSL_DIR}/csr.pem
    sudo chmod 644 ${SSL_DIR}/certificate.pem
}

fn_nginx_config(){
    echo "Creando la configuracion del sitio para Nginx..."
    if [ ! -f "/etc/nginx/sites-available/n8n" ]; then
        echo "server {
            listen 80;
            server_name ${DOMAIN};

            location / {
                proxy_pass http://localhost:5678;
                proxy_http_version 1.1;
                chunked_transfer_encoding off;
                proxy_buffering off;
                proxy_cache off;
                proxy_set_header Connection 'Upgrade';
                proxy_set_header Upgrade \$http_upgrade;
            }
        }" | sudo tee /etc/nginx/sites-available/n8n > /dev/null;
    else
        echo "El sitio de n8n para Nginx ya existe";
    fi
    if [ $? -eq 0 ]; then
        echo "Habilitando el sitio de n8n en Nginx...";
        sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/;
        echo "Validando el archivo de configuracion del sitio...";
        sudo nginx -t;
        [ $? -eq 0 ] && return 0 || exit 1;
    else
        echo "No fue posible instalar Node."
        exit 1;
    fi
}

fn_certbot_install(){
    sudo apt install -y certbot python3-certbot-nginx > /dev/null 2>&1 &
    show_progress "apt" "Installando Certbot...";
    if [ $? -eq 0 ]; then
        echo "Generando certificado SSL..."
        sudo certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email ${EMAIL} --redirect;
        return 0
    else
        echo "No fue posible generar el certificado SSL para el dominio ${DOMAIN}"
        exit 1;
    fi
    echo "Reiniciando servidor Nginx..."
    sudo systemctl restart nginx
}

fn_service_create(){
    echo "[Unit]
Description=n8n Workflow Automation
After=network.target

[Service]
Environment=\"N8N_PROTOCOL=https\"
Environment=\"N8N_SSL_CERT=/etc/ssl/n8n/certificate.pem\"
Environment=\"N8N_SSL_KEY=/etc/ssl/n8n/private.key\"
Environment=\"WEBHOOK_URL=https://159.112.183.169:5678\"
Environment=\"PATH=/home/$INVOKER/.nvm/versions/node/v22.13.1/bin:/home/$INVOKER/.local/share/pnpm:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"
ExecStart=/home/$INVOKER/.local/share/pnpm/n8n start
Restart=always
User=$INVOKER
Group=$INVOKER
WorkingDirectory=/home/$INVOKER
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$INVOKER

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/n8n.service > /dev/null;
}

fn_install_full(){
    start_time=$(date +%s);

    sudo apt update -y > /dev/null 2>&1 &
    show_progress "apt" "Actualizando el sistema con apt...";

    fn_node_install;
    [ $? -eq 0 ] && fn_db_install || { echo 'Error instalando node'; exit 1; }    
    [ $? -eq 0 ] && fn_server_install || { echo 'Error instalando sqlite'; exit 1; }

    if [ ! -z $2 ]; then
        fn_nginx_install
        [ $? -eq 0 ] && fn_nginx_config || { echo 'Error instalando Nginx'; exit 1; }
        [ $? -eq 0 ] && fn_certbot_install || { echo 'Error configurando nginx'; exit 1; }
        [ $? -ne 0 ] && sudo systemctl restart nginx || { echo 'Error en certbot'; exit 1; }
    else
        [ $? -eq 0 ] && fn_ssl_generate || { echo 'Error instalando n8n'; exit 1; }
        [ $? -ne 0 ] && { echo 'error generando certificados'; exit 1; }
        fn_service_create
        [ $? -eq 0 ] && { sudo systemctl daemon-reload; sudo systemctl enable --now n8n; } || { echo 'Error creando servicio'; exit 1; }
    fi

    echo "Aplicando configuraciones finales"

    sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 5678 -j ACCEPT
    sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 5678
    sudo netfilter-persistent save

    end_time=$(date +%s);

    elapsed_time=$(( (end_time - start_time) / 60 ));
    echo '';
    echo '';
    echo "La instalacion ha finalizado, tu servidor esta listo para usar y solo te tomo $elapsed_time minutos ;). La automatizacion es fantastica.";
    [ -z $2 ] && { echo 'Para ver el estado del servicio: sudo systemctl status n8n'; }
}

clear;
echo "==================================="
echo "  N8N Wizard v.0.0.1"
echo "  Creado por: DevItBash"
echo "  Licencia: GNU GPL v3"
echo "  Encuentrame en redes como: @devitbash"
echo "==================================="

case $1 in
    install)
        fn_install_full;
        ;;
    'install-node')
        fn_node_install;
    ;;
    'install-sqlite')
        fn_db_install;
    ;;
    'ssl-self')
        fn_ssl_generate;
    ;;
    'service-create')
        fn_service_create
        [ $? -eq 0 ] && { echo 'Servicio creado'; sudo systemctl daemon-reload; sudo systemctl enable --now n8n; } || { echo 'Error creando servicio'; exit 1; }
        echo 'Para ver el estado del servicio: sudo systemctl status n8n';
    ;;
    update)
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
        echo "  domain    Tu dominio, requerido para la generacion del ssl con cerbot"
        echo "  email     Tu email, requerido para la generacion del ssl con certbot"
        exit 0
    ;;
esac