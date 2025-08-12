# 🚀 Guia de Autostart Automático - Sem Login

## 🎯 **OBJETIVO**
Configurar o Raspberry Pi para:
- ✅ **Iniciar automaticamente** sem pedir login/senha
- ✅ **Ir direto para a aplicação Tkinter**
- ✅ **Funcionar como um kiosk** profissional

---

## 🔧 **OPÇÕES DE CONFIGURAÇÃO**

### **Opção 1: Configuração Rápida (RECOMENDADA)**
```bash
# Execute o script rápido
sudo bash install/quick_autostart.sh
```

### **Opção 2: Configuração Completa**
```bash
# Execute o script completo
sudo bash install/autostart_config.sh
```

### **Opção 3: Configuração Manual**
Siga os passos manuais abaixo.

---

## 🚀 **CONFIGURAÇÃO RÁPIDA (RECOMENDADA)**

### **1. Executar Script**
```bash
cd /opt/scanner-system
sudo bash install/quick_autostart.sh
```

### **2. Reiniciar Sistema**
```bash
sudo reboot
```

### **3. Verificar Funcionamento**
- A aplicação Tkinter deve aparecer automaticamente
- Não deve pedir login/senha
- Deve funcionar como um kiosk

---

## 🔍 **O QUE O SCRIPT FAZ**

### **Configurações Aplicadas:**
1. **Auto-login** no LXDE (Raspberry Pi OS)
2. **Autostart** da aplicação Tkinter
3. **Execução automática** no .bashrc
4. **Modo gráfico** habilitado
5. **Boot silencioso** (sem mensagens)
6. **Serviço systemd** para auto-iniciar
7. **Múltiplos pontos** de execução automática

### **Arquivos Criados/Modificados:**
- `/etc/lxdm/lxdm.conf` - Auto-login
- `/etc/xdg/lxsession/LXDE-pi/autostart/` - Autostart LXDE
- `/home/USER/.bashrc` - Execução automática
- `/etc/systemd/system/scanner-app.service` - Serviço systemd
- `/opt/scanner-system/start_app.sh` - Script de execução

---

## 🛠️ **CONFIGURAÇÃO MANUAL**

### **1. Configurar Auto-Login LXDE**
```bash
# Editar arquivo de configuração
sudo nano /etc/lxdm/lxdm.conf

# Adicionar/modificar estas linhas:
autologin=SEU_USUARIO
timeout=0
```

### **2. Configurar Autostart da Aplicação**
```bash
# Criar diretório de autostart
mkdir -p /etc/xdg/lxsession/LXDE-pi/autostart

# Criar arquivo de autostart
echo "@python3 /opt/scanner-system/src/app.py" > /etc/xdg/lxsession/LXDE-pi/autostart/scanner-system
```

### **3. Configurar Execução no .bashrc**
```bash
# Editar .bashrc do usuário
nano ~/.bashrc

# Adicionar no final:
if [ -n "$DISPLAY" ]; then
    sleep 3
    if ! pgrep -f "scanner-system" > /dev/null; then
        if [ -f "/opt/scanner-system/src/app.py" ]; then
            cd /opt/scanner-system
            python3 src/app.py &
        fi
    fi
fi
```

### **4. Configurar Modo Gráfico**
```bash
# Editar configuração do Raspberry Pi
sudo nano /etc/default/raspi-config

# Alterar:
BOOT_TO_CLI=0
```

### **5. Configurar Boot Silencioso**
```bash
# Editar cmdline.txt
sudo nano /boot/cmdline.txt

# Adicionar no final:
quiet logo.nologo
```

---

## 🔧 **VERIFICAÇÃO E TROUBLESHOOTING**

### **Verificar Status dos Serviços**
```bash
# Verificar serviço principal
sudo systemctl status scanner-app.service

# Verificar logs
sudo journalctl -u scanner-app.service -f

# Verificar se está rodando
ps aux | grep scanner-system
```

### **Verificar Configurações**
```bash
# Verificar auto-login
cat /etc/lxdm/lxdm.conf | grep autologin

# Verificar autostart
ls -la /etc/xdg/lxsession/LXDE-pi/autostart/

# Verificar .bashrc
tail -10 ~/.bashrc

# Verificar modo gráfico
cat /etc/default/raspi-config | grep BOOT_TO_CLI
```

### **Testar Manualmente**
```bash
# Testar se a aplicação inicia
cd /opt/scanner-system
python3 src/app.py

# Testar script de execução
./start_app.sh
```

