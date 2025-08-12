# Sistema de Scanner Raspberry Pi

Sistema completo e robusto para Raspberry Pi OS Lite com interface gráfica moderna, captura global de códigos de barras, sincronização offline e ativação via chave.

## 🎯 Características Principais

- **Interface Moderna**: GUI com CustomTkinter, responsiva e intuitiva
- **Captura Global**: Scanner funciona mesmo sem foco da janela (usando evdev)
- **Sincronização Offline**: Salva dados localmente e sincroniza automaticamente
- **Ativação Segura**: Sistema de ativação via chave com validação de token
- **Configuração de Rede**: Suporte Wi-Fi e Ethernet com interface gráfica
- **Configuração de Data/Hora**: Sincronização NTP e configuração manual
- **Modo Kiosk**: Execução automática e fullscreen para uso profissional
- **Monitoramento**: Logs detalhados e monitoramento de sistema

## 🏗️ Arquitetura do Sistema

```
ProjetoRaspberry/
├── src/                    # Código fonte principal
│   ├── app.py             # Aplicação GUI principal
│   ├── network.py         # Gerenciamento de rede
│   ├── activation.py      # Sistema de ativação
│   ├── scanner.py         # Captura de códigos de barras
│   ├── sync.py            # Sincronização offline
│   ├── datetime_config.py # Configuração de data/hora
│   └── utils.py           # Utilitários gerais
├── config/                 # Configurações
│   └── settings.py        # Configurações globais
├── install/                # Scripts de instalação
│   └── install.sh         # Instalador automático
├── requirements.txt        # Dependências Python
└── README.md              # Esta documentação
```

## 📋 Requisitos do Sistema

### Hardware
- Raspberry Pi 3B+ ou superior
- 1GB RAM mínimo (2GB recomendado)
- 8GB cartão SD mínimo
- Scanner USB de códigos de barras
- Monitor HDMI (opcional para headless)

### Software
- Raspberry Pi OS Lite (Bullseye ou superior)
- Python 3.8+
- Acesso root para instalação

## 🚀 Instalação Rápida

### 1. Preparar Raspberry Pi
```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependências básicas
sudo apt install -y git curl wget
```

### 2. Clonar Projeto
```bash
cd /opt
sudo git clone https://github.com/seu-usuario/ProjetoRaspberry.git scanner-system
sudo chown -R $USER:$USER scanner-system
cd scanner-system
```

### 3. Instalação Automática
```bash
# Executar script de instalação
sudo bash install/install.sh
```

### 4. Reiniciar Sistema
```bash
sudo reboot
```

## ⚙️ Instalação Manual

### 1. Dependências do Sistema
```bash
sudo apt install -y \
    python3 python3-pip python3-tk python3-dev \
    network-manager nmcli ntpdate hwclock wmctrl
```

### 2. Dependências Python
```bash
pip3 install -r requirements.txt
```

### 3. Configurar Permissões
```bash
# Adicionar usuário aos grupos necessários
sudo usermod -a -G input $USER
sudo usermod -a -G dialout $USER

# Configurar sudo para comandos específicos
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/date" | sudo tee /etc/sudoers.d/scanner-system
echo "$USER ALL=(ALL) NOPASSWD: /usr/sbin/hwclock" | sudo tee -a /etc/sudoers.d/scanner-system
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/timedatectl" | sudo tee -a /etc/sudoers.d/scanner-system
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/ntpdate" | sudo tee -a /etc/sudoers.d/scanner-system
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/nmcli" | sudo tee -a /etc/sudoers.d/scanner-system
```

### 4. Configurar Serviço
```bash
# Criar arquivo de serviço
sudo tee /etc/systemd/system/scanner-system.service > /dev/null << EOF
[Unit]
Description=Sistema de Scanner Raspberry Pi
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=/opt/scanner-system
ExecStart=/usr/bin/python3 /opt/scanner-system/src/app.py
Restart=always
RestartSec=10
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$USER/.Xauthority

[Install]
WantedBy=multi-user.target
EOF

# Habilitar serviço
sudo systemctl daemon-reload
sudo systemctl enable scanner-system.service
```

## 🔧 Configuração

