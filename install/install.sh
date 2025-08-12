#!/bin/bash

# Script de instalação para Sistema de Scanner Raspberry Pi
# Execute com: sudo bash install.sh

set -e

echo "=========================================="
echo "Instalação do Sistema de Scanner Raspberry Pi"
echo "=========================================="

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script deve ser executado como root (sudo)"
    exit 1
fi

# Verificar se é Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "⚠️  Este script é destinado para Raspberry Pi"
    read -p "Continuar mesmo assim? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Atualizar sistema
echo "🔄 Atualizando sistema..."
apt update && apt upgrade -y

# Instalar dependências do sistema
echo "📦 Instalando dependências do sistema..."
apt install -y \
    python3 \
    python3-pip \
    python3-tk \
    python3-dev \
    git \
    curl \
    wget

# Verificar e instalar network-manager
echo "🌐 Configurando gerenciamento de rede..."
if command -v apt &> /dev/null; then
    # Debian/Ubuntu/Raspberry Pi OS
    apt install -y network-manager
elif command -v yum &> /dev/null; then
    # CentOS/RHEL/Fedora
    yum install -y NetworkManager
elif command -v dnf &> /dev/null; then
    # Fedora mais recente
    dnf install -y NetworkManager
elif command -v pacman &> /dev/null; then
    # Arch Linux
    pacman -S --noconfirm networkmanager
else
    echo "⚠️  Gerenciador de pacotes não reconhecido. Instale network-manager manualmente."
fi

# Verificar se nmcli está disponível
if ! command -v nmcli &> /dev/null; then
    echo "⚠️  nmcli não encontrado. Tentando instalar network-manager-cli..."
    if command -v apt &> /dev/null; then
        apt install -y network-manager-cli
    elif command -v yum &> /dev/null; then
        yum install -y NetworkManager-cli
    elif command -v dnf &> /dev/null; then
        dnf install -y NetworkManager-cli
    elif command -v pacman &> /dev/null; then
        pacman -S --noconfirm networkmanager
    fi
fi

# Verificar se hwclock está disponível
if ! command -v hwclock &> /dev/null; then
    echo "⚠️  hwclock não encontrado. Tentando instalar util-linux..."
    if command -v apt &> /dev/null; then
        apt install -y util-linux
    elif command -v yum &> /dev/null; then
        yum install -y util-linux
    elif command -v dnf &> /dev/null; then
        dnf install -y util-linux
    elif command -v pacman &> /dev/null; then
        pacman -S --noconfirm util-linux
    fi
fi

# Instalar outras dependências
echo "📦 Instalando outras dependências..."
if command -v apt &> /dev/null; then
    # Debian/Ubuntu/Raspberry Pi OS
    apt install -y ntpdate wmctrl
elif command -v yum &> /dev/null; then
    # CentOS/RHEL/Fedora
    yum install -y ntpdate wmctrl
elif command -v dnf &> /dev/null; then
    # Fedora mais recente
    dnf install -y ntpdate wmctrl
elif command -v pacman &> /dev/null; then
    # Arch Linux
    pacman -S --noconfirm ntp wmctrl
fi

# Verificar se as ferramentas essenciais estão disponíveis
echo "🔍 Verificando ferramentas essenciais..."

# Verificar nmcli
if command -v nmcli &> /dev/null; then
    echo "✅ nmcli encontrado"
else
    echo "⚠️  nmcli não disponível. Algumas funcionalidades de rede podem não funcionar."
fi

# Verificar hwclock
if command -v hwclock &> /dev/null; then
    echo "✅ hwclock encontrado"
else
    echo "⚠️  hwclock não disponível. Sincronização de hardware clock não funcionará."
fi

# Verificar ntpdate
if command -v ntpdate &> /dev/null; then
    echo "✅ ntpdate encontrado"
else
    echo "⚠️  ntpdate não disponível. Sincronização NTP pode não funcionar."
fi

# Verificar wmctrl
if command -v wmctrl &> /dev/null; then
    echo "✅ wmctrl encontrado"
