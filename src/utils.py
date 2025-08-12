"""
Módulo de utilitários para o sistema de scanner
"""

import json
import csv
import logging
import logging.handlers
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional
import subprocess
import platform

from config.settings import LOGS_FILE, LOG_CONFIG


def setup_logging(name: str = "scanner_system") -> logging.Logger:
    """Configura e retorna um logger configurado"""
    logger = logging.getLogger(name)
    
    if not logger.handlers:
        logger.setLevel(getattr(logging, LOG_CONFIG["level"]))
        
        # Handler para arquivo com rotação
        file_handler = logging.handlers.RotatingFileHandler(
            LOGS_FILE,
            maxBytes=LOG_CONFIG["max_size"],
            backupCount=LOG_CONFIG["backup_count"]
        )
        
        # Handler para console
        console_handler = logging.StreamHandler()
        
        # Formato
        formatter = logging.Formatter(LOG_CONFIG["format"])
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)
        
        logger.addHandler(file_handler)
        logger.addHandler(console_handler)
    
    return logger


def get_raspberry_pi_serial() -> str:
    """Obtém o serial único do Raspberry Pi"""
    try:
        with open('/proc/cpuinfo', 'r') as f:
            for line in f:
                if line.startswith('Serial'):
                    return line.split(':')[1].strip()
    except:
        pass
    
    # Fallback para outros sistemas
    try:
        result = subprocess.run(['hostname'], capture_output=True, text=True)
        return result.stdout.strip()
    except:
        return "unknown"


def get_system_info() -> Dict[str, str]:
    """Obtém informações do sistema"""
    return {
        "platform": platform.system(),
        "platform_version": platform.version(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "serial": get_raspberry_pi_serial()
    }


def save_json(data: Dict[str, Any], file_path: Path) -> bool:
    """Salva dados em arquivo JSON"""
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        logging.error(f"Erro ao salvar JSON em {file_path}: {e}")
        return False


def load_json(file_path: Path) -> Optional[Dict[str, Any]]:
    """Carrega dados de arquivo JSON"""
    try:
        if file_path.exists():
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
    except Exception as e:
        logging.error(f"Erro ao carregar JSON de {file_path}: {e}")
    return None


def save_csv(data: List[Dict[str, Any]], file_path: Path, fieldnames: List[str]) -> bool:
    """Salva dados em arquivo CSV"""
    try:
        with open(file_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(data)
        return True
    except Exception as e:
        logging.error(f"Erro ao salvar CSV em {file_path}: {e}")
        return False


def load_csv(file_path: Path) -> List[Dict[str, Any]]:
    """Carrega dados de arquivo CSV"""
    try:
        if file_path.exists():
            with open(file_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                return list(reader)
    except Exception as e:
        logging.error(f"Erro ao carregar CSV de {file_path}: {e}")
    return []


def append_csv_row(data: Dict[str, Any], file_path: Path, fieldnames: List[str]) -> bool:
    """Adiciona uma linha ao arquivo CSV"""
    try:
        file_exists = file_path.exists()
        with open(file_path, 'a', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            if not file_exists:
                writer.writeheader()
            writer.writerow(data)
        return True
    except Exception as e:
        logging.error(f"Erro ao adicionar linha ao CSV {file_path}: {e}")
        return False


def format_timestamp(timestamp: Optional[datetime] = None) -> str:
    """Formata timestamp para exibição"""
    if timestamp is None:
        timestamp = datetime.now()
    return timestamp.strftime("%d/%m/%Y %H:%M:%S")


def is_raspberry_pi() -> bool:
    """Verifica se está rodando em Raspberry Pi"""
    try:
        with open('/proc/cpuinfo', 'r') as f:
            return 'Raspberry Pi' in f.read()
    except:
        return False


def run_command(command: str, timeout: int = 30) -> tuple[bool, str, str]:
    """Executa comando do sistema e retorna (sucesso, stdout, stderr)"""
    try:
        result = subprocess.run(
            command.split(),
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return (
            result.returncode == 0,
            result.stdout.strip(),
            result.stderr.strip()
        )
    except subprocess.TimeoutExpired:
        return False, "", "Comando expirou"
    except Exception as e:
        return False, "", str(e)


def ensure_directory(path: Path) -> bool:
    """Garante que o diretório existe"""
    try:
        path.mkdir(parents=True, exist_ok=True)
        return True
    except Exception as e:
        logging.error(f"Erro ao criar diretório {path}: {e}")
        return False 