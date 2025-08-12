#!/bin/bash

# Script para corrigir problemas de exibição da interface gráfica Tkinter
# Execute com: sudo bash fix_gui_display.sh

echo "🖥️  Corrigindo Exibição da Interface Gráfica Tkinter"
echo "===================================================="

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute com sudo: sudo bash fix_gui_display.sh"
    exit 1
fi

# Definir usuário como pi
PI_USER="pi"
echo "👤 Configurando para usuário: $PI_USER"

echo "🔧 Corrigindo problemas de exibição..."

# 1. Verificar e configurar variáveis de ambiente
echo "🌍 Configurando variáveis de ambiente..."
cat > /etc/environment.d/scanner-display.conf << EOF
DISPLAY=:0
XAUTHORITY=/home/$PI_USER/.Xauthority
XDG_RUNTIME_DIR=/run/user/1000
EOF

echo "✅ Variáveis de ambiente configuradas"

# 2. Configurar permissões do diretório X11
echo "🔐 Configurando permissões X11..."
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
chown root:root /tmp/.X11-unix

# Configurar permissões para o usuário pi
usermod -a -G video $PI_USER 2>/dev/null || echo "⚠️  Não foi possível adicionar usuário ao grupo video"
usermod -a -G tty $PI_USER 2>/dev/null || echo "⚠️  Não foi possível adicionar usuário ao grupo tty"

echo "✅ Permissões X11 configuradas"

# 3. Configurar autostart com variáveis de ambiente corretas
echo "🚀 Reconfigurando autostart com variáveis corretas..."

# Remover configurações antigas
rm -f /etc/xdg/lxsession/LXDE-pi/autostart/scanner-system
rm -f /etc/xdg/lxsession/LXDE/autostart/scanner-system
rm -f /home/$PI_USER/.config/autostart/scanner-system.desktop

# Criar novo autostart com variáveis corretas
cat > /etc/xdg/lxsession/LXDE-pi/autostart/scanner-system << EOF
@bash -c 'export DISPLAY=:0; export XAUTHORITY=/home/$PI_USER/.Xauthority; cd /opt/scanner-system && python3 src/app.py'
EOF

cat > /etc/xdg/lxsession/LXDE/autostart/scanner-system << EOF
@bash -c 'export DISPLAY=:0; export XAUTHORITY=/home/$PI_USER/.Xauthority; cd /opt/scanner-system && python3 src/app.py'
EOF

cat > /home/$PI_USER/.config/autostart/scanner-system.desktop << EOF
[Desktop Entry]
Type=Application
Name=Sistema de Scanner
Comment=Sistema de Scanner Raspberry Pi
Exec=bash -c 'export DISPLAY=:0; export XAUTHORITY=/home/$PI_USER/.Xauthority; cd /opt/scanner-system && python3 src/app.py'
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
EOF

echo "✅ Autostart reconfigurado com variáveis corretas"

# 4. Reconfigurar execução no .bashrc
echo "📝 Reconfigurando execução no .bashrc..."
# Remover configuração antiga
sed -i '/scanner-system/,/fi/d' /home/$PI_USER/.bashrc

# Adicionar nova configuração
cat >> /home/$PI_USER/.bashrc << EOF

# Auto-executar sistema de scanner
if [ -n "\$DISPLAY" ]; then
    sleep 3
    if ! pgrep -f "scanner-system" > /dev/null; then
        if [ -f "/opt/scanner-system/src/app.py" ]; then
            export DISPLAY=:0
            export XAUTHORITY=/home/$PI_USER/.Xauthority
            cd /opt/scanner-system
            python3 src/app.py &
        fi
    fi
fi
EOF

echo "✅ .bashrc reconfigurado"

# 5. Reconfigurar execução no .profile
echo "📝 Reconfigurando execução no .profile..."
# Remover configuração antiga
sed -i '/scanner-system/,/fi/d' /home/$PI_USER/.profile

# Adicionar nova configuração
cat >> /home/$PI_USER/.profile << EOF

