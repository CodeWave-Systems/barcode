#!/bin/bash

# Script para configurar autostart automático sem login
# Execute com: sudo bash autostart_config.sh

set -e

echo "=========================================="
echo "Configuração de Autostart Automático"
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

echo "🔧 Configurando autostart automático..."

# 1. Configurar auto-login para o usuário
echo "👤 Configurando auto-login..."
if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
    echo "✅ Auto-login já configurado"
else
    mkdir -p /etc/systemd/system/getty@tty1.service.d/
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $SUDO_USER --noclear %I \$TERM
Type=idle
EOF
    echo "✅ Auto-login configurado para usuário $SUDO_USER"
fi

# 2. Configurar auto-login no lightdm (se disponível)
echo "🖥️  Configurando auto-login no LightDM..."
if [ -f /etc/lightdm/lightdm.conf ]; then
    # Backup do arquivo original
    cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
    
    # Adicionar configurações de auto-login
    cat >> /etc/lightdm/lightdm.conf << EOF

# Configurações de auto-login
[SeatDefaults]
autologin-user=$SUDO_USER
autologin-user-timeout=0
autologin-session=lightdm-autologin
EOF
    echo "✅ Auto-login LightDM configurado"
else
    echo "⚠️  LightDM não encontrado, configurando alternativas..."
fi

# 3. Configurar auto-login no LXDE (Raspberry Pi OS)
echo "🍓 Configurando auto-login no LXDE..."
if [ -f /etc/lxdm/lxdm.conf ]; then
    # Backup do arquivo original
    cp /etc/lxdm/lxdm.conf /etc/lxdm/lxdm.conf.backup
    
    # Configurar auto-login
    sed -i 's/# autologin=.*/autologin='$SUDO_USER'/' /etc/lxdm/lxdm.conf
    sed -i 's/# timeout=.*/timeout=0/' /etc/lxdm/lxdm.conf
    echo "✅ Auto-login LXDM configurado"
fi

# 4. Configurar autostart da aplicação
echo "🚀 Configurando autostart da aplicação..."

# Criar diretório de autostart se não existir
mkdir -p /etc/xdg/autostart
mkdir -p /etc/xdg/lxsession/LXDE-pi/autostart
mkdir -p /etc/xdg/lxsession/LXDE/autostart
mkdir -p /home/$SUDO_USER/.config/autostart

# Configurar autostart global (para todos os usuários)
cat > /etc/xdg/autostart/scanner-system.desktop << EOF
[Desktop Entry]
Type=Application
Name=Sistema de Scanner
Comment=Sistema de Scanner Raspberry Pi
Exec=python3 /opt/scanner-system/src/app.py
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
EOF

# Configurar autostart específico do LXDE
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

echo "✅ Autostart configurado em múltiplos locais"

# 5. Configurar execução automática no .bashrc
echo "📝 Configurando execução no .bashrc..."
if ! grep -q "scanner-system" /home/$SUDO_USER/.bashrc; then
    cat >> /home/$SUDO_USER/.bashrc << EOF

# Auto-executar sistema de scanner
if [ -z "\$DISPLAY" ] && [ -t 0 ]; then
    # Se não há display e é terminal, não executar
    return
fi

# Verificar se já está rodando
if ! pgrep -f "scanner-system" > /dev/null; then
    # Aguardar um pouco para o sistema carregar
    sleep 5
    
    # Executar aplicação
    if [ -f "/opt/scanner-system/src/app.py" ]; then
        cd /opt/scanner-system
        python3 src/app.py &
    fi
fi
EOF
    echo "✅ Execução automática configurada no .bashrc"
else
    echo "✅ Execução automática já configurada no .bashrc"
fi

# 6. Configurar execução no .profile
echo "📝 Configurando execução no .profile..."
if ! grep -q "scanner-system" /home/$SUDO_USER/.profile; then
    cat >> /home/$SUDO_USER/.profile << EOF

# Auto-executar sistema de scanner
if [ -n "\$DISPLAY" ]; then
    # Aguardar um pouco para o sistema carregar
    sleep 3
    
    # Verificar se já está rodando
    if ! pgrep -f "scanner-system" > /dev/null; then
        # Executar aplicação
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

# 7. Configurar execução no .xinitrc
echo "📝 Configurando execução no .xinitrc..."
if [ -f /home/$SUDO_USER/.xinitrc ]; then
    # Backup do arquivo original
    cp /home/$SUDO_USER/.xinitrc /home/$SUDO_USER/.xinitrc.backup
    
    # Adicionar execução da aplicação
    if ! grep -q "scanner-system" /home/$SUDO_USER/.xinitrc; then
        cat >> /home/$SUDO_USER/.xinitrc << EOF

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
    cat > /home/$SUDO_USER/.xinitrc << EOF
#!/bin/bash

# Executar sistema de scanner
if [ -f "/opt/scanner-system/src/app.py" ]; then
    cd /opt/scanner-system
    python3 src/app.py &
