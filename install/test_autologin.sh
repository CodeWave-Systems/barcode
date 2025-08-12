#!/bin/bash

# Script para testar se o login automático está funcionando
# Execute com: bash test_autologin.sh

echo "🧪 Testando Configuração de Login Automático"
echo "============================================"

# Verificar se estamos rodando como usuário pi
if [ "$USER" != "pi" ]; then
    echo "⚠️  Este script deve ser executado como usuário pi"
    echo "   Execute: su - pi"
    echo "   Ou: sudo -u pi bash test_autologin.sh"
    exit 1
fi

echo "👤 Usuário atual: $USER"
echo "🏠 Diretório home: $HOME"

# 1. Verificar configuração LXDE
echo ""
echo "🍓 Verificando configuração LXDE..."
if [ -f /etc/lxdm/lxdm.conf ]; then
    echo "✅ Arquivo LXDE encontrado"
    
    # Verificar auto-login
    if grep -q "autologin=pi" /etc/lxdm/lxdm.conf; then
        echo "✅ Auto-login configurado para usuário pi"
        AUTOLOGIN_USER=$(grep "autologin=" /etc/lxdm/lxdm.conf | cut -d'=' -f2)
        echo "   Usuário configurado: $AUTOLOGIN_USER"
    else
        echo "❌ Auto-login não configurado para usuário pi"
    fi
    
    # Verificar timeout
    if grep -q "timeout=0" /etc/lxdm/lxdm.conf; then
        echo "✅ Timeout configurado como 0 (sem espera)"
    else
        echo "⚠️  Timeout não configurado como 0"
    fi
else
    echo "❌ Arquivo LXDE não encontrado"
fi

# 2. Verificar autostart da aplicação
echo ""
echo "🚀 Verificando autostart da aplicação..."

AUTOSTART_PATHS=(
    "/etc/xdg/lxsession/LXDE-pi/autostart/scanner-system"
    "/etc/xdg/lxsession/LXDE/autostart/scanner-system"
    "$HOME/.config/autostart/scanner-system.desktop"
)

for path in "${AUTOSTART_PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo "✅ $path existe"
        if [[ "$path" == *".desktop" ]]; then
            # Verificar conteúdo do arquivo .desktop
            if grep -q "Exec=python3 /opt/scanner-system/src/app.py" "$path"; then
                echo "   ✅ Comando de execução correto"
            else
                echo "   ⚠️  Comando de execução pode estar incorreto"
            fi
        else
            # Verificar conteúdo do arquivo de texto
            if grep -q "python3 /opt/scanner-system/src/app.py" "$path"; then
                echo "   ✅ Comando de execução correto"
            else
                echo "   ⚠️  Comando de execução pode estar incorreto"
            fi
        fi
    else
        echo "❌ $path não existe"
    fi
done

# 3. Verificar execução automática nos arquivos de perfil
echo ""
echo "📝 Verificando execução automática..."

# Verificar .bashrc
if [ -f "$HOME/.bashrc" ]; then
    if grep -q "scanner-system" "$HOME/.bashrc; then
        echo "✅ Execução automática configurada no .bashrc"
    else
        echo "❌ Execução automática não configurada no .bashrc"
    fi
else
    echo "⚠️  Arquivo .bashrc não encontrado"
fi

# Verificar .profile
if [ -f "$HOME/.profile" ]; then
    if grep -q "scanner-system" "$HOME/.profile; then
        echo "✅ Execução automática configurada no .profile"
    else
        echo "❌ Execução automática não configurada no .profile"
    fi
else
    echo "⚠️  Arquivo .profile não encontrado"
fi

# Verificar .xinitrc
if [ -f "$HOME/.xinitrc" ]; then
    if grep -q "scanner-system" "$HOME/.xinitrc; then
        echo "✅ Execução automática configurada no .xinitrc"
    else
        echo "❌ Execução automática não configurada no .xinitrc"
    fi
else
    echo "⚠️  Arquivo .xinitrc não encontrado"
fi