### 1. Configuração de Rede
```bash
# Verificar status da rede
nmcli device status

# Conectar Wi-Fi
nmcli device wifi connect "SSID" password "SENHA"

# Conectar Ethernet
nmcli device connect eth0
```

### 2. Configuração de Data/Hora
```bash
# Sincronizar com NTP
sudo ntpdate -s pool.ntp.org

# Definir timezone
sudo timedatectl set-timezone America/Sao_Paulo

# Verificar status
timedatectl status
```

### 3. Configuração do Scanner
```bash
# Verificar dispositivos de entrada
ls /dev/input/event*

# Testar permissões
sudo -u $USER python3 -c "import evdev; print('evdev funcionando')"
```

## 🎮 Uso do Sistema

### 1. Primeira Execução
1. **Inicialização**: Sistema inicia automaticamente no boot
2. **Configuração de Rede**: Conectar Wi-Fi ou Ethernet
3. **Ativação**: Inserir chave de ativação fornecida
4. **Scanner**: Sistema está pronto para uso

### 2. Interface Principal
- **Tela de Boas-vindas**: Status do sistema e opções
- **Tela de Scanner**: Captura e exibição de códigos
- **Configurações**: Rede, data/hora e sistema
- **Status**: Informações em tempo real

### 3. Operação do Scanner
- **Captura Automática**: Scanner detecta códigos automaticamente
- **Feedback Visual**: Confirmação de cada código escaneado
- **Sincronização**: Envio automático para servidor
- **Modo Offline**: Armazenamento local quando sem internet

## 📊 Monitoramento e Logs

### 1. Logs do Sistema
```bash
# Logs da aplicação
tail -f /opt/scanner-system/logs/scanner.log

# Logs do sistema
sudo journalctl -u scanner-system.service -f

# Logs de temperatura
tail -f /opt/scanner-system/logs/temperature.log
```

### 2. Status do Serviço
```bash
# Verificar status
sudo systemctl status scanner-system.service

# Reiniciar serviço
sudo systemctl restart scanner-system.service

# Ver logs em tempo real
sudo journalctl -u scanner-system.service -f
```

### 3. Monitoramento de Recursos
```bash
# Temperatura do CPU
vcgencmd measure_temp

# Uso de memória
free -h

# Espaço em disco
df -h

# Uptime do sistema
uptime
```

## 🔒 Segurança

### 1. Firewall
```bash
# Verificar status
sudo ufw status

# Configurar regras
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### 2. Atualizações
```bash
# Atualizações automáticas
sudo apt update && sudo apt upgrade -y

# Verificar dependências Python
pip3 list --outdated
```

### 3. Backup
```bash
# Backup manual
tar -czf backup_$(date +%Y%m%d).tar.gz /opt/scanner-system/data

# Verificar backups automáticos
ls -la /opt/scanner-system/backups/
```

## 🚨 Solução de Problemas

### 1. Scanner Não Funciona
```bash
# Verificar permissões
ls -la /dev/input/event*

# Verificar grupos do usuário
groups $USER

# Testar evdev
python3 -c "import evdev; print('evdev OK')"
```

### 2. Problemas de Rede
```bash
# Verificar status
nmcli device status

# Reiniciar NetworkManager
sudo systemctl restart NetworkManager

# Verificar conectividade
ping -c 3 8.8.8.8
```

### 3. Problemas de Ativação
```bash
# Verificar token
cat /opt/scanner-system/config/token.json

# Verificar logs
tail -f /opt/scanner-system/logs/scanner.log

# Reativar dispositivo
rm /opt/scanner-system/config/token.json
```

### 4. Problemas de Interface
```bash
# Verificar X11
echo $DISPLAY

# Verificar permissões
ls -la ~/.Xauthority

# Reiniciar X11
sudo systemctl restart lightdm
```

## 📈 Manutenção

### 1. Limpeza de Logs
```bash
# Limpar logs antigos
sudo find /opt/scanner-system/logs -name "*.log.*" -mtime +7 -delete

# Verificar espaço usado
du -sh /opt/scanner-system/logs/
```

### 2. Backup de Dados
```bash
# Backup manual
sudo tar -czf /opt/scanner-system/backups/manual_$(date +%Y%m%d_%H%M%S).tar.gz \
    -C /opt/scanner-system data config

