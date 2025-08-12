#!/bin/bash

# Script específico para configurar usuário pi com autostart automático
# Execute com: sudo bash setup_pi_user.sh

echo "🍓 Configurando Autostart para Usuário PI"
echo "========================================="

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute com sudo: sudo bash setup_pi_user.sh"
    exit 1
fi

# Definir usuário como pi
PI_USER="pi"
echo "👤 Configurando para usuário: $PI_USER"

# Verificar se o usuário pi existe
if ! id "$PI_USER" &>/dev/null; then
    echo "❌ Usuário $PI_USER não existe!"
    exit 1
fi

echo "🔧 Configurando autostart automático para usuário $PI_USER..."

# 1. Configurar auto-login no LXDE
echo "🍓 Configurando auto-login LXDE..."
if [ -f /etc/lxdm/lxdm.conf ]; then
    # Backup do arquivo original
    cp /etc/lxdm/lxdm.conf /etc/lxdm/lxdm.conf.backup.$(date +%Y%m%d_%H%M%S)
    
    # Configurar auto-login
    sed -i "s/# autologin=.*/autologin=$PI_USER/" /etc/lxdm/lxdm.conf
    sed -i "s/# timeout=.*/timeout=0/" /etc/lxdm/lxdm.conf
    
    # Verificar se foi configurado
    if grep -q "autologin=$PI_USER" /etc/lxdm/lxdm.conf; then
        echo "✅ Auto-login LXDE configurado para $PI_USER"
    else
        echo "⚠️  Auto-login LXDE não configurado corretamente"
        # Adicionar manualmente se não existir
        echo "autologin=$PI_USER" >> /etc/lxdm/lxdm.conf
        echo "timeout=0" >> /etc/lxdm/lxdm.conf
        echo "✅ Auto-login LXDE adicionado manualmente"
    fi
else
    echo "⚠️  LXDE não encontrado, configurando alternativas..."
fi

# 2. Configurar autostart da aplicação
echo "🚀 Configurando autostart da aplicação..."

# Criar diretórios de autostart
mkdir -p /etc/xdg/lxsession/LXDE-pi/autostart
mkdir -p /etc/xdg/lxsession/LXDE/autostart
mkdir -p /home/$PI_USER/.config/autostart

# Configurar autostart no LXDE
cat > /etc/xdg/lxsession/LXDE-pi/autostart/scanner-system << EOF
@python3 /opt/scanner-system/src/app.py
EOF

cat > /etc/xdg/lxsession/LXDE/autostart/scanner-system << EOF
@python3 /opt/scanner-system/src/app.py
EOF

# Configurar autostart do usuário pi
cat > /home/$PI_USER/.config/autostart/scanner-system.desktop << EOF
[Desktop Entry]
Type=Application
Name=Sistema de Scanner
Comment=Sistema de Scanner Raspberry Pi
Exec=python3 /opt/scanner-system/src/app.py
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
EOF

echo "✅ Autostart configurado em múltiplos locais"

# 3. Configurar execução no .bashrc
echo "📝 Configurando execução no .bashrc..."
if ! grep -q "scanner-system" /home/$PI_USER/.bashrc; then
    cat >> /home/$PI_USER/.bashrc << EOF

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
else
    echo "✅ Execução automática já configurada no .bashrc"
fi

# 4. Configurar execução no .profile
echo "📝 Configurando execução no .profile..."
if ! grep -q "scanner-system" /home/$PI_USER/.profile; then
    cat >> /home/$PI_USER/.profile << EOF

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
    echo "✅ Execução automática configurada no .profile"
else
    echo "✅ Execução automática já configurada no .profile"
fi

# 5. Configurar execução no .xinitrc
echo "📝 Configurando execução no .xinitrc..."
if [ -f /home/$PI_USER/.xinitrc ]; then
    # Backup do arquivo original
    cp /home/$PI_USER/.xinitrc /home/$PI_USER/.xinitrc.backup.$(date +%Y%m%d_%H%M%S)
    
    # Adicionar execução da aplicação
    if ! grep -q "scanner-system" /home/$PI_USER/.xinitrc; then
        cat >> /home/$PI_USER/.xinitrc << EOF

# Executar sistema de scanner
if [ -f "/opt/scanner-system/src/app.py" ]; then
    cd /opt/scanner-system
    python3 src/app.py &
fi
EOF
        echo "✅ Execução automática configurada no .xinitrc"
    else
        echo "✅ Execução automática já configurada no .xinitrc"
    fi
else
    # Criar .xinitrc se não existir
    cat > /home/$PI_USER/.xinitrc << EOF
#!/bin/bash

# Executar sistema de scanner
if [ -f "/opt/scanner-system/src/app.py" ]; then
    cd /opt/scanner-system
    python3 src/app.py &
fi

# Executar desktop padrão
exec startx
EOF
    chmod +x /home/$PI_USER/.xinitrc
    echo "✅ .xinitrc criado com execução automática"
fi

# 6. Configurar permissões
echo "🔐 Configurando permissões..."
chown -R $PI_USER:$PI_USER /home/$PI_USER/.config
chown -R $PI_USER:$PI_USER /home/$PI_USER/.bashrc
chown -R $PI_USER:$PI_USER /home/$PI_USER/.profile
chown -R $PI_USER:$PI_USER /home/$PI_USER/.xinitrc