# 4. Verificar se a aplicação existe
echo ""
echo "🔍 Verificando se a aplicação existe..."
if [ -f "/opt/scanner-system/src/app.py" ]; then
    echo "✅ Aplicação encontrada em /opt/scanner-system/src/app.py"
    
    # Verificar permissões
    if [ -r "/opt/scanner-system/src/app.py" ]; then
        echo "   ✅ Aplicação tem permissão de leitura"
    else
        echo "   ❌ Aplicação não tem permissão de leitura"
    fi
    
    if [ -x "/opt/scanner-system/src/app.py" ]; then
        echo "   ✅ Aplicação tem permissão de execução"
    else
        echo "   ⚠️  Aplicação não tem permissão de execução"
    fi
else
    echo "❌ Aplicação não encontrada em /opt/scanner-system/src/app.py"
    echo "   Certifique-se de que os arquivos foram copiados para /opt/scanner-system/"
fi

# 5. Verificar script de execução
echo ""
echo "📋 Verificando script de execução..."
if [ -f "/opt/scanner-system/start_app.sh" ]; then
    echo "✅ Script de execução encontrado"
    
    if [ -x "/opt/scanner-system/start_app.sh" ]; then
        echo "   ✅ Script tem permissão de execução"
    else
        echo "   ❌ Script não tem permissão de execução"
    fi
    
    if [ -r "/opt/scanner-system/start_app.sh" ]; then
        echo "   ✅ Script tem permissão de leitura"
    else
        echo "   ❌ Script não tem permissão de leitura"
    fi
else
    echo "❌ Script de execução não encontrado"
fi

# 6. Verificar serviço systemd
echo ""
echo "⚙️  Verificando serviço systemd..."
if command -v systemctl &> /dev/null; then
    if systemctl is-enabled scanner-autostart.service > /dev/null 2>&1; then
        echo "✅ Serviço scanner-autostart está habilitado"
        
        # Verificar status
        SERVICE_STATUS=$(systemctl is-active scanner-autostart.service 2>/dev/null || echo "inactive")
        echo "   Status atual: $SERVICE_STATUS"
        
        if [ "$SERVICE_STATUS" = "active" ]; then
            echo "   ✅ Serviço está rodando"
        else
            echo "   ⚠️  Serviço não está rodando"
        fi
    else
        echo "❌ Serviço scanner-autostart não está habilitado"
    fi
else
    echo "⚠️  systemctl não disponível"
fi

# 7. Verificar modo gráfico
echo ""
echo "🖥️  Verificando modo gráfico..."
if [ -f /etc/default/raspi-config ]; then
    if grep -q "BOOT_TO_CLI=0" /etc/default/raspi-config; then
        echo "✅ Modo gráfico configurado (BOOT_TO_CLI=0)"
    else
        echo "❌ Modo gráfico não configurado (BOOT_TO_CLI=1)"
    fi
else
    echo "⚠️  Arquivo raspi-config não encontrado"
fi

# 8. Verificar boot silencioso
echo ""
echo "🔇 Verificando boot silencioso..."
if [ -f /boot/cmdline.txt ]; then
    BOOT_CONFIGURED=true
    
    if grep -q "quiet" /boot/cmdline.txt; then
        echo "✅ Boot silencioso configurado (quiet)"
    else
        echo "❌ Boot silencioso não configurado"
        BOOT_CONFIGURED=false
    fi
    
    if grep -q "logo.nologo" /boot/cmdline.txt; then
        echo "✅ Logo removido do boot (logo.nologo)"
    else
        echo "❌ Logo não removido do boot"
        BOOT_CONFIGURED=false
    fi
    
    if [ "$BOOT_CONFIGURED" = true ]; then
        echo "✅ Boot silencioso completamente configurado"
    fi
else
    echo "⚠️  Arquivo cmdline.txt não encontrado"
fi

# 9. Verificar variáveis de ambiente
echo ""
echo "🌍 Verificando variáveis de ambiente..."
if [ -n "$DISPLAY" ]; then
    echo "✅ DISPLAY configurado: $DISPLAY"
else
    echo "❌ DISPLAY não configurado"
fi

if [ -n "$XAUTHORITY" ]; then
    echo "✅ XAUTHORITY configurado: $XAUTHORITY"
