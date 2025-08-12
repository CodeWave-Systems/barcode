#!/bin/bash

# Script de deploy para Sistema de Scanner Raspberry Pi
# Execute com: bash scripts/deploy.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir com cores
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se está no diretório correto
if [ ! -f "requirements.txt" ] || [ ! -d "src" ]; then
    print_error "Execute este script do diretório raiz do projeto"
    exit 1
fi

print_status "🚀 Iniciando deploy do Sistema de Scanner Raspberry Pi..."

# Verificar sistema operacional
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_success "Raspberry Pi detectado"
        IS_RASPBERRY_PI=true
    else
        print_warning "Sistema Linux detectado (não é Raspberry Pi)"
        IS_RASPBERRY_PI=false
    fi
else
    print_warning "Sistema não-Linux detectado. Algumas funcionalidades podem não funcionar."
    IS_RASPBERRY_PI=false
fi

# Verificar se é root
if [ "$EUID" -eq 0 ]; then
    print_warning "Executando como root. Isso pode causar problemas de permissão."
    read -p "Continuar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Verificar Python
print_status "Verificando Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_success "Python $PYTHON_VERSION encontrado"
else
    print_error "Python 3 não encontrado. Instale Python 3.8+ primeiro."
    exit 1
fi

# Verificar pip
print_status "Verificando pip..."
if command -v pip3 &> /dev/null; then
    print_success "pip3 encontrado"
else
    print_error "pip3 não encontrado. Instale pip3 primeiro."
    exit 1
fi

# Criar diretórios necessários
print_status "Criando diretórios..."
mkdir -p data logs config backups
print_success "Diretórios criados"

# Verificar dependências do sistema
print_status "Verificando dependências do sistema..."
SYSTEM_DEPS=("git" "curl" "wget")

for dep in "${SYSTEM_DEPS[@]}"; do
    if command -v "$dep" &> /dev/null; then
        print_success "$dep encontrado"
    else
        print_warning "$dep não encontrado"
    fi
done

# Instalar dependências Python
print_status "Instalando dependências Python..."
if pip3 install -r requirements.txt; then
    print_success "Dependências Python instaladas"
else
    print_error "Falha ao instalar dependências Python"
    exit 1
fi

# Configurar permissões (se for Raspberry Pi)
if [ "$IS_RASPBERRY_PI" = true ]; then
    print_status "Configurando permissões para Raspberry Pi..."
    
    # Verificar se é root para configurar permissões
    if [ "$EUID" -eq 0 ]; then
        # Adicionar usuário aos grupos necessários
        CURRENT_USER=${SUDO_USER:-$USER}
        usermod -a -G input "$CURRENT_USER" 2>/dev/null || print_warning "Não foi possível adicionar usuário ao grupo input"
        usermod -a -G dialout "$CURRENT_USER" 2>/dev/null || print_warning "Não foi possível adicionar usuário ao grupo dialout"
        
        print_success "Permissões configuradas para usuário $CURRENT_USER"
    else
        print_warning "Execute com sudo para configurar permissões do sistema"
    fi
fi

# Testar sistema
print_status "Testando sistema..."
if python3 scripts/test_system.py; then
    print_success "Testes passaram com sucesso!"
else
    print_warning "Alguns testes falharam. Verifique os erros acima."
fi

# Configurar serviço systemd (se for Raspberry Pi e root)
if [ "$IS_RASPBERRY_PI" = true ] && [ "$EUID" -eq 0 ]; then
    print_status "Configurando serviço systemd..."
    
    CURRENT_USER=${SUDO_USER:-$USER}
    CURRENT_DIR=$(pwd)
    
    # Criar arquivo de serviço
    cat > /etc/systemd/system/scanner-system.service << EOF
[Unit]
Description=Sistema de Scanner Raspberry Pi
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$CURRENT_DIR
ExecStart=/usr/bin/python3 $CURRENT_DIR/src/app.py
Restart=always
RestartSec=10
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$CURRENT_USER/.Xauthority

[Install]
WantedBy=multi-user.target
EOF

    # Habilitar serviço
    systemctl daemon-reload
    systemctl enable scanner-system.service
    
    print_success "Serviço systemd configurado e habilitado"
    print_status "Para iniciar: sudo systemctl start scanner-system.service"
    print_status "Para ver status: sudo systemctl status scanner-system.service"