else
    echo "⚠️  wmctrl não disponível. Controle de janelas pode ser limitado."
fi

# Instalar dependências Python
echo "🐍 Instalando dependências Python..."
pip3 install --upgrade pip

# Lista de dependências Python com versões específicas
PYTHON_DEPS=(
    "customtkinter==5.2.2"
    "requests==2.31.0"
    "APScheduler==3.10.4"
    "python-dateutil==2.8.2"
    "psutil==5.9.6"
    "pynput==1.7.6"
)

# Tentar instalar evdev (pode falhar em alguns sistemas)
echo "📱 Tentando instalar evdev..."
if pip3 install evdev==1.6.1; then
    echo "✅ evdev instalado com sucesso"
else
    echo "⚠️  evdev não pôde ser instalado. Usando fallback."
    # Adicionar dependência alternativa
    PYTHON_DEPS+=("pynput==1.7.6")
fi

# Tentar instalar netifaces (pode falhar em alguns sistemas)
echo "🌐 Tentando instalar netifaces..."
if pip3 install netifaces==0.11.0; then
    echo "✅ netifaces instalado com sucesso"
else
    echo "⚠️  netifaces não pôde ser instalado. Usando alternativas do sistema."
fi

# Instalar outras dependências Python
for dep in "${PYTHON_DEPS[@]}"; do
    echo "📦 Instalando $dep..."
    if pip3 install "$dep"; then
        echo "✅ $dep instalado"
    else
        echo "⚠️  Falha ao instalar $dep"
    fi
done

# Configurar permissões para dispositivos de entrada
echo "🔐 Configurando permissões..."
usermod -a -G input $SUDO_USER 2>/dev/null || echo "⚠️  Não foi possível adicionar usuário ao grupo input"
usermod -a -G dialout $SUDO_USER 2>/dev/null || echo "⚠️  Não foi possível adicionar usuário ao grupo dialout"

# Criar diretórios necessários
echo "📁 Criando diretórios..."
mkdir -p /opt/scanner-system/{data,logs,config,backups}
chown -R $SUDO_USER:$SUDO_USER /opt/scanner-system

# Configurar NetworkManager
echo "🌐 Configurando NetworkManager..."
if command -v systemctl &> /dev/null; then
    systemctl enable NetworkManager 2>/dev/null || echo "⚠️  Não foi possível habilitar NetworkManager"
    systemctl start NetworkManager 2>/dev/null || echo "⚠️  Não foi possível iniciar NetworkManager"
else
    echo "⚠️  systemctl não disponível. Configure NetworkManager manualmente."
fi

# Configurar NTP
echo "🕐 Configurando NTP..."
if command -v systemctl &> /dev/null; then
    systemctl enable systemd-timesyncd 2>/dev/null || echo "⚠️  Não foi possível habilitar systemd-timesyncd"
    systemctl start systemd-timesyncd 2>/dev/null || echo "⚠️  Não foi possível iniciar systemd-timesyncd"
else
    echo "⚠️  systemctl não disponível. Configure NTP manualmente."
fi

# Configurar serviço systemd
echo "⚙️  Configurando serviço systemd..."
if command -v systemctl &> /dev/null; then
    cat > /etc/systemd/system/scanner-system.service << EOF
[Unit]
Description=Sistema de Scanner Raspberry Pi
After=network.target

[Service]
Type=simple
User=$SUDO_USER
Group=$SUDO_USER
WorkingDirectory=/opt/scanner-system
ExecStart=/usr/bin/python3 /opt/scanner-system/src/app.py
Restart=always
RestartSec=10
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SUDO_USER/.Xauthority

[Install]
WantedBy=multi-user.target
EOF

    # Habilitar serviço
    systemctl daemon-reload
    systemctl enable scanner-system.service
    
    echo "✅ Serviço systemd configurado e habilitado"
else
    echo "⚠️  systemctl não disponível. Configure o serviço manualmente."
fi

# Configurar autostart do X11
echo "🖥️  Configurando autostart do X11..."
if [ -f /etc/xdg/lxsession/LXDE-pi/autostart ]; then
    echo "@python3 /opt/scanner-system/src/app.py" >> /etc/xdg/lxsession/LXDE-pi/autostart
    echo "✅ Autostart LXDE configurado"
