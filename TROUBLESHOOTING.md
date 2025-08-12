# 🔧 Guia de Solução de Problemas

## ❌ Problemas Comuns de Instalação

### 1. **Erro: "Unable to locate package nmcli"**

**Problema**: O pacote `nmcli` não está disponível no seu sistema.

**Soluções**:

#### **Opção A: Instalação Manual**
```bash
# Para Debian/Ubuntu/Raspberry Pi OS
sudo apt update
sudo apt install -y network-manager network-manager-cli

# Para CentOS/RHEL/Fedora
sudo yum install -y NetworkManager NetworkManager-cli

# Para Arch Linux
sudo pacman -S --noconfirm networkmanager
```

#### **Opção B: Usar Script Minimalista**
```bash
# Execute o script de instalação minimalista
sudo bash install/install_minimal.sh
```

#### **Opção C: Verificar Disponibilidade**
```bash
# Verificar se o pacote existe
apt search network-manager-cli

# Ou procurar por alternativas
apt search network-manager
```

### 2. **Erro: "Unable to locate package hwclock"**

**Problema**: O comando `hwclock` não está disponível.

**Soluções**:

#### **Opção A: Instalar util-linux**
```bash
# Para Debian/Ubuntu/Raspberry Pi OS
sudo apt install -y util-linux

# Para CentOS/RHEL/Fedora
sudo yum install -y util-linux

# Para Arch Linux
sudo pacman -S --noconfirm util-linux
```

#### **Opção B: Verificar se já está instalado**
```bash
# Verificar se hwclock está disponível
which hwclock

# Verificar se está em outro local
find /usr -name "hwclock" 2>/dev/null
```

### 3. **Erro: "Package not found" para outros pacotes**

**Problema**: Alguns pacotes podem não estar disponíveis em todas as distribuições.

**Soluções**:

#### **Verificar Distribuição**
```bash
# Verificar qual distribuição você está usando
cat /etc/os-release

# Ou
lsb_release -a
```

#### **Atualizar Repositórios**
```bash
# Para Debian/Ubuntu/Raspberry Pi OS
sudo apt update

# Para CentOS/RHEL/Fedora
sudo yum update

# Para Arch Linux
sudo pacman -Sy
```

#### **Instalar Repositórios Adicionais**
```bash
# Para Debian/Ubuntu
sudo apt install -y software-properties-common
sudo add-apt-repository universe
sudo apt update

# Para CentOS/RHEL
sudo yum install -y epel-release
sudo yum update
```

### 4. **Erro: "Permission denied" para evdev**

**Problema**: O módulo `evdev` requer permissões especiais.

**Soluções**:

#### **Verificar Permissões**
```bash
# Verificar grupos do usuário
groups $USER

# Adicionar usuário aos grupos necessários
sudo usermod -a -G input $USER
sudo usermod -a -G dialout $USER

# Reiniciar sessão ou fazer logout/login
```

#### **Verificar Dispositivos de Entrada**
```bash
# Listar dispositivos de entrada
ls -la /dev/input/

# Verificar permissões
ls -la /dev/input/event*

# Verificar se o usuário tem acesso
sudo -u $USER ls /dev/input/event0
```

### 5. **Erro: "Python module not found"**

**Problema**: Módulos Python não podem ser importados.

**Soluções**:

#### **Verificar Instalação**
```bash
# Verificar versão do Python
python3 --version

# Verificar pip
pip3 --version

# Listar módulos instalados
pip3 list
```

#### **Reinstalar Módulos**
```bash
# Atualizar pip
pip3 install --upgrade pip

# Instalar módulos individualmente
pip3 install customtkinter==5.2.2
pip3 install requests==2.31.0
pip3 install APScheduler==3.10.4
```

#### **Usar Requisitos Alternativos**
```bash
# Se evdev falhar, usar pynput
pip3 install pynput==1.7.6

# Se netifaces falhar, usar alternativas do sistema
pip3 install psutil==5.9.6
```