# Restaurar backup
sudo tar -xzf /opt/scanner-system/backups/backup_arquivo.tar.gz -C /opt/scanner-system
```

### 3. Atualizações
```bash
# Atualizar código
cd /opt/scanner-system
sudo git pull origin main

# Atualizar dependências
pip3 install -r requirements.txt --upgrade

# Reiniciar serviço
sudo systemctl restart scanner-system.service
```

## 🔧 Configurações Avançadas

### 1. Personalização da Interface
```python
# Editar config/settings.py
GUI_CONFIG = {
    "fullscreen": True,
    "width": 1024,        # Alterar resolução
    "height": 768,
    "theme": "dark",      # Tema: "dark" ou "light"
    "title": "Meu Scanner"
}
```

### 2. Configuração de API
```python
# Editar config/settings.py
API_BASE_URL = "https://minha-api.com"
API_ENDPOINTS = {
    "ativar": "/api/ativar",
    "registrar": "/api/registrar",
    "status": "/api/status"
}
```

### 3. Configuração de Scanner
```python
# Editar config/settings.py
SCANNER_CONFIG = {
    "timeout": 3.0,           # Timeout do scanner
    "max_retries": 5,         # Tentativas de envio
    "sync_interval": 1800,    # Sincronização a cada 30 min
}
```

## 📚 API Endpoints

### 1. Ativação
```http
POST /ativar_raspberry
Content-Type: application/json

{
    "activation_key": "chave123",
    "device_serial": "serial_raspberry",
    "device_type": "raspberry_pi",
    "platform": "linux",
    "timestamp": "2023-12-25T10:30:00"
}
```

### 2. Registro de Código
```http
POST /registrar_codigo
Authorization: Bearer <token>
Content-Type: application/json

{
    "code": "123456789",
    "timestamp": "2023-12-25T10:30:00",
    "device_id": "device_123",
    "metadata": {}
}
```

### 3. Status do Dispositivo
```http
POST /status_raspberry
Authorization: Bearer <token>
Content-Type: application/json

{
    "device_id": "device_123",
    "timestamp": "2023-12-25T10:30:00"
}
```

## 🤝 Contribuição

### 1. Reportar Bugs
- Use as Issues do GitHub
- Inclua logs e informações do sistema
- Descreva os passos para reproduzir

### 2. Sugestões
- Abra uma Issue com label "enhancement"
- Descreva a funcionalidade desejada
- Inclua casos de uso

### 3. Pull Requests
- Fork o projeto
- Crie uma branch para sua feature
- Siga o padrão de código
- Inclua testes se possível

## 📄 Licença

Este projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 📞 Suporte

- **Documentação**: Este README
- **Issues**: [GitHub Issues](https://github.com/seu-usuario/ProjetoRaspberry/issues)
- **Email**: suporte@exemplo.com
- **Telefone**: +55 (11) 99999-9999

## 🙏 Agradecimentos

- Raspberry Pi Foundation
- Comunidade Python
- Contribuidores do projeto
- Usuários beta testers

---

**Versão**: 1.0.0  
**Última Atualização**: Dezembro 2023  
**Desenvolvido por**: Sua Empresa/Equipe
# Sistema de Scanner Raspberry Pi

## 🚀 **AUTOSTART AUTOMÁTICO - SEM LOGIN**

### **Configuração Rápida (RECOMENDADA)**
```bash
# Execute o script para configurar autostart automático
sudo bash install/quick_autostart.sh

# Reinicie o sistema
sudo reboot
```

### **Resultado**
- ✅ **Sistema inicia automaticamente** sem pedir login/senha
- ✅ **Vai direto para a aplicação Tkinter**
- ✅ **Funciona como um kiosk profissional**

### **Documentação Completa**
- 📖 [Guia de Autostart](AUTOSTART_GUIDE.md) - Configuração detalhada
- 🔧 [Troubleshooting](TROUBLESHOOTING.md) - Solução de problemas
- ⚡ [Script Rápido](install/quick_autostart.sh) - Configuração em 1 comando

---

# Sistema de Scanner Raspberry Pi