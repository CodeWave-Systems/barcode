"""
Configurações globais do sistema de scanner Raspberry Pi
"""

import os
from pathlib import Path

# Diretórios base
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
LOGS_DIR = BASE_DIR / "logs"
CONFIG_DIR = BASE_DIR / "config"

# Criar diretórios se não existirem
DATA_DIR.mkdir(exist_ok=True)
LOGS_DIR.mkdir(exist_ok=True)
CONFIG_DIR.mkdir(exist_ok=True)

# Arquivos de dados
TOKEN_FILE = CONFIG_DIR / "token.json"
PENDING_FILE = DATA_DIR / "pendentes.csv"
LOGS_FILE = LOGS_DIR / "scanner.log"
SETTINGS_FILE = CONFIG_DIR / "settings.json"

# Configurações da API
API_BASE_URL = "https://api.exemplo.com"  # Alterar para URL real
API_ENDPOINTS = {
    "ativar": "/ativar_raspberry",
    "registrar": "/registrar_codigo",
    "status": "/status_raspberry"
}

# Configurações do scanner
SCANNER_CONFIG = {
    "timeout": 5.0,  # timeout para leitura do scanner
    "max_retries": 3,  # tentativas de envio
    "sync_interval": 3600,  # sincronização a cada hora (segundos)
}

# Configurações da interface
GUI_CONFIG = {
    "fullscreen": True,
    "width": 800,
    "height": 600,
    "theme": "dark",
    "title": "Sistema de Scanner - Raspberry Pi"
}

# Configurações de rede
NETWORK_CONFIG = {
    "wifi_scan_timeout": 10,
    "connection_timeout": 30,
    "retry_attempts": 3
}

# Configurações de log
LOG_CONFIG = {
    "level": "INFO",
    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    "max_size": 10 * 1024 * 1024,  # 10MB
    "backup_count": 5
} 