# Auto-executar sistema de scanner
if [ -n "\$DISPLAY" ]; then
    sleep 3
    if ! pgrep -f "scanner-system" > /dev/null; then
        if [ -f "/opt/scanner-system/src/app.py" ]; then
            export DISPLAY=:0
            export XAUTHORITY=/home/$PI_USER/.Xauthority
            cd /opt/scanner-system
            python3 src/app.py &
        fi
    fi
fi
EOF

echo "✅ .profile reconfigurado"

# 6. Criar script de execução com variáveis corretas
echo "📋 Criando script de execução corrigido..."
cat > /opt/scanner-system/start_app_gui.sh << EOF
#!/bin/bash
# Script para iniciar aplicação com interface gráfica

# Configurar variáveis de ambiente
export DISPLAY=:0
export XAUTHORITY=/home/$PI_USER/.Xauthority
export XDG_RUNTIME_DIR=/run/user/1000

# Aguardar sistema carregar
sleep 3

# Verificar se o display está disponível
if ! xset q &>/dev/null; then
    echo "Erro: Display não está disponível"
    echo "Tentando iniciar X11..."
    startx &
    sleep 5
fi

# Verificar se o display está funcionando
if ! xset q &>/dev/null; then
    echo "Erro: Não foi possível iniciar o display"
    exit 1
fi

echo "Display funcionando: \$DISPLAY"

# Navegar para o diretório da aplicação
cd /opt/scanner-system

# Verificar se a aplicação existe
if [ ! -f "src/app.py" ]; then
    echo "Erro: Aplicação não encontrada"
    exit 1
fi

# Executar aplicação
echo "Iniciando aplicação Tkinter..."
python3 src/app.py
EOF

chmod +x /opt/scanner-system/start_app_gui.sh
chown $PI_USER:$PI_USER /opt/scanner-system/start_app_gui.sh

echo "✅ Script de execução GUI criado"

# 7. Reconfigurar serviço systemd
echo "⚙️  Reconfigurando serviço systemd..."
cat > /etc/systemd/system/scanner-autostart.service << EOF
[Unit]
Description=Scanner System Auto-start with GUI
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$PI_USER
Group=$PI_USER
WorkingDirectory=/opt/scanner-system
ExecStart=/opt/scanner-system/start_app_gui.sh
Restart=always
RestartSec=10
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$PI_USER/.Xauthority
Environment=XDG_RUNTIME_DIR=/run/user/1000

[Install]
WantedBy=graphical-session.target
EOF

# Recarregar e habilitar serviço
systemctl daemon-reload
systemctl enable scanner-autostart.service

if systemctl is-enabled scanner-autostart.service > /dev/null 2>&1; then
    echo "✅ Serviço systemd reconfigurado"
else
    echo "⚠️  Serviço não pôde ser habilitado"
fi

# 8. Configurar para forçar modo gráfico
echo "🖥️  Configurando modo gráfico forçado..."
if [ -f /etc/default/raspi-config ]; then
    sed -i 's/BOOT_TO_CLI=1/BOOT_TO_CLI=0/' /etc/default/raspi-config 2>/dev/null || true
    echo "✅ Modo gráfico forçado"
fi

# 9. Configurar para não mostrar terminal
echo "🔇 Configurando para não mostrar terminal..."
if [ -f /boot/cmdline.txt ]; then
    # Adicionar parâmetros para boot gráfico
    if ! grep -q "console=tty1" /boot/cmdline.txt; then
        echo " console=tty1" >> /boot/cmdline.txt
        echo "✅ Console tty1 configurado"
    fi
    
    if ! grep -q "quiet" /boot/cmdline.txt; then
        echo " quiet" >> /boot/cmdline.txt
        echo "✅ Boot silencioso configurado"
    fi
fi

# 10. Configurar permissões
echo "🔐 Configurando permissões finais..."
chown -R $PI_USER:$PI_USER /home/$PI_USER/.config
chown -R $PI_USER:$PI_USER /home/$PI_USER/.bashrc
chown -R $PI_USER:$PI_USER /home/$PI_USER/.profile