fi

# Executar desktop padrão
exec startx
EOF
    chmod +x /home/$SUDO_USER/.xinitrc
    echo "✅ .xinitrc criado com execução automática"
fi

# 8. Configurar permissões
echo "🔐 Configurando permissões..."
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.bashrc
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.profile
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.xinitrc

# 9. Configurar serviço systemd para auto-iniciar
echo "⚙️  Configurando serviço systemd..."
if command -v systemctl &> /dev/null; then
    # Criar serviço de auto-login
    cat > /etc/systemd/system/autologin@tty1.service << EOF
[Unit]
Description=Auto-login for %I on tty1
After=systemd-user-sessions.service getty@tty1.service
Wants=getty@tty1.service

[Service]
Type=simple
ExecStart=/bin/bash -c 'cd /opt/scanner-system && python3 src/app.py'
User=%I
Group=%I
WorkingDirectory=/opt/scanner-system
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
EOF

    # Habilitar serviço
    systemctl daemon-reload
    systemctl enable autologin@$SUDO_USER.service
    echo "✅ Serviço de auto-login configurado"
else
    echo "⚠️  systemctl não disponível, serviço não configurado"
fi

# 10. Configurar para iniciar em modo gráfico
echo "🖥️  Configurando modo gráfico..."
if [ -f /etc/default/raspi-config ]; then
    # Configurar para iniciar em modo gráfico
    sed -i 's/BOOT_TO_CLI=1/BOOT_TO_CLI=0/' /etc/default/raspi-config 2>/dev/null || true
fi

# 11. Configurar para não mostrar tela de login
echo "🔒 Configurando para não mostrar tela de login..."
if [ -f /etc/systemd/system/display-manager.service ]; then
    # Habilitar display manager
    systemctl enable display-manager.service 2>/dev/null || true
fi

# 12. Configurar timeout de boot
echo "⏱️  Configurando timeout de boot..."
if [ -f /boot/cmdline.txt ]; then
    # Adicionar timeout para boot mais rápido
    if ! grep -q "consoleblank=0" /boot/cmdline.txt; then
        echo " consoleblank=0" >> /boot/cmdline.txt
        echo "✅ Timeout de boot configurado"
    fi
fi

# 13. Configurar para não mostrar mensagens de boot
echo "🔇 Configurando para não mostrar mensagens de boot..."
if [ -f /boot/cmdline.txt ]; then
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

# 14. Configurar para iniciar aplicação imediatamente
echo "🚀 Configurando execução imediata..."
cat > /opt/scanner-system/start_immediately.sh << EOF
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

chmod +x /opt/scanner-system/start_immediately.sh
chown $SUDO_USER:$SUDO_USER /opt/scanner-system/start_immediately.sh

# 15. Configurar para executar este script no boot
echo "📋 Configurando execução do script no boot..."
cat > /etc/systemd/system/scanner-autostart.service << EOF
[Unit]
Description=Scanner System Auto-start
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$SUDO_USER
Group=$SUDO_USER
WorkingDirectory=/opt/scanner-system
ExecStart=/opt/scanner-system/start_immediately.sh
Restart=always
RestartSec=10
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SUDO_USER/.Xauthority

[Install]
WantedBy=graphical-session.target
EOF

if command -v systemctl &> /dev/null; then
    systemctl daemon-reload
    systemctl enable scanner-autostart.service
    echo "✅ Serviço de auto-start configurado"
fi

echo "=========================================="
echo "✅ Configuração de autostart concluída!"
echo "=========================================="
echo ""
echo "📋 O que foi configurado:"
echo "✅ Auto-login automático para usuário $SUDO_USER"
echo "✅ Autostart da aplicação Tkinter"
echo "✅ Execução em múltiplos pontos de inicialização"
echo "✅ Serviço systemd para auto-iniciar"
echo "✅ Boot em modo gráfico"
echo "✅ Sem tela de login"
echo ""
echo "🔄 Para aplicar as configurações:"
echo "1. Reinicie o sistema: sudo reboot"
echo "2. O sistema deve iniciar automaticamente"
echo "3. A aplicação Tkinter deve aparecer automaticamente"
echo ""
echo "🔧 Comandos úteis:"
echo "   sudo systemctl status scanner-autostart.service"
echo "   sudo systemctl status autologin@$SUDO_USER.service"
echo "   journalctl -u scanner-autostart.service -f"
echo ""
echo "⚠️  NOTA: Se algo não funcionar, verifique os logs acima"
echo "=========================================="

# Criar arquivo de status da configuração
cat > /opt/scanner-system/autostart-status.txt << EOF
Configuração de autostart concluída em: $(date)
Usuário: $SUDO_USER
Status: ✅ Configurado
Configurações aplicadas:
- Auto-login habilitado
- Autostart da aplicação
- Execução automática
- Serviços habilitados
EOF

echo "📄 Status da configuração salvo em: /opt/scanner-system/autostart-status.txt" 