elif [ -f /etc/xdg/lxsession/LXDE/autostart ]; then
    echo "@python3 /opt/scanner-system/src/app.py" >> /etc/xdg/lxsession/LXDE/autostart
    echo "✅ Autostart LXDE configurado"
elif [ -f ~/.config/autostart ]; then
    mkdir -p ~/.config/autostart
    cat > ~/.config/autostart/scanner-system.desktop << EOF
[Desktop Entry]
Type=Application
Name=Sistema de Scanner
Comment=Sistema de Scanner Raspberry Pi
Exec=python3 /opt/scanner-system/src/app.py
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
    echo "✅ Autostart genérico configurado"
else
    echo "⚠️  Não foi possível configurar autostart. Configure manualmente."
fi

# Configurar permissões de sudo para comandos específicos
echo "🔓 Configurando permissões sudo..."
cat > /etc/sudoers.d/scanner-system << EOF
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/date
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/timedatectl
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/ntpdate
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/nmcli
EOF

# Adicionar hwclock se disponível
if command -v hwclock &> /dev/null; then
    echo "$SUDO_USER ALL=(ALL) NOPASSWD: /usr/sbin/hwclock" >> /etc/sudoers.d/scanner-system
fi

echo "✅ Permissões sudo configuradas"

# Configurar firewall (se disponível)
echo "🔥 Configurando firewall..."
if command -v ufw &> /dev/null; then
    ufw --force enable
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo "✅ Firewall UFW configurado"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --reload
    echo "✅ Firewall firewalld configurado"
else
    echo "⚠️  Firewall não encontrado. Configure manualmente se necessário."
fi

# Configurar swap (se necessário)
echo "💾 Configurando swap..."
if [ ! -f /swapfile ]; then
    if command -v fallocate &> /dev/null; then
        fallocate -l 1G /swapfile
    elif command -v dd &> /dev/null; then
        dd if=/dev/zero of=/swapfile bs=1M count=1024
    else
        echo "⚠️  Não foi possível criar arquivo de swap. Crie manualmente."
    fi
    
    if [ -f /swapfile ]; then
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        echo "✅ Swap configurado"
    fi
else
    echo "✅ Swap já configurado"
fi

# Configurar otimizações do sistema
echo "⚡ Configurando otimizações..."
if [ -f /boot/config.txt ]; then
    # Raspberry Pi
    cat >> /boot/config.txt << EOF

# Otimizações para sistema de scanner
gpu_mem=128
max_usb_current=1
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=4
EOF
    echo "✅ Otimizações Raspberry Pi configuradas"
elif [ -f /etc/default/grub ]; then
    # Outros sistemas Linux
    echo "⚠️  Otimizações específicas do sistema não configuradas. Configure manualmente se necessário."
fi

# Configurar cron para manutenção
echo "⏰ Configurando cron..."
cat > /etc/cron.daily/scanner-maintenance << EOF
#!/bin/bash
# Manutenção diária do sistema de scanner

# Limpar logs antigos
find /opt/scanner-system/logs -name "*.log.*" -mtime +7 -delete 2>/dev/null || true

# Verificar espaço em disco
df -h | grep -E '^/dev/' | awk '\$5 > "90%" {print "ALERTA: Disco quase cheio - " \$0}' | logger 2>/dev/null || true

# Verificar serviços
if command -v systemctl &> /dev/null; then
    systemctl is-active --quiet scanner-system.service || systemctl restart scanner-system.service
fi
EOF

chmod +x /etc/cron.daily/scanner-maintenance
echo "✅ Cron de manutenção configurado"

# Configurar logrotate
echo "📝 Configurando rotação de logs..."
cat > /etc/logrotate.d/scanner-system << EOF
/opt/scanner-system/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $SUDO_USER $SUDO_USER
    postrotate
        if command -v systemctl &> /dev/null; then
            systemctl reload scanner-system.service > /dev/null 2>&1 || true
        fi
    endscript
}
EOF

