#!/bin/bash

# Script rápido para configurar autostart sem login
# Execute com: sudo bash quick_autostart.sh

echo "🚀 Configuração Rápida de Autostart Sem Login"
echo "=============================================="

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute com sudo: sudo bash quick_autostart.sh"
    exit 1
fi

echo "🔧 Configurando autostart automático..."

# 1. Configurar auto-login no LXDE (Raspberry Pi OS)
echo "👤 Configurando auto-login..."
if [ -f /etc/lxdm/lxdm.conf ]; then
    # Backup
    cp /etc/lxdm/lxdm.conf /etc/lxdm/lxdm.conf.backup.$(date +%Y%m%d_%H%M%S)
    
    # Configurar auto-login
    sed -i 's/# autologin=.*/autologin='$SUDO_USER'/' /etc/lxdm/lxdm.conf
    sed -i 's/# timeout=.*/timeout=0/' /etc/lxdm/lxdm.conf
    echo "✅ Auto-login LXDM configurado"
else
    echo "⚠️  LXDM não encontrado, configurando alternativas..."
fi

# 2. Configurar autostart da aplicação
echo "🚀 Configurando autostart da aplicação..."

# Criar diretórios de autostart
mkdir -p /etc/xdg/lxsession/LXDE-pi/autostart
mkdir -p /etc/xdg/lxsession/LXDE/autostart
mkdir -p /home/$SUDO_USER/.config/autostart

# Configurar autostart no LXDE
cat > /etc/xdg/lxsession/LXDE-pi/autostart/scanner-system << EOF
@python3 /opt/scanner-system/src/app.py
EOF

cat > /etc/xdg/lxsession/LXDE/autostart/scanner-system << EOF
@python3 /opt/scanner-system/src/app.py
EOF

# Configurar autostart do usuário
cat > /home/$SUDO_USER/.config/autostart/scanner-system.desktop << EOF
[Desktop Entry]
Type=Application
Name=Sistema de Scanner
Comment=Sistema de Scanner Raspberry Pi
Exec=python3 /opt/scanner-system/src/app.py
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
EOF

echo "✅ Autostart configurado"

# 3. Configurar execução no .bashrc
echo "📝 Configurando execução automática..."
if ! grep -q "scanner-system" /home/$SUDO_USER/.bashrc; then
    cat >> /home/$SUDO_USER/.bashrc << EOF

# Auto-executar sistema de scanner
if [ -n "\$DISPLAY" ]; then
    sleep 3
    if ! pgrep -f "scanner-system" > /dev/null; then
        if [ -f "/opt/scanner-system/src/app.py" ]; then
            cd /opt/scanner-system
            python3 src/app.py &
        fi
    fi
fi
EOF
    echo "✅ Execução automática configurada no .bashrc"
fi

# 4. Configurar permissões
echo "🔐 Configurando permissões..."
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.bashrc

# 5. Configurar para iniciar em modo gráfico
echo "🖥️  Configurando modo gráfico..."
if [ -f /etc/default/raspi-config ]; then
    sed -i 's/BOOT_TO_CLI=1/BOOT_TO_CLI=0/' /etc/default/raspi-config 2>/dev/null || true
    echo "✅ Modo gráfico configurado"
fi

# 6. Configurar boot silencioso
echo "🔇 Configurando boot silencioso..."
if [ -f /boot/cmdline.txt ]; then
    if ! grep -q "quiet" /boot/cmdline.txt; then
        echo " quiet" >> /boot/cmdline.txt
        echo "✅ Boot silencioso configurado"
    fi
    if ! grep -q "logo.nologo" /boot/cmdline.txt; then
        echo " logo.nologo" >> /boot/cmdline.txt
        echo "✅ Logo removido do boot"
    fi
fi

# 7. Criar script de execução imediata
echo "📋 Criando script de execução imediata..."
cat > /opt/scanner-system/start_app.sh << EOF
#!/bin/bash
# Script para iniciar aplicação imediatamente

cd /opt/scanner-system

# Aguardar sistema carregar
sleep 2

# Executar aplicação
if [ -f "src/app.py" ]; then
    python3 src/app.py
else
    echo "Erro: Aplicação não encontrada"
    exit 1
fi
EOF

chmod +x /opt/scanner-system/start_app.sh
chown $SUDO_USER:$SUDO_USER /opt/scanner-system/start_app.sh

# 8. Configurar serviço systemd simples
echo "⚙️  Configurando serviço systemd..."
if command -v systemctl &> /dev/null; then
    cat > /etc/systemd/system/scanner-app.service << EOF
[Unit]
Description=Scanner Application
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$SUDO_USER
Group=$SUDO_USER
WorkingDirectory=/opt/scanner-system
ExecStart=/opt/scanner-system/start_app.sh
Restart=always
RestartSec=10
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SUDO_USER/.Xauthority

[Install]
WantedBy=graphical-session.target
EOF

    systemctl daemon-reload
    systemctl enable scanner-app.service
    echo "✅ Serviço systemd configurado"
fi

echo "=========================================="
echo "✅ Configuração rápida concluída!"
echo "=========================================="
echo ""
echo "📋 O que foi configurado:"
echo "✅ Auto-login automático"
echo "✅ Autostart da aplicação Tkinter"
echo "✅ Execução automática no .bashrc"
echo "✅ Modo gráfico habilitado"
echo "✅ Boot silencioso"
echo "✅ Serviço systemd habilitado"
echo ""
echo "🔄 Para aplicar:"
echo "1. Reinicie: sudo reboot"
echo "2. A aplicação deve aparecer automaticamente"
echo ""
echo "🔧 Verificar status:"
echo "   sudo systemctl status scanner-app.service"
echo "   journalctl -u scanner-app.service -f"
echo ""
echo "⚠️  Se não funcionar, use o script completo:"
echo "   sudo bash install/autostart_config.sh"
echo "=========================================="

# Criar arquivo de status
cat > /opt/scanner-system/quick-autostart-status.txt << EOF
Configuração rápida concluída em: $(date)
Usuário: $SUDO_USER
Status: ✅ Configurado (Rápido)
EOF

echo "📄 Status salvo em: /opt/scanner-system/quick-autostart-status.txt" 