# 7. Configurar serviço systemd
echo "⚙️  Configurando serviço systemd..."
cat > /etc/systemd/system/scanner-autostart.service << EOF
[Unit]
Description=Scanner System Auto-start for PI User
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$PI_USER
Group=$PI_USER
WorkingDirectory=/opt/scanner-system
ExecStart=/opt/scanner-system/start_app.sh
Restart=always
RestartSec=10
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$PI_USER/.Xauthority

[Install]
WantedBy=graphical-session.target
EOF

# Habilitar serviço
systemctl daemon-reload
systemctl enable scanner-autostart.service

if systemctl is-enabled scanner-autostart.service > /dev/null 2>&1; then
    echo "✅ Serviço scanner-autostart habilitado"
else
    echo "⚠️  Serviço não pôde ser habilitado, mas continuando..."
fi

# 8. Configurar para iniciar em modo gráfico
echo "🖥️  Configurando modo gráfico..."
if [ -f /etc/default/raspi-config ]; then
    # Configurar para iniciar em modo gráfico
    sed -i 's/BOOT_TO_CLI=1/BOOT_TO_CLI=0/' /etc/default/raspi-config 2>/dev/null || true
    echo "✅ Modo gráfico configurado"
fi

# 9. Configurar boot silencioso
echo "🔇 Configurando boot silencioso..."
if [ -f /boot/cmdline.txt ]; then
    # Adicionar timeout para boot mais rápido
    if ! grep -q "consoleblank=0" /boot/cmdline.txt; then
        echo " consoleblank=0" >> /boot/cmdline.txt
        echo "✅ Timeout de boot configurado"
    fi
    
    # Adicionar parâmetros para boot silencioso
    if ! grep -q "quiet" /boot/cmdline.txt; then
        echo " quiet" >> /boot/cmdline.txt
        echo "✅ Boot silencioso configurado"
    fi
    if ! grep -q "logo.nologo" /boot/cmdline.txt; then
        echo " logo.nologo" >> /boot/cmdline.txt
        echo "✅ Logo removido do boot"
    fi
fi

# 10. Criar script de execução imediata
echo "📋 Criando script de execução imediata..."
cat > /opt/scanner-system/start_app.sh << EOF
#!/bin/bash
# Script para iniciar aplicação imediatamente

cd /opt/scanner-system

# Aguardar um pouco para o sistema carregar
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
chown $PI_USER:$PI_USER /opt/scanner-system/start_app.sh
echo "✅ Script de execução imediata criado"

# 11. Configurar permissões de sudo para comandos específicos
echo "🔓 Configurando permissões sudo..."
cat > /etc/sudoers.d/scanner-system << EOF
$PI_USER ALL=(ALL) NOPASSWD: /usr/bin/date
$PI_USER ALL=(ALL) NOPASSWD: /usr/bin/timedatectl
$PI_USER ALL=(ALL) NOPASSWD: /usr/bin/ntpdate
$PI_USER ALL=(ALL) NOPASSWD: /usr/bin/nmcli
EOF

# Adicionar hwclock se disponível
if command -v hwclock &> /dev/null; then
    echo "$PI_USER ALL=(ALL) NOPASSWD: /usr/sbin/hwclock" >> /etc/sudoers.d/scanner-system
fi

echo "✅ Permissões sudo configuradas"

# 12. Verificar se a aplicação existe
echo "🔍 Verificando se a aplicação existe..."
if [ -f /opt/scanner-system/src/app.py ]; then
    echo "✅ Aplicação encontrada em /opt/scanner-system/src/app.py"
else
    echo "⚠️  Aplicação não encontrada em /opt/scanner-system/src/app.py"
    echo "   Certifique-se de que os arquivos foram copiados para /opt/scanner-system/"
fi

echo "========================================="
echo "✅ Configuração para usuário PI concluída!"
echo "========================================="
echo ""
echo "📋 O que foi configurado:"
echo "✅ Auto-login automático para usuário $PI_USER"
echo "✅ Autostart da aplicação Tkinter"
echo "✅ Execução em múltiplos pontos de inicialização"
echo "✅ Serviço systemd para auto-iniciar"
echo "✅ Modo gráfico habilitado"
echo "✅ Boot silencioso"
echo "✅ Permissões sudo configuradas"
echo ""
echo "🔄 Para aplicar as configurações:"
echo "1. Reinicie o sistema: sudo reboot"
echo "2. O sistema deve iniciar automaticamente como usuário $PI_USER"
echo "3. A aplicação Tkinter deve aparecer automaticamente"
echo ""
echo "🔧 Comandos úteis:"
echo "   sudo systemctl status scanner-autostart.service"
echo "   sudo systemctl restart scanner-autostart.service"
echo "   journalctl -u scanner-autostart.service -f"
echo ""
echo "⚠️  NOTA: Se algo não funcionar, verifique os logs acima"
echo "========================================="

# Criar arquivo de status da configuração
cat > /opt/scanner-system/pi-user-setup-status.txt << EOF
Configuração para usuário PI concluída em: $(date)
Usuário: $PI_USER
Status: ✅ Configurado
Configurações aplicadas:
- Auto-login habilitado para $PI_USER
- Autostart da aplicação
- Execução automática
- Serviços habilitados
- Permissões sudo configuradas
EOF

echo "📄 Status da configuração salvo em: /opt/scanner-system/pi-user-setup-status.txt" 