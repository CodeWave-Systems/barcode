#!/bin/bash

# Script de instalação minimalista para Sistema de Scanner
# Execute com: sudo bash install_minimal.sh

set -e

echo "=========================================="
echo "Instalação Minimalista do Sistema de Scanner"
echo "=========================================="

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script deve ser executado como root (sudo)"
    exit 1
fi

# Atualizar sistema
echo "🔄 Atualizando sistema..."
if command -v apt &> /dev/null; then
    apt update && apt upgrade -y
elif command -v yum &> /dev/null; then
    yum update -y
elif command -v dnf &> /dev/null; then
    dnf update -y
elif command -v pacman &> /dev/null; then
    pacman -Syu --noconfirm
fi

# Instalar dependências básicas
echo "📦 Instalando dependências básicas..."
if command -v apt &> /dev/null; then
    # Debian/Ubuntu/Raspberry Pi OS
    apt install -y python3 python3-pip python3-tk python3-dev git curl wget
elif command -v yum &> /dev/null; then
    # CentOS/RHEL/Fedora
    yum install -y python3 python3-pip python3-tkinter python3-devel git curl wget
elif command -v dnf &> /dev/null; then
    # Fedora mais recente
    dnf install -y python3 python3-pip python3-tkinter python3-devel git curl wget
elif command -v pacman &> /dev/null; then
    # Arch Linux
    pacman -S --noconfirm python python-pip tk git curl wget
else
    echo "⚠️  Gerenciador de pacotes não reconhecido. Instale manualmente:"
    echo "   - Python 3.8+"
    echo "   - pip3"
    echo "   - tkinter"
    echo "   - git, curl, wget"
fi

# Verificar Python
echo "🐍 Verificando Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo "✅ Python $PYTHON_VERSION encontrado"
else
    echo "❌ Python 3 não encontrado. Instale Python 3.8+ primeiro."
    exit 1
fi

# Verificar pip
echo "📦 Verificando pip..."
if command -v pip3 &> /dev/null; then
    echo "✅ pip3 encontrado"
else
    echo "❌ pip3 não encontrado. Instale pip3 primeiro."
    exit 1
fi

# Criar diretórios necessários
echo "📁 Criando diretórios..."
mkdir -p /opt/scanner-system/{data,logs,config,backups}
chown -R $SUDO_USER:$SUDO_USER /opt/scanner-system

# Instalar dependências Python essenciais
echo "🐍 Instalando dependências Python..."
pip3 install --upgrade pip

# Lista de dependências essenciais
ESSENTIAL_DEPS=(
    "customtkinter==5.2.2"
    "requests==2.31.0"
    "python-dateutil==2.8.2"
    "psutil==5.9.6"
)

# Tentar instalar dependências opcionais
OPTIONAL_DEPS=(
    "APScheduler==3.10.4"
    "evdev==1.6.1"
    "netifaces==0.11.0"
    "pynput==1.7.6"
)

echo "📦 Instalando dependências essenciais..."
for dep in "${ESSENTIAL_DEPS[@]}"; do
    echo "  Instalando $dep..."
    if pip3 install "$dep"; then
        echo "    ✅ $dep instalado"
    else
        echo "    ❌ Falha ao instalar $dep"
        exit 1
    fi
done

echo "📦 Tentando instalar dependências opcionais..."
for dep in "${OPTIONAL_DEPS[@]}"; do
    echo "  Tentando $dep..."
    if pip3 install "$dep"; then
        echo "    ✅ $dep instalado"
    else
        echo "    ⚠️  $dep não pôde ser instalado (continuando...)"
    fi
done

# Configurar permissões básicas
echo "🔐 Configurando permissões básicas..."
usermod -a -G input $SUDO_USER 2>/dev/null || echo "⚠️  Não foi possível adicionar usuário ao grupo input"
usermod -a -G dialout $SUDO_USER 2>/dev/null || echo "⚠️  Não foi possível adicionar usuário ao grupo dialout"

# Configurar serviço systemd (se disponível)
echo "⚙️  Configurando serviço..."
if command -v systemctl &> /dev/null; then
    cat > /etc/systemd/system/scanner-system.service << EOF
[Unit]
Description=Sistema de Scanner
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

    systemctl daemon-reload
    systemctl enable scanner-system.service
    echo "✅ Serviço systemd configurado"
else
    echo "⚠️  systemctl não disponível. Configure o serviço manualmente."
fi

# Configurar autostart básico
echo "🖥️  Configurando autostart..."
AUTOSTART_PATHS=(
    "/etc/xdg/lxsession/LXDE-pi/autostart"
    "/etc/xdg/lxsession/LXDE/autostart"
    "/etc/xdg/autostart"
    "$HOME/.config/autostart"
)

AUTOSTART_CONFIGURED=false
for path in "${AUTOSTART_PATHS[@]}"; do
    if [ -f "$path" ] || [ -d "$(dirname "$path")" ]; then
        if [ -f "$path" ]; then
            # Arquivo existe, adicionar linha
            echo "@python3 /opt/scanner-system/src/app.py" >> "$path"
        else
            # Diretório existe, criar arquivo
            mkdir -p "$(dirname "$path")"
            echo "@python3 /opt/scanner-system/src/app.py" > "$path"
        fi
        echo "✅ Autostart configurado em $path"
        AUTOSTART_CONFIGURED=true
        break
    fi
