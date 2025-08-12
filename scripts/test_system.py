#!/usr/bin/env python3
"""
Script de teste para verificar o sistema de scanner
Execute com: python3 scripts/test_system.py
"""

import sys
import os
import importlib
from pathlib import Path

# Adicionar diretório pai ao path
sys.path.append(str(Path(__file__).parent.parent))

def test_imports():
    """Testa se todos os módulos podem ser importados"""
    print("🔍 Testando imports dos módulos...")
    
    modules_to_test = [
        'config.settings',
        'src.utils',
        'src.network',
        'src.activation',
        'src.scanner',
        'src.sync',
        'src.datetime_config',
        'src.app'
    ]
    
    failed_imports = []
    
    for module_name in modules_to_test:
        try:
            importlib.import_module(module_name)
            print(f"  ✅ {module_name}")
        except ImportError as e:
            print(f"  ❌ {module_name}: {e}")
            failed_imports.append(module_name)
    
    if failed_imports:
        print(f"\n❌ Falharam {len(failed_imports)} imports")
        return False
    else:
        print("✅ Todos os imports funcionaram!")
        return True

def test_config():
    """Testa configurações do sistema"""
    print("\n⚙️  Testando configurações...")
    
    try:
        from config.settings import (
            BASE_DIR, DATA_DIR, LOGS_DIR, CONFIG_DIR,
            API_BASE_URL, SCANNER_CONFIG, GUI_CONFIG
        )
        
        print(f"  ✅ Diretório base: {BASE_DIR}")
        print(f"  ✅ Diretório de dados: {DATA_DIR}")
        print(f"  ✅ Diretório de logs: {LOGS_DIR}")
        print(f"  ✅ Diretório de config: {CONFIG_DIR}")
        print(f"  ✅ URL da API: {API_BASE_URL}")
        print(f"  ✅ Config do scanner: {SCANNER_CONFIG}")
        print(f"  ✅ Config da GUI: {GUI_CONFIG}")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Erro nas configurações: {e}")
        return False

def test_utils():
    """Testa funções utilitárias"""
    print("\n🛠️  Testando funções utilitárias...")
    
    try:
        from src.utils import (
            setup_logging, get_raspberry_pi_serial,
            get_system_info, format_timestamp
        )
        
        # Testar logger
        logger = setup_logging("test")
        print("  ✅ Logger configurado")
        
        # Testar serial do Raspberry Pi
        serial = get_raspberry_pi_serial()
        print(f"  ✅ Serial do Raspberry Pi: {serial}")
        
        # Testar informações do sistema
        system_info = get_system_info()
        print(f"  ✅ Plataforma: {system_info['platform']}")
        
        # Testar formatação de timestamp
        timestamp = format_timestamp()
        print(f"  ✅ Timestamp formatado: {timestamp}")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Erro nas funções utilitárias: {e}")
        return False

def test_network():
    """Testa módulo de rede"""
    print("\n🌐 Testando módulo de rede...")
    
    try:
        from src.network import NetworkManager
        
        network_manager = NetworkManager()
        
        # Testar se nmcli está disponível
        nmcli_available = network_manager.check_nmcli_available()
        print(f"  ✅ nmcli disponível: {nmcli_available}")
        
        # Testar interfaces de rede
        interfaces = network_manager.get_network_interfaces()
        print(f"  ✅ Interfaces encontradas: {len(interfaces)}")
        
        for interface in interfaces:
            print(f"    - {interface.interface}: {interface.type} ({interface.status})")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Erro no módulo de rede: {e}")
        return False

def test_scanner():
    """Testa módulo do scanner"""
    print("\n📱 Testando módulo do scanner...")
    
    try:
        from src.scanner import BarcodeScanner, MockScanner
        
        # Testar scanner simulado primeiro
        mock_scanner = MockScanner()
        print("  ✅ Scanner simulado criado")
        
        # Testar scanner real (se disponível)
        try:
            real_scanner = BarcodeScanner()
            print("  ✅ Scanner real criado")
            
            # Testar status
            status = real_scanner.get_scanner_status()
            print(f"  ✅ Status do scanner: {status}")
            
        except Exception as e:
            print(f"  ⚠️  Scanner real não disponível: {e}")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Erro no módulo do scanner: {e}")
        return False

