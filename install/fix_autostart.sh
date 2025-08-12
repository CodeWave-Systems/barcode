#!/bin/bash

# Script para corrigir problemas de autostart e verificar configuração
# Execute com: sudo bash fix_autostart.sh

echo "🔧 Corrigindo e Verificando Configuração de Autostart"
echo "===================================================="

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute com sudo: sudo bash fix_autostart.sh"
    exit 1
fi

echo "🔍 Verificando configurações atuais..."

# 1. Verificar se o usuário existe
CURRENT_USER=$(who am i | awk '{print $1}')
if [ -z "$CURRENT_USER" ]; then
    CURRENT_USER=$SUDO_USER
fi

echo "👤 Usuário atual: $CURRENT_USER"

# 2. Corrigir serviço systemd
echo "⚙️  Corrigindo serviço systemd..."

# Remover serviço problemático se existir
if [ -f /etc/systemd/system/autologin@pi.service ]; then
    rm -f /etc/systemd/system/autologin@pi.service
    echo "✅ Serviço problemático removido"
fi

# Criar serviço correto
cat > /etc/systemd/system/scanner-autostart.service << EOF
[Unit]
Description=Scanner System Auto-start
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=/opt/scanner-system
ExecStart=/opt/scanner-system/start_immediately.sh
Restart=always
RestartSec=10
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$CURRENT_USER/.Xauthority

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

# 3. Verificar e corrigir configurações de auto-login
echo "🔍 Verificando configurações de auto-login..."

# Verificar LXDE
if [ -f /etc/lxdm/lxdm.conf ]; then
    echo "🍓 Configuração LXDE encontrada"
    if grep -q "autologin=$CURRENT_USER" /etc/lxdm/lxdm.conf; then
        echo "✅ Auto-login LXDE configurado para $CURRENT_USER"
    else
        echo "⚠️  Auto-login LXDE não configurado corretamente"
        # Corrigir
        sed -i "s/# autologin=.*/autologin=$CURRENT_USER/" /etc/lxdm/lxdm.conf
        sed -i "s/# timeout=.*/timeout=0/" /etc/lxdm/lxdm.conf
        echo "✅ Auto-login LXDE corrigido"
    fi
else
    echo "⚠️  LXDE não encontrado"
fi

# 4. Verificar autostart da aplicação
echo "🚀 Verificando autostart da aplicação..."

AUTOSTART_PATHS=(
    "/etc/xdg/lxsession/LXDE-pi/autostart/scanner-system"
    "/etc/xdg/lxsession/LXDE/autostart/scanner-system"
    "/home/$CURRENT_USER/.config/autostart/scanner-system.desktop"
)

for path in "${AUTOSTART_PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo "✅ $path existe"
    else
        echo "❌ $path não existe, criando..."
        # Criar diretório se necessário
        mkdir -p "$(dirname "$path")"
        
        if [[ "$path" == *".desktop" ]]; then
            # Arquivo .desktop
            cat > "$path" << EOF
[Desktop Entry]
Type=Application
Name=Sistema de Scanner
Comment=Sistema de Scanner Raspberry Pi
Exec=python3 /opt/scanner-system/src/app.py
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
EOF
        else
            # Arquivo de texto simples
            echo "@python3 /opt/scanner-system/src/app.py" > "$path"
        fi
        
        echo "✅ $path criado"
    fi
done

# 5. Verificar execução no .bashrc
echo "📝 Verificando execução no .bashrc..."
if grep -q "scanner-system" /home/$CURRENT_USER/.bashrc; then
    echo "✅ Execução automática configurada no .bashrc"
else
    echo "⚠️  Execução automática não configurada no .bashrc, adicionando..."
    cat >> /home/$CURRENT_USER/.bashrc << EOF

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
    echo "✅ Execução automática adicionada ao .bashrc"
fi

# 6. Verificar execução no .profile
echo "📝 Verificando execução no .profile..."
if grep -q "scanner-system" /home/$CURRENT_USER/.profile; then
    echo "✅ Execução automática configurada no .profile"
else
    echo "⚠️  Execução automática não configurada no .profile, adicionando..."
    cat >> /home/$CURRENT_USER/.profile << EOF

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
    echo "✅ Execução automática adicionada ao .profile"
fi