---

## 🚀 **SOLUÇÕES RÁPIDAS**

### **Solução 1: Instalação Minimalista (Recomendada para problemas)**
```bash
# Execute o script minimalista que lida com dependências faltantes
sudo bash install/install_minimal.sh
```

### **Solução 2: Instalação Manual Passo a Passo**
```bash
# 1. Atualizar sistema
sudo apt update && sudo apt upgrade -y

# 2. Instalar dependências básicas
sudo apt install -y python3 python3-pip python3-tk python3-dev git

# 3. Instalar dependências Python essenciais
pip3 install customtkinter requests python-dateutil psutil

# 4. Tentar dependências opcionais
pip3 install APScheduler pynput

# 5. Configurar permissões
sudo usermod -a -G input $USER
sudo usermod -a -G dialout $USER
```

### **Solução 3: Verificação de Sistema**
```bash
# Verificar se é Raspberry Pi
grep -q "Raspberry Pi" /proc/cpuinfo && echo "É Raspberry Pi" || echo "Não é Raspberry Pi"

# Verificar arquitetura
uname -m

# Verificar distribuição
cat /etc/os-release | grep PRETTY_NAME

# Verificar Python
python3 --version
pip3 --version
```

---

## 🔍 **DIAGNÓSTICO DE PROBLEMAS**

### **Script de Diagnóstico**
```bash
# Execute o script de teste para identificar problemas
python3 scripts/test_system.py

# Ou o teste básico se estiver usando instalação minimalista
python3 test_basic.py
```

### **Verificação de Logs**
```bash
# Verificar logs do sistema
sudo journalctl -xe

# Verificar logs de instalação
cat /opt/scanner-system/install-status.txt

# Verificar permissões
ls -la /opt/scanner-system/
```

---

## 📋 **CHECKLIST DE VERIFICAÇÃO**

### **Antes da Instalação**
- [ ] Sistema atualizado (`sudo apt update && sudo apt upgrade`)
- [ ] Python 3.8+ instalado (`python3 --version`)
- [ ] pip3 instalado (`pip3 --version`)
- [ ] Acesso root (`sudo -v`)

### **Durante a Instalação**
- [ ] Dependências do sistema instaladas
- [ ] Dependências Python instaladas
- [ ] Permissões configuradas
- [ ] Serviços configurados

### **Após a Instalação**
- [ ] Script de teste passa (`python3 test_basic.py`)
- [ ] Aplicação inicia (`./run_scanner.sh`)
- [ ] Scanner detecta dispositivos
- [ ] Interface gráfica funciona

---

## 🆘 **CONTATO PARA SUPORTE**

### **Informações Necessárias**
Quando reportar um problema, inclua:

1. **Distribuição**: `cat /etc/os-release`
2. **Arquitetura**: `uname -m`
3. **Python**: `python3 --version`
4. **Erro completo**: Copie a mensagem de erro
5. **Logs**: `cat /opt/scanner-system/install-status.txt`

### **Canais de Suporte**
- **Issues do GitHub**: [Link do projeto]
- **Email**: suporte@exemplo.com
- **Documentação**: README.md

---

## 💡 **DICAS IMPORTANTES**

### **Para Raspberry Pi**
- Use **Raspberry Pi OS Lite** para melhor performance
- Conecte via **SSH** para instalação headless
- Use **cartão SD de classe 10** ou superior

### **Para Outros Sistemas**
- **Ubuntu/Debian**: Geralmente funciona sem problemas
- **CentOS/RHEL**: Pode precisar de repositórios adicionais
- **Arch Linux**: Pacotes podem ter nomes diferentes

### **Para Desenvolvimento**
- Use **ambiente virtual** Python para testes
- Teste em **máquina virtual** antes de produção
- Mantenha **backup** das configurações

---

**🎯 Lembre-se**: Se encontrar problemas, comece com a **instalação minimalista** e depois adicione funcionalidades conforme necessário! 