def test_activation():
    """Testa módulo de ativação"""
    print("\n🔑 Testando módulo de ativação...")
    
    try:
        from src.activation import DeviceActivation
        
        activation = DeviceActivation()
        
        # Testar informações de ativação
        info = activation.get_activation_info()
        print(f"  ✅ Status da ativação: {info['activated']}")
        print(f"  ✅ Device ID: {info['device_id']}")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Erro no módulo de ativação: {e}")
        return False

def test_datetime():
    """Testa módulo de data e hora"""
    print("\n🕐 Testando módulo de data e hora...")
    
    try:
        from src.datetime_config import DateTimeManager
        
        datetime_manager = DateTimeManager()
        
        # Testar data e hora atual
        current_dt = datetime_manager.get_current_datetime()
        print(f"  ✅ Data/hora atual: {current_dt}")
        
        # Testar informações de timezone
        timezone_info = datetime_manager.get_timezone_info()
        print(f"  ✅ Timezone: {timezone_info['timezone']}")
        print(f"  ✅ Offset UTC: {timezone_info['utc_offset']}")
        
        # Testar uptime
        uptime = datetime_manager.get_uptime()
        print(f"  ✅ Uptime: {uptime}")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Erro no módulo de data/hora: {e}")
        return False

def test_directories():
    """Testa criação de diretórios"""
    print("\n📁 Testando criação de diretórios...")
    
    try:
        from config.settings import BASE_DIR, DATA_DIR, LOGS_DIR, CONFIG_DIR
        
        # Criar diretórios se não existirem
        for directory in [DATA_DIR, LOGS_DIR, CONFIG_DIR]:
            directory.mkdir(parents=True, exist_ok=True)
            print(f"  ✅ Diretório criado/verificado: {directory}")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Erro na criação de diretórios: {e}")
        return False

def test_dependencies():
    """Testa dependências Python"""
    print("\n🐍 Testando dependências Python...")
    
    dependencies = [
        'customtkinter',
        'requests',
        'APScheduler',
        'evdev',
        'python-dateutil',
        'psutil',
        'netifaces',
        'pynput'
    ]
    
    failed_deps = []
    
    for dep in dependencies:
        try:
            importlib.import_module(dep)
            print(f"  ✅ {dep}")
        except ImportError:
            print(f"  ❌ {dep} (não instalado)")
            failed_deps.append(dep)
    
    if failed_deps:
        print(f"\n⚠️  Dependências não instaladas: {', '.join(failed_deps)}")
        print("   Execute: pip3 install -r requirements.txt")
        return False
    else:
        print("✅ Todas as dependências estão instaladas!")
        return True

def main():
    """Função principal de teste"""
    print("🚀 Iniciando testes do sistema de scanner...")
    print("=" * 50)
    
    tests = [
        ("Imports", test_imports),
        ("Configurações", test_config),
        ("Funções Utilitárias", test_utils),
        ("Rede", test_network),
        ("Scanner", test_scanner),
        ("Ativação", test_activation),
        ("Data/Hora", test_datetime),
        ("Diretórios", test_directories),
        ("Dependências", test_dependencies)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
            print()
        except Exception as e:
            print(f"  ❌ Erro inesperado no teste {test_name}: {e}")
            print()
    
    print("=" * 50)
    print(f"📊 Resultado dos testes: {passed}/{total} passaram")
    
    if passed == total:
        print("🎉 Todos os testes passaram! Sistema funcionando perfeitamente.")
        return 0
    else:
        print("⚠️  Alguns testes falharam. Verifique os erros acima.")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 