echo "✅ Logrotate configurado"

# Configurar monitoramento de temperatura (apenas Raspberry Pi)
echo "🌡️  Configurando monitoramento de temperatura..."
if grep -q "Raspberry Pi" /proc/cpuinfo; then
    cat > /etc/cron.hourly/temp-monitor << EOF
#!/bin/bash
# Monitoramento de temperatura do Raspberry Pi

if command -v vcgencmd &> /dev/null; then
    TEMP=\$(vcgencmd measure_temp | cut -d'=' -f2 | cut -d"'" -f1)
    echo "\$(date): Temperatura: \${TEMP}°C" >> /opt/scanner-system/logs/temperature.log
    
    # Alerta se temperatura > 80°C
    if (( \$(echo "\$TEMP > 80" | bc -l 2>/dev/null || echo "0") )); then
        echo "ALERTA: Temperatura alta: \${TEMP}°C" | logger
    fi
fi
EOF
    chmod +x /etc/cron.hourly/temp-monitor
    echo "✅ Monitoramento de temperatura configurado"
else
    echo "⚠️  Monitoramento de temperatura não configurado (não é Raspberry Pi)"
fi

# Configurar backup automático
echo "💾 Configurando backup automático..."
cat > /etc/cron.daily/scanner-backup << EOF
#!/bin/bash
# Backup automático dos dados do scanner

BACKUP_DIR="/opt/scanner-system/backups"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

# Backup dos dados
tar -czf \$BACKUP_DIR/scanner-data_\$DATE.tar.gz -C /opt/scanner-system data config 2>/dev/null || true

# Manter apenas últimos 7 backups
ls -t \$BACKUP_DIR/scanner-data_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm 2>/dev/null || true
EOF

chmod +x /etc/cron.daily/scanner-backup
echo "✅ Backup automático configurado"

# Configurar notificações de erro
echo "🔔 Configurando notificações..."
if [ -f /etc/rsyslog.conf ]; then
    cat > /etc/rsyslog.d/scanner-alerts.conf << EOF
# Alertas do sistema de scanner
if \$programname == 'scanner-system' and (\$msg contains 'ERROR' or \$msg contains 'CRITICAL') then {
    /var/log/scanner-alerts.log
    stop
}
EOF

    # Reiniciar rsyslog se disponível
    if command -v systemctl &> /dev/null; then
        systemctl restart rsyslog 2>/dev/null || echo "⚠️  Não foi possível reiniciar rsyslog"
    fi
    echo "✅ Notificações configuradas"
else
    echo "⚠️  rsyslog não encontrado. Notificações não configuradas."
fi

echo "=========================================="
echo "✅ Instalação concluída com sucesso!"
echo "=========================================="
echo ""
echo "📋 Próximos passos:"
echo "1. Reinicie o Raspberry Pi: sudo reboot"
echo "2. Configure a rede Wi-Fi/Ethernet"
echo "3. Ative o dispositivo com sua chave de ativação"
echo "4. O sistema iniciará automaticamente no boot"
echo ""
echo "📁 Arquivos instalados em: /opt/scanner-system"
echo "📝 Logs em: /opt/scanner-system/logs"
echo "⚙️  Serviço: scanner-system.service"
echo ""
echo "🔧 Comandos úteis:"
if command -v systemctl &> /dev/null; then
    echo "   sudo systemctl status scanner-system.service"
    echo "   sudo systemctl restart scanner-system.service"
    echo "   sudo journalctl -u scanner-system.service -f"
fi
echo ""
echo "📚 Documentação: /opt/scanner-system/README.md"
echo "=========================================="

# Criar arquivo de status da instalação
cat > /opt/scanner-system/install-status.txt << EOF
Instalação concluída em: $(date)
Usuário: $SUDO_USER
Versão: 1.0.0
Status: ✅ Sucesso
Sistema: $(uname -a)
Distribuição: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "Desconhecida")
EOF

echo "📄 Status da instalação salvo em: /opt/scanner-system/install-status.txt" 