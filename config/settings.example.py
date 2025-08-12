"""
Arquivo de configuração de exemplo para o Sistema de Scanner Raspberry Pi
Copie este arquivo para settings.py e configure conforme necessário
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

# =============================================================================
# CONFIGURAÇÕES DA API - ALTERAR PARA SUAS CONFIGURAÇÕES REAIS
# =============================================================================

# URL base da sua API
API_BASE_URL = "https://sua-api.com"  # ⚠️ ALTERAR: URL da sua API

# Endpoints da API
API_ENDPOINTS = {
    "ativar": "/api/ativar_raspberry",      # ⚠️ ALTERAR: Endpoint de ativação
    "registrar": "/api/registrar_codigo",   # ⚠️ ALTERAR: Endpoint de registro
    "status": "/api/status_raspberry"       # ⚠️ ALTERAR: Endpoint de status
}

# =============================================================================
# CONFIGURAÇÕES DO SCANNER
# =============================================================================

SCANNER_CONFIG = {
    "timeout": 5.0,           # Timeout para leitura do scanner (segundos)
    "max_retries": 3,         # Número máximo de tentativas de envio
    "sync_interval": 3600,    # Intervalo de sincronização (segundos) - 1 hora
    "key_timeout": 0.1,       # Timeout entre teclas do scanner (segundos)
    "max_buffer_size": 1000,  # Tamanho máximo do buffer de códigos
}

# =============================================================================
# CONFIGURAÇÕES DA INTERFACE GRÁFICA
# =============================================================================

GUI_CONFIG = {
    "fullscreen": True,        # Modo fullscreen (True/False)
    "width": 800,              # Largura da janela (se não fullscreen)
    "height": 600,             # Altura da janela (se não fullscreen)
    "theme": "dark",           # Tema: "dark" ou "light"
    "title": "Sistema de Scanner - Raspberry Pi",  # Título da janela
    "auto_hide_cursor": True,  # Ocultar cursor automaticamente
    "show_fps": False,         # Mostrar FPS (para debug)
}

# =============================================================================
# CONFIGURAÇÕES DE REDE
# =============================================================================

NETWORK_CONFIG = {
    "wifi_scan_timeout": 10,      # Timeout para escaneamento Wi-Fi (segundos)
    "connection_timeout": 30,     # Timeout para conexão (segundos)
    "retry_attempts": 3,          # Número de tentativas de conexão
    "auto_reconnect": True,       # Reconectar automaticamente
    "check_interval": 60,         # Intervalo para verificar conectividade (segundos)
    "preferred_networks": [       # Redes Wi-Fi preferidas (opcional)
        # "MinhaRede1",
        # "MinhaRede2"
    ]
}

# =============================================================================
# CONFIGURAÇÕES DE LOG
# =============================================================================

LOG_CONFIG = {
    "level": "INFO",              # Nível de log: DEBUG, INFO, WARNING, ERROR, CRITICAL
    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    "max_size": 10 * 1024 * 1024,  # Tamanho máximo do arquivo de log (10MB)
    "backup_count": 5,            # Número de arquivos de backup
    "console_output": True,       # Mostrar logs no console
    "file_output": True,          # Salvar logs em arquivo
}

# =============================================================================
# CONFIGURAÇÕES DE SINCRONIZAÇÃO
# =============================================================================

SYNC_CONFIG = {
    "auto_sync": True,            # Sincronização automática
    "sync_on_startup": True,      # Sincronizar ao iniciar
    "batch_size": 100,            # Tamanho do lote para sincronização
    "retry_delay": 300,           # Delay entre tentativas (segundos)
    "max_retry_delay": 3600,      # Delay máximo entre tentativas (segundos)
    "offline_storage": True,      # Armazenar dados offline
    "compression": False,         # Comprimir dados antes do envio
}

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================

SECURITY_CONFIG = {
    "token_expiry_check": True,   # Verificar expiração do token
    "auto_token_refresh": True,   # Renovar token automaticamente
    "secure_connection": True,    # Usar HTTPS
    "certificate_verify": True,   # Verificar certificados SSL
    "max_failed_attempts": 5,     # Máximo de tentativas falhadas
    "lockout_duration": 1800,     # Duração do bloqueio (segundos)
}

# =============================================================================
# CONFIGURAÇÕES DE PERFORMANCE
# =============================================================================

PERFORMANCE_CONFIG = {
    "max_memory_usage": 512,      # Uso máximo de memória (MB)
    "cpu_throttling": False,      # Limitar uso de CPU
    "disk_cache_size": 100,      # Tamanho do cache em disco (MB)
    "network_buffer_size": 8192,  # Tamanho do buffer de rede (bytes)
    "log_rotation_interval": 86400,  # Intervalo de rotação de logs (segundos)
}

# =============================================================================
# CONFIGURAÇÕES DE NOTIFICAÇÃO
# =============================================================================

NOTIFICATION_CONFIG = {
    "enable_notifications": True,  # Habilitar notificações
    "sound_notifications": False,  # Notificações sonoras
    "visual_notifications": True,  # Notificações visuais
    "email_notifications": False,  # Notificações por email
    "notification_timeout": 5000,  # Timeout das notificações (ms)
}

# =============================================================================
# CONFIGURAÇÕES DE BACKUP
# =============================================================================

BACKUP_CONFIG = {
    "auto_backup": True,          # Backup automático
    "backup_interval": 86400,     # Intervalo de backup (segundos) - 1 dia
    "backup_retention": 7,        # Manter backups por X dias
    "backup_compression": True,   # Comprimir backups
    "backup_encryption": False,   # Criptografar backups
    "backup_location": DATA_DIR / "backups",  # Local dos backups
}

# =============================================================================
# CONFIGURAÇÕES DE MONITORAMENTO
# =============================================================================

MONITORING_CONFIG = {
    "system_monitoring": True,    # Monitoramento do sistema
    "temperature_monitoring": True,  # Monitoramento de temperatura
    "disk_monitoring": True,      # Monitoramento de disco
    "network_monitoring": True,   # Monitoramento de rede
    "alert_thresholds": {
        "cpu_usage": 80,          # Alerta se CPU > 80%
        "memory_usage": 85,       # Alerta se memória > 85%
        "disk_usage": 90,         # Alerta se disco > 90%
        "temperature": 75,        # Alerta se temperatura > 75°C
    }
}

# =============================================================================
# CONFIGURAÇÕES DE DESENVOLVIMENTO
# =============================================================================

DEV_CONFIG = {
    "debug_mode": False,          # Modo debug
    "verbose_logging": False,     # Logging verboso
    "test_mode": False,           # Modo de teste
    "mock_scanner": False,        # Usar scanner simulado
    "auto_restart": False,        # Reiniciar automaticamente em caso de erro
    "performance_profiling": False,  # Profiling de performance
}

# =============================================================================
# CONFIGURAÇÕES ESPECÍFICAS DO RASPBERRY PI
# =============================================================================

RASPBERRY_PI_CONFIG = {
    "gpu_memory": 128,            # Memória GPU (MB)
    "overclock": False,           # Overclock
    "hdmi_force_hotplug": True,   # Forçar detecção HDMI
    "max_usb_current": 1,        # Corrente máxima USB
    "disable_wifi_power_management": True,  # Desabilitar gerenciamento de energia Wi-Fi
    "enable_uart": False,         # Habilitar UART
    "enable_i2c": False,          # Habilitar I2C
    "enable_spi": False,          # Habilitar SPI
}

# =============================================================================
# CONFIGURAÇÕES DE TESTE
# =============================================================================

TEST_CONFIG = {
    "test_scanner": True,         # Testar scanner na inicialização
    "test_network": True,         # Testar conectividade na inicialização
    "test_api": True,             # Testar API na inicialização
    "test_permissions": True,     # Testar permissões na inicialização
    "test_storage": True,         # Testar armazenamento na inicialização
}

# =============================================================================
# VALIDAÇÃO DAS CONFIGURAÇÕES
# =============================================================================

def validate_config():
    """Valida as configurações e retorna erros encontrados"""
    errors = []
    
    # Validar URLs
    if not API_BASE_URL.startswith(('http://', 'https://')):
        errors.append("API_BASE_URL deve começar com http:// ou https://")
    
    # Validar timeouts
    if SCANNER_CONFIG["timeout"] <= 0:
        errors.append("SCANNER_CONFIG['timeout'] deve ser maior que 0")
    
    if NETWORK_CONFIG["connection_timeout"] <= 0:
        errors.append("NETWORK_CONFIG['connection_timeout'] deve ser maior que 0")
    
    # Validar tamanhos
    if SCANNER_CONFIG["max_buffer_size"] <= 0:
        errors.append("SCANNER_CONFIG['max_buffer_size'] deve ser maior que 0")
    
    if LOG_CONFIG["max_size"] <= 0:
        errors.append("LOG_CONFIG['max_size'] deve ser maior que 0")
    
    return errors

# Validar configurações na importação
if __name__ == "__main__":
    errors = validate_config()
    if errors:
        print("❌ Erros de configuração encontrados:")
        for error in errors:
            print(f"   - {error}")
        exit(1)
    else:
        print("✅ Configurações válidas!")
else:
    # Validar silenciosamente
    config_errors = validate_config()
    if config_errors:
        import logging
        logger = logging.getLogger(__name__)
        logger.warning("Configurações inválidas detectadas:")
        for error in config_errors:
            logger.warning(f"  - {error}") 