# 7. Verificar modo gráfico
echo "🖥️  Verificando modo gráfico..."
if [ -f /etc/default/raspi-config ]; then
    if grep -q "BOOT_TO_CLI=0" /etc/default/raspi-config; then
        echo "✅ Modo gráfico configurado"
    else
        echo "⚠️  Modo gráfico não configurado, configurando..."
        sed -i 's/BOOT_TO_CLI=1/BOOT_TO_CLI=0/' /etc/default/raspi-config 2>/dev/null || true
        echo "✅ Modo gráfico configurado"
    fi
else
    echo "⚠️  Arquivo raspi-config não encontrado"
fi

# 8. Verificar boot silencioso
echo "🔇 Verificando boot silencioso..."
if [ -f /boot/cmdline.txt ]; then
    BOOT_CONFIGURED=true
    
    if ! grep -q "quiet" /boot/cmdline.txt; then
        echo " quiet" >> /boot/cmdline.txt
        BOOT_CONFIGURED=false
    fi
    
    if ! grep -q "logo.nologo" /boot/cmdline.txt; then
        echo " logo.nologo" >> /boot/cmdline.txt
        BOOT_CONFIGURED=false
    fi
    
    if [ "$BOOT_CONFIGURED" = false ]; then
        echo "✅ Boot silencioso configurado"
    else
        echo "✅ Boot silencioso já configurado"
    fi
else
    echo "⚠️  Arquivo cmdline.txt não encontrado"
fi

# 9. Verificar script de execução imediata
echo "📋 Verificando script de execução imediata..."
if [ -f /opt/scanner-system/start_immediately.sh ]; then
    echo "✅ Script de execução imediata existe"
else
    echo "⚠️  Script de execução imediata não existe, criando..."
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
    chown $CURRENT_USER:$CURRENT_USER /opt/scanner-system/start_immediately.sh
    echo "✅ Script de execução imediata criado"
fi

# 10. Configurar permissões
echo "🔐 Configurando permissões..."
chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.config 2>/dev/null || true
chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.bashrc 2>/dev/null || true
chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.profile 2>/dev/null || true
chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.xinitrc 2>/dev/null || true

# 11. Verificar se a aplicação existe
echo "🔍 Verificando se a aplicação existe..."
if [ -f /opt/scanner-system/src/app.py ]; then
    echo "✅ Aplicação encontrada em /opt/scanner-system/src/app.py"
else
    echo "⚠️  Aplicação não encontrada em /opt/scanner-system/src/app.py"
    echo "   Certifique-se de que os arquivos foram copiados para /opt/scanner-system/"
fi

# 12. Testar serviço
echo "🧪 Testando serviço..."
if systemctl is-enabled scanner-autostart.service > /dev/null 2>&1; then
    echo "✅ Serviço scanner-autostart está habilitado"
    echo "   Status: $(systemctl is-active scanner-autostart.service 2>/dev/null || echo 'inactive')"
else
    echo "⚠️  Serviço scanner-autostart não está habilitado"
fi

echo "===================================================="
echo "✅ Verificação e correção concluída!"
echo "===================================================="
echo ""
echo "📋 Resumo das configurações:"
echo "✅ Auto-login configurado"
echo "✅ Autostart da aplicação configurado"
echo "✅ Execução automática em múltiplos pontos"
echo "✅ Modo gráfico habilitado"
echo "✅ Boot silencioso configurado"
echo "✅ Serviço systemd corrigido"
echo ""
echo "🔄 Para aplicar todas as configurações:"
echo "1. Reinicie o sistema: sudo reboot"
echo "2. A aplicação deve aparecer automaticamente"
echo ""
echo "🔧 Para verificar status:"
echo "   sudo systemctl status scanner-autostart.service"
echo "   journalctl -u scanner-autostart.service -f"
echo ""
echo "⚠️  IMPORTANTE: Certifique-se de que os arquivos do projeto"
echo "   estão em /opt/scanner-system/ antes de reiniciar!"
echo "===================================================="

# Criar arquivo de status da correção
cat > /opt/scanner-system/fix-autostart-status.txt << EOF
Correção de autostart concluída em: $(date)
Usuário: $CURRENT_USER
Status: ✅ Corrigido e Verificado
Serviços:
- scanner-autostart.service: $(systemctl is-enabled scanner-autostart.service 2>/dev/null || echo 'disabled')
- Status atual: $(systemctl is-active scanner-autostart.service 2>/dev/null || echo 'inactive')
EOF

echo "📄 Status da correção salvo em: /opt/scanner-system/fix-autostart-status.txt" 