fi

# Configurar autostart (se não for root)
if [ "$EUID" -ne 0 ]; then
    print_status "Configurando autostart para usuário..."
    
    # Criar script de autostart
    AUTOSTART_DIR="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    
    cat > "$AUTOSTART_DIR/scanner-system.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Sistema de Scanner
Comment=Sistema de Scanner Raspberry Pi
Exec=python3 $(pwd)/src/app.py
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

    print_success "Autostart configurado para usuário"
fi

# Criar script de execução rápida
print_status "Criando script de execução rápida..."
cat > run_scanner.sh << 'EOF'
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

# Verificar dependências
if ! python3 -c "import customtkinter" 2>/dev/null; then
    echo "❌ Dependências não instaladas. Execute: pip3 install -r requirements.txt"
    exit 1
fi

# Executar aplicação
echo "✅ Iniciando aplicação..."
python3 src/app.py
EOF

chmod +x run_scanner.sh
print_success "Script de execução criado: ./run_scanner.sh"

# Criar script de configuração
print_status "Criando script de configuração..."
cat > configure.sh << 'EOF'
#!/bin/bash
# Script de configuração do sistema

cd "$(dirname "$0")"

echo "⚙️  Configurando Sistema de Scanner..."

# Verificar se é Raspberry Pi
if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo "✅ Raspberry Pi detectado"
    
    # Configurar rede
    echo "🌐 Configurando rede..."
    if command -v nmcli &> /dev/null; then
        echo "NetworkManager disponível"
        nmcli device status
    else
        echo "NetworkManager não disponível"
    fi
    
    # Configurar data/hora
    echo "🕐 Configurando data/hora..."
    if command -v timedatectl &> /dev/null; then
        timedatectl status
    else
        echo "timedatectl não disponível"
    fi
    
else
    echo "⚠️  Sistema não é Raspberry Pi"
fi

echo "✅ Configuração concluída!"
echo ""
echo "📋 Próximos passos:"
echo "1. Configure a rede Wi-Fi/Ethernet"
echo "2. Ative o dispositivo com sua chave de ativação"
echo "3. Execute: ./run_scanner.sh"
EOF

chmod +x configure.sh
print_success "Script de configuração criado: ./configure.sh"

# Criar arquivo de configuração de exemplo
print_status "Criando arquivo de configuração de exemplo..."
if [ ! -f "config/settings.py" ]; then
    print_warning "Arquivo de configuração não encontrado. Copiando exemplo..."
    cp config/settings.py.example config/settings.py 2>/dev/null || print_warning "Não foi possível copiar arquivo de exemplo"
fi

# Verificar arquivos importantes
print_status "Verificando arquivos importantes..."
IMPORTANT_FILES=("src/app.py" "config/settings.py" "requirements.txt")

for file in "${IMPORTANT_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "$file encontrado"
    else
        print_error "$file não encontrado"
    fi
done

# Resumo final
echo ""
echo "=========================================="
echo "🎉 DEPLOY CONCLUÍDO COM SUCESSO!"
echo "=========================================="
echo ""
echo "📁 Diretório do projeto: $(pwd)"
echo "🐍 Python: $(python3 --version)"
echo "📦 Dependências: Instaladas"
echo "🔧 Scripts criados:"
echo "   - ./run_scanner.sh (executar aplicação)"
echo "   - ./configure.sh (configurar sistema)"
echo ""

if [ "$IS_RASPBERRY_PI" = true ]; then
    echo "🍓 Raspberry Pi detectado!"
    if [ "$EUID" -eq 0 ]; then
        echo "⚙️  Serviço systemd configurado"
        echo "🔄 Sistema iniciará automaticamente no boot"
    else
        echo "⚠️  Execute com sudo para configurar serviço systemd"
    fi
fi

echo ""
echo "📋 PRÓXIMOS PASSOS:"
echo "1. Configure a rede: ./configure.sh"
echo "2. Execute a aplicação: ./run_scanner.sh"
echo "3. Ative o dispositivo com sua chave"
echo "4. Teste o scanner"
echo ""
echo "📚 Documentação: README.md"
echo "🧪 Testes: python3 scripts/test_system.py"
echo "=========================================="

print_success "Deploy concluído! 🚀" 