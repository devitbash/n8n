#!/bin/bash

# Whatsapp Non Official API (Christophe Hubert) Wizard Script
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

fn_git_install(){
    echo 'Instalando GIT Server...';
    sudo apt install git -y > /dev/null 2>&1 &
    show_progress "apt" "Instalando git por medio de apt...";
}

fn_install_api(){
    git clone https://github.com/chrishubert/whatsapp-api.git
    cd whatsapp-api
    cp .env.example .env
    npm install
    npm install body-parser
}

fn_gtk_install(){
    echo 'Instalando GTK y paquetes extra...';
    sudo apt install -y libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libxcomposite1 libxrandr2 libpangocairo-1.0-0 libgtk-3-0t64 libnss3 libxss1 libgbm1 fonts-liberation libappindicator3-1 xdg-utils libasound2t64 -y > /dev/null 2>&1 &
    show_progress "apt" "Instalando gtk y paquetes extra con apt...";
}

clear;
echo "==================================="
echo "  Whatsapp API (Christophe Hubert) Non Oficial Wizard v.0.0.1"
echo "  Creado por: DevItBash"
echo "  Licencia: GNU GPL v3"
echo "  Encuentrame en redes como: @devitbash"
echo "==================================="

start_time=$(date +%s);
fn_git_install
fn_install_api
fn_gtk_install
end_time=$(date +%s);
elapsed_time=$(( (end_time - start_time) / 60 ));
echo '';
echo '';
echo "La instalacion ha finalizado, tu servidor esta listo para usar y solo te tomo $elapsed_time minutos ;). La automatizacion es fantastica.";

#Si es en la misma máquina:
#sudo iptables -t nat -A OUTPUT -d ${ip} -p tcp --dport 443 -j DNAT --to-destination 127.0.0.1:5678
#sudo iptables -t nat -L OUTPUT -n --line-numbers
#sudo iptables -t nat -D OUTPUT <número>