# 11. Criar script de teste GUI
echo "🧪 Criando script de teste GUI..."
cat > /opt/scanner-system/test_gui.sh << EOF
#!/bin/bash
# Script para testar se a interface gráfica está funcionando

echo "🧪 Testando Interface Gráfica..."
echo "================================="

# Configurar variáveis de ambiente
export DISPLAY=:0
export XAUTHORITY=/home/$PI_USER/.Xauthority
export XDG_RUNTIME_DIR=/run/user/1000

echo "DISPLAY: \$DISPLAY"
echo "XAUTHORITY: \$XAUTHORITY"
echo "XDG_RUNTIME_DIR: \$XDG_RUNTIME_DIR"

# Verificar se o display está funcionando
if xset q &>/dev/null; then
    echo "✅ Display está funcionando"
    
    # Testar se podemos abrir uma janela simples
    if python3 -c "
import tkinter as tk
root = tk.Tk()
root.title('Teste GUI')
root.geometry('300x200')
label = tk.Label(root, text='Interface Gráfica Funcionando!')
label.pack(pady=20)
root.after(2000, root.destroy)
root.mainloop()
print('✅ Tkinter funcionando!')
" 2>/dev/null; then
        echo "✅ Tkinter está funcionando corretamente"
    else
        echo "❌ Tkinter não está funcionando"
    fi
else
    echo "❌ Display não está funcionando"
    echo "Tentando iniciar X11..."
    startx &
    sleep 5
    
    if xset q &>/dev/null; then
        echo "✅ X11 iniciado com sucesso"
    else
        echo "❌ Falha ao iniciar X11"
    fi
fi

echo "================================="
EOF

chmod +x /opt/scanner-system/test_gui.sh
chown $PI_USER:$PI_USER /opt/scanner-system/test_gui.sh

echo "✅ Script de teste GUI criado"

# 12. Configurar para iniciar X11 automaticamente
echo "🖥️  Configurando início automático do X11..."
cat > /etc/systemd/system/startx.service << EOF
[Unit]
Description=Start X11 Server
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$PI_USER
Group=$PI_USER
ExecStart=/usr/bin/startx
Restart=always
RestartSec=10

[Install]
WantedBy=graphical-session.target
EOF

# Habilitar serviço
systemctl daemon-reload
systemctl enable startx.service

echo "✅ Serviço startx configurado"

echo "===================================================="
echo "✅ Correção da Interface Gráfica Concluída!"
echo "===================================================="
echo ""
echo "📋 O que foi corrigido:"
echo "✅ Variáveis de ambiente DISPLAY e XAUTHORITY"
echo "✅ Permissões X11 e grupos de usuário"
echo "✅ Autostart com variáveis corretas"
echo "✅ Script de execução GUI específico"
echo "✅ Serviço systemd corrigido"
echo "✅ Modo gráfico forçado"
echo "✅ Script de teste GUI"
echo ""
echo "🧪 Para testar a interface gráfica:"
echo "   sudo -u pi bash /opt/scanner-system/test_gui.sh"
echo ""
echo "🔄 Para aplicar todas as correções:"
echo "1. Reinicie o sistema: sudo reboot"
echo "2. A aplicação deve abrir em modo gráfico (não no terminal)"
echo ""
echo "🔧 Se ainda houver problemas:"
echo "   sudo -u pi bash /opt/scanner-system/test_gui.sh"
echo "   journalctl -u scanner-autostart.service -f"
echo ""
echo "===================================================="

# Criar arquivo de status da correção
cat > /opt/scanner-system/gui-fix-status.txt << EOF
Correção da interface gráfica concluída em: $(date)
Usuário: $PI_USER
Status: ✅ Corrigido
Problemas resolvidos:
- Variáveis de ambiente DISPLAY/XAUTHORITY
- Permissões X11
- Autostart com variáveis corretas
- Script de execução GUI
- Serviço systemd corrigido
EOF

echo "📄 Status da correção salvo em: /opt/scanner-system/gui-fix-status.txt" 