---

## ❌ **PROBLEMAS COMUNS E SOLUÇÕES**

### **1. Aplicação Não Inicia Automaticamente**

**Sintomas**: Sistema inicia, mas aplicação não aparece.

**Soluções**:
```bash
# Verificar logs
sudo journalctl -u scanner-app.service -f

# Verificar se o arquivo existe
ls -la /opt/scanner-system/src/app.py

# Testar execução manual
cd /opt/scanner-system
python3 src/app.py

# Verificar permissões
ls -la /opt/scanner-system/
```

### **2. Tela de Login Ainda Aparece**

**Sintomas**: Sistema ainda pede login/senha.

**Soluções**:
```bash
# Verificar configuração LXDE
cat /etc/lxdm/lxdm.conf | grep autologin

# Verificar se o usuário está correto
whoami

# Reconfigurar auto-login
sudo bash install/quick_autostart.sh
```

### **3. Aplicação Inicia mas Fecha**

**Sintomas**: Aplicação aparece e fecha rapidamente.

**Soluções**:
```bash
# Verificar logs da aplicação
tail -f /opt/scanner-system/logs/scanner.log

# Verificar dependências
python3 -c "import customtkinter; print('OK')"

# Testar em modo debug
cd /opt/scanner-system
python3 -u src/app.py
```

### **4. Sistema Inicia em Modo Texto**

**Sintomas**: Sistema inicia em terminal, não em modo gráfico.

**Soluções**:
```bash
# Verificar configuração
cat /etc/default/raspi-config | grep BOOT_TO_CLI

# Configurar modo gráfico
sudo raspi-config

# Ou editar manualmente
sudo nano /etc/default/raspi-config
# BOOT_TO_CLI=0
```

---

## 🔄 **REVERTER CONFIGURAÇÕES**

### **Se Algo Não Funcionar**
```bash
# Fazer backup das configurações originais
sudo cp /etc/lxdm/lxdm.conf /etc/lxdm/lxdm.conf.backup
sudo cp ~/.bashrc ~/.bashrc.backup

# Reverter auto-login
sudo nano /etc/lxdm/lxdm.conf
# Comentar ou remover linha: autologin=USUARIO

# Reverter .bashrc
nano ~/.bashrc
# Remover ou comentar as linhas do scanner-system

# Reiniciar
sudo reboot
```

---

## 📋 **CHECKLIST DE VERIFICAÇÃO**

### **Antes da Configuração**
- [ ] Sistema atualizado (`sudo apt update && sudo apt upgrade`)
- [ ] Aplicação funcionando manualmente (`python3 src/app.py`)
- [ ] Usuário tem permissões adequadas
- [ ] Backup das configurações originais

### **Após a Configuração**
- [ ] Sistema inicia automaticamente
- [ ] Não pede login/senha
- [ ] Aplicação Tkinter aparece automaticamente
- [ ] Funciona como kiosk (sem barra de título)
- [ ] Reinicia automaticamente se fechar

### **Verificações Finais**
- [ ] `sudo systemctl status scanner-app.service` mostra "active"
- [ ] `ps aux | grep scanner-system` mostra processo rodando
- [ ] Logs não mostram erros críticos
- [ ] Aplicação responde ao scanner

---

## 🎯 **RESULTADO FINAL**

Após a configuração bem-sucedida, seu Raspberry Pi deve:

1. **Iniciar automaticamente** sem pedir credenciais
2. **Carregar o desktop** em modo gráfico
3. **Executar a aplicação Tkinter** automaticamente
4. **Funcionar como um kiosk** profissional
5. **Reiniciar automaticamente** se houver problemas

---

## 🆘 **SUPORTE**

### **Se Nada Funcionar**
1. **Execute o script completo**: `sudo bash install/autostart_config.sh`
2. **Verifique os logs**: `sudo journalctl -u scanner-app.service -f`
3. **Teste manualmente**: `cd /opt/scanner-system && python3 src/app.py`
4. **Consulte o troubleshooting**: `TROUBLESHOOTING.md`

### **Informações para Suporte**
```bash
# Coletar informações do sistema
cat /etc/os-release
uname -a
cat /opt/scanner-system/quick-autostart-status.txt
sudo systemctl status scanner-app.service
```

---

**🎉 Com essas configurações, seu Raspberry Pi funcionará como um verdadeiro kiosk profissional!** 