done

if [ "$AUTOSTART_CONFIGURED" = false ]; then
    echo "⚠️  Não foi possível configurar autostart. Configure manualmente."
fi

# Configurar permissões sudo básicas
echo "🔓 Configurando permissões sudo..."
cat > /etc/sudoers.d/scanner-system << EOF
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/date
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/timedatectl
$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/ntpdate
EOF

# Adicionar permissões condicionais
if command -v hwclock &> /dev/null; then
    echo "$SUDO_USER ALL=(ALL) NOPASSWD: /usr/sbin/hwclock" >> /etc/sudoers.d/scanner-system
fi

if command -v nmcli &> /dev/null; then
    echo "$SUDO_USER ALL=(ALL) NOPASSWD: /usr/bin/nmcli" >> /etc/sudoers.d/scanner-system
fi

echo "✅ Permissões sudo configuradas"

# Criar script de execução
echo "📝 Criando script de execução..."
cat > /opt/scanner-system/run_scanner.sh << 'EOF'
#!/bin/bash
# Script para executar o sistema de scanner

cd "$(dirname "$0")"

echo "🚀 Iniciando Sistema de Scanner..."
echo "Diretório: $(pwd)"

# Verificar se Python está disponível
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 não encontrado"
    exit 1
fi

# Verificar dependências básicas
if ! python3 -c "import customtkinter" 2>/dev/null; then
    echo "❌ customtkinter não encontrado. Execute: pip3 install -r requirements.txt"
    exit 1
fi

if ! python3 -c "import requests" 2>/dev/null; then
    echo "❌ requests não encontrado. Execute: pip3 install -r requirements.txt"
    exit 1
fi

# Executar aplicação
echo "✅ Iniciando aplicação..."
python3 src/app.py
EOF

chmod +x /opt/scanner-system/run_scanner.sh
echo "✅ Script de execução criado"

# Criar script de teste
echo "🧪 Criando script de teste..."
cat > /opt/scanner-system/test_basic.py << 'EOF'
#!/usr/bin/env python3
"""
Teste básico do sistema
"""

import sys
import importlib

def test_import(module_name, required=True):
    """Testa se um módulo pode ser importado"""
    try:
        importlib.import_module(module_name)
        print(f"✅ {module_name}")
        return True
    except ImportError as e:
        if required:
            print(f"❌ {module_name}: {e}")
            return False
        else:
            print(f"⚠️  {module_name}: {e}")
            return False

def main():
    """Função principal de teste"""
    print("🧪 Teste básico do sistema...")
    print("=" * 40)
    
    # Testes essenciais
    essential_modules = [
        "customtkinter",
        "requests",
        "python-dateutil",
        "psutil"
    ]
    
    print("📦 Testando módulos essenciais:")
    essential_ok = True
    for module in essential_modules:
        if not test_import(module, required=True):
            essential_ok = False
    
    # Testes opcionais
    optional_modules = [
        "APScheduler",
        "evdev",
        "netifaces",
        "pynput"
    ]
    
    print("\n📦 Testando módulos opcionais:")
    for module in optional_modules:
        test_import(module, required=False)
    
    # Teste de diretórios
    print("\n📁 Testando diretórios:")
    import os
    dirs_to_check = ["data", "logs", "config", "backups"]
    for dir_name in dirs_to_check:
        if os.path.exists(dir_name):
            print(f"✅ {dir_name}/")
        else:
            print(f"❌ {dir_name}/ (não encontrado)")
    
    print("\n" + "=" * 40)
    if essential_ok:
        print("🎉 Teste básico passou! Sistema funcionando.")
        return 0
    else:
        print("❌ Teste básico falhou. Verifique as dependências.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
EOF

chmod +x /opt/scanner-system/test_basic.py
echo "✅ Script de teste criado"

# Criar arquivo de status
echo "📄 Criando arquivo de status..."
cat > /opt/scanner-system/install-status.txt << EOF
Instalação minimalista concluída em: $(date)
Usuário: $SUDO_USER
Versão: 1.0.0
Status: ✅ Sucesso (Minimalista)
Sistema: $(uname -a)
Distribuição: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "Desconhecida")
Python: $(python3 --version 2>/dev/null || echo "Desconhecida")
EOF

echo "=========================================="
echo "✅ Instalação minimalista concluída!"
echo "=========================================="
echo ""
echo "📋 Próximos passos:"
echo "1. Copie os arquivos do projeto para /opt/scanner-system/"
echo "2. Execute: cd /opt/scanner-system"
echo "3. Teste: python3 test_basic.py"
echo "4. Execute: ./run_scanner.sh"
echo ""
echo "📁 Arquivos instalados em: /opt/scanner-system"
echo "🔧 Script de execução: ./run_scanner.sh"
echo "🧪 Script de teste: python3 test_basic.py"
echo ""
echo "⚠️  NOTA: Esta é uma instalação minimalista."
echo "   Algumas funcionalidades podem não funcionar completamente."
echo "   Para instalação completa, use: install.sh"
echo "==========================================" 