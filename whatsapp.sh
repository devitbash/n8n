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

fn_pnpm_install(){
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

fn_git_install(){
    echo 'Instalando GIT Server...';
    sudo apt install git -y > /dev/null 2>&1 &
    show_progress "apt" "Instalando git por medio de apt...";
}

fn_install_api(){
    git clone https://github.com/chrishubert/whatsapp-api.git
    cd whatsapp-api
    pnpm install
    pnpm install body-parser
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

fn_pnpm_install
fn_git_install
fn_install_api
fn_gtk_install