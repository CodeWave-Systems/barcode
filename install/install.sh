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
    network-manager \
    nmcli \
    ntpdate \
    hwclock \
    wmctrl \
    git \
    curl \
    wget

# Instalar dependências Python
echo "🐍 Instalando dependências Python..."
pip3 install --upgrade pip
pip3 install \
    customtkinter==5.2.2 \
    requests==2.31.0 \
    APScheduler==3.10.4 \
    evdev==1.6.1 \
    python-dateutil==2.8.2 \
    psutil==5.9.6 \
    netifaces==0.11.0 \
    pynput==1.7.6

# Configurar permissões para dispositivos de entrada
echo "🔐 Configurando permissões..."
usermod -a -G input $SUDO_USER
usermod -a -G dialout $SUDO_USER

# Criar diretórios necessários
echo "📁 Criando diretórios..."
mkdir -p /opt/scanner-system/{data,logs,config}
chown -R $SUDO_USER:$SUDO_USER /opt/scanner-system

# Configurar NetworkManager
echo "🌐 Configurando NetworkManager..."
systemctl enable NetworkManager
systemctl start NetworkManager

# Configurar NTP
echo "🕐 Configurando NTP..."
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd

# Configurar serviço systemd
echo "⚙️  Configurando serviço systemd..."
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

# Configurar autostart do X11
echo "🖥️  Configurando autostart do X11..."
if [ -f /etc/xdg/lxsession/LXDE-pi/autostart ]; then
    echo "@python3 /opt/scanner-system/src/app.py" >> /etc/xdg/lxsession/LXDE-pi/autostart
fi

# Configurar permissões de sudo para comandos específicos
echo "🔓 Configurando permissões sudo..."
cat > /etc/sudoers.d/scanner-system << EOF
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/date
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/sbin/hwclock
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/timedatectl
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/ntpdate
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/nmcli
EOF

# Configurar firewall (se necessário)
echo "🔥 Configurando firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp

# Configurar swap (se necessário)
echo "💾 Configurando swap..."
if [ ! -f /swapfile ]; then
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Configurar otimizações do sistema
echo "⚡ Configurando otimizações..."
cat >> /boot/config.txt << EOF

# Otimizações para sistema de scanner
gpu_mem=128
max_usb_current=1
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=4
EOF

# Configurar cron para manutenção
echo "⏰ Configurando cron..."
cat > /etc/cron.daily/scanner-maintenance << EOF
#!/bin/bash
# Manutenção diária do sistema de scanner

# Limpar logs antigos
find /opt/scanner-system/logs -name "*.log.*" -mtime +7 -delete

# Verificar espaço em disco
df -h | grep -E '^/dev/' | awk '\$5 > "90%" {print "ALERTA: Disco quase cheio - " \$0}' | logger

# Verificar serviços
systemctl is-active --quiet scanner-system.service || systemctl restart scanner-system.service
EOF

chmod +x /etc/cron.daily/scanner-maintenance

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
        systemctl reload scanner-system.service > /dev/null 2>&1 || true
    endscript
}
EOF

# Configurar monitoramento de temperatura
echo "🌡️  Configurando monitoramento de temperatura..."
cat > /etc/cron.hourly/temp-monitor << EOF
#!/bin/bash
# Monitoramento de temperatura do Raspberry Pi

TEMP=\$(vcgencmd measure_temp | cut -d'=' -f2 | cut -d"'" -f1)
echo "\$(date): Temperatura: \${TEMP}°C" >> /opt/scanner-system/logs/temperature.log

# Alerta se temperatura > 80°C
if (( \$(echo "\$TEMP > 80" | bc -l) )); then
    echo "ALERTA: Temperatura alta: \${TEMP}°C" | logger
fi
EOF

chmod +x /etc/cron.hourly/temp-monitor

# Configurar backup automático
echo "💾 Configurando backup automático..."
cat > /etc/cron.daily/scanner-backup << EOF
#!/bin/bash
# Backup automático dos dados do scanner

BACKUP_DIR="/opt/scanner-system/backups"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

# Backup dos dados
tar -czf \$BACKUP_DIR/scanner-data_\$DATE.tar.gz -C /opt/scanner-system data config

# Manter apenas últimos 7 backups
ls -t \$BACKUP_DIR/scanner-data_*.tar.gz | tail -n +8 | xargs -r rm
EOF

chmod +x /etc/cron.daily/scanner-backup

# Configurar notificações de erro
echo "🔔 Configurando notificações..."
cat > /etc/rsyslog.d/scanner-alerts.conf << EOF
# Alertas do sistema de scanner
if \$programname == 'scanner-system' and (\$msg contains 'ERROR' or \$msg contains 'CRITICAL') then {
    /var/log/scanner-alerts.log
    stop
}
EOF

# Reiniciar rsyslog
systemctl restart rsyslog

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
echo "   sudo systemctl status scanner-system.service"
echo "   sudo systemctl restart scanner-system.service"
echo "   sudo journalctl -u scanner-system.service -f"
echo ""
echo "📚 Documentação: /opt/scanner-system/README.md"
echo "=========================================="

# Criar arquivo de status da instalação
cat > /opt/scanner-system/install-status.txt << EOF
Instalação concluída em: $(date)
Usuário: $SUDO_USER
Versão: 1.0.0
Status: ✅ Sucesso
EOF

echo "📄 Status da instalação salvo em: /opt/scanner-system/install-status.txt" 