else
    echo "⚠️  XAUTHORITY não configurado"
fi

# 10. Teste de execução da aplicação
echo ""
echo "🧪 Testando execução da aplicação..."
if [ -f "/opt/scanner-system/src/app.py" ]; then
    echo "Tentando executar aplicação em modo teste..."
    
    # Verificar se Python está disponível
    if command -v python3 &> /dev/null; then
        echo "✅ Python3 encontrado: $(python3 --version)"
        
        # Verificar se customtkinter está disponível
        if python3 -c "import customtkinter; print('✅ customtkinter disponível')" 2>/dev/null; then
            echo "✅ customtkinter disponível"
            
            # Tentar executar aplicação em modo teste (sem GUI)
            echo "Testando import da aplicação..."
            cd /opt/scanner-system
            
            if python3 -c "import sys; sys.path.append('src'); import app; print('✅ Aplicação pode ser importada')" 2>/dev/null; then
                echo "✅ Aplicação pode ser importada com sucesso"
            else
                echo "❌ Aplicação não pode ser importada"
                echo "   Verifique se há erros de sintaxe ou dependências faltando"
            fi
        else
            echo "❌ customtkinter não disponível"
            echo "   Execute: pip3 install customtkinter"
        fi
    else
        echo "❌ Python3 não encontrado"
    fi
else
    echo "❌ Aplicação não encontrada para teste"
fi

# 11. Resumo final
echo ""
echo "============================================"
echo "📋 RESUMO DO TESTE"
echo "============================================"

# Contar configurações corretas
CORRECT_CONFIGS=0
TOTAL_CONFIGS=0

# Verificar cada configuração
if grep -q "autologin=pi" /etc/lxdm/lxdm.conf 2>/dev/null; then
    ((CORRECT_CONFIGS++))
fi
((TOTAL_CONFIGS++))

if [ -f "/etc/xdg/lxsession/LXDE-pi/autostart/scanner-system" ]; then
    ((CORRECT_CONFIGS++))
fi
((TOTAL_CONFIGS++))

if [ -f "$HOME/.config/autostart/scanner-system.desktop" ]; then
    ((CORRECT_CONFIGS++))
fi
((TOTAL_CONFIGS++))

if grep -q "scanner-system" "$HOME/.bashrc" 2>/dev/null; then
    ((CORRECT_CONFIGS++))
fi
((TOTAL_CONFIGS++))

if [ -f "/opt/scanner-system/src/app.py" ]; then
    ((CORRECT_CONFIGS++))
fi
((TOTAL_CONFIGS++))

if systemctl is-enabled scanner-autostart.service > /dev/null 2>&1; then
    ((CORRECT_CONFIGS++))
fi
((TOTAL_CONFIGS++))

PERCENTAGE=$((CORRECT_CONFIGS * 100 / TOTAL_CONFIGS))

echo "✅ Configurações corretas: $CORRECT_CONFIGS/$TOTAL_CONFIGS ($PERCENTAGE%)"

if [ $PERCENTAGE -eq 100 ]; then
    echo "🎉 PERFEITO! Todas as configurações estão corretas!"
    echo "   O sistema deve funcionar automaticamente após reiniciar."
elif [ $PERCENTAGE -ge 80 ]; then
    echo "👍 MUITO BOM! A maioria das configurações está correta."
    echo "   O sistema deve funcionar, mas pode ter alguns problemas menores."
elif [ $PERCENTAGE -ge 60 ]; then
    echo "⚠️  REGULAR! Algumas configurações estão corretas."
    echo "   O sistema pode funcionar parcialmente."
else
    echo "❌ PROBLEMAS! Muitas configurações estão incorretas."
    echo "   Execute o script de configuração novamente."
fi

echo ""
echo "🔄 Para aplicar todas as configurações:"
echo "1. Reinicie o sistema: sudo reboot"
echo "2. O sistema deve iniciar automaticamente como usuário pi"
echo "3. A aplicação Tkinter deve aparecer automaticamente"
echo ""
echo "🔧 Para corrigir problemas:"
echo "   sudo bash install/setup_pi_user.sh"
echo ""
echo "============================================" 