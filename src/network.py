"""
Módulo de gerenciamento de rede para Raspberry Pi
"""

import subprocess
import time
import json
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import logging

from config.settings import NETWORK_CONFIG
from src.utils import run_command, setup_logging


@dataclass
class NetworkInfo:
    """Informações da rede"""
    interface: str
    type: str  # 'wifi' ou 'ethernet'
    ssid: Optional[str] = None
    ip: Optional[str] = None
    status: str = "disconnected"
    signal_strength: Optional[int] = None


class NetworkManager:
    """Gerenciador de rede usando nmcli"""
    
    def __init__(self):
        self.logger = setup_logging("network_manager")
        self.available_networks = []
        self.current_connection = None
        
    def check_nmcli_available(self) -> bool:
        """Verifica se nmcli está disponível"""
        success, _, _ = run_command("which nmcli")
        return success
    
    def get_network_interfaces(self) -> List[NetworkInfo]:
        """Obtém todas as interfaces de rede"""
        interfaces = []
        
        # Obter interfaces físicas
        success, output, _ = run_command("nmcli device status")
        if not success:
            self.logger.error("Erro ao obter status das interfaces")
            return interfaces
        
        for line in output.split('\n')[1:]:  # Pular cabeçalho
            if line.strip():
                parts = line.split()
                if len(parts) >= 3:
                    interface = parts[0]
                    device_type = parts[1]
                    status = parts[2]
                    
                    if device_type == 'wifi':
                        net_info = NetworkInfo(
                            interface=interface,
                            type='wifi',
                            status=status
                        )
                    elif device_type == 'ethernet':
                        net_info = NetworkInfo(
                            interface=interface,
                            type='ethernet',
                            status=status
                        )
                    else:
                        continue
                    
                    # Obter IP se conectado
                    if status == 'connected':
                        net_info.ip = self._get_interface_ip(interface)
                        if device_type == 'wifi':
                            net_info.ssid = self._get_wifi_ssid(interface)
                            net_info.signal_strength = self._get_wifi_signal(interface)
                    
                    interfaces.append(net_info)
        
        return interfaces
    
    def _get_interface_ip(self, interface: str) -> Optional[str]:
        """Obtém IP de uma interface específica"""
        success, output, _ = run_command(f"ip addr show {interface}")
        if success:
            for line in output.split('\n'):
                if 'inet ' in line:
                    return line.split()[1].split('/')[0]
        return None
    
    def _get_wifi_ssid(self, interface: str) -> Optional[str]:
        """Obtém SSID da interface Wi-Fi"""
        success, output, _ = run_command(f"nmcli -t -f SSID device show {interface}")
        if success:
            for line in output.split('\n'):
                if line.startswith('SSID:'):
                    return line.split(':', 1)[1]
        return None
    
    def _get_wifi_signal(self, interface: str) -> Optional[int]:
        """Obtém força do sinal Wi-Fi"""
        success, output, _ = run_command(f"nmcli -t -f SIGNAL device wifi list ifname {interface}")
        if success:
            for line in output.split('\n'):
                if line.strip():
                    parts = line.split(':')
                    if len(parts) > 2:
                        try:
                            return int(parts[2])
                        except ValueError:
                            continue
        return None
    
    def scan_wifi_networks(self, interface: str = None) -> List[Dict[str, str]]:
        """Escaneia redes Wi-Fi disponíveis"""
        networks = []
        
        if interface:
            cmd = f"nmcli -t -f SSID,SIGNAL,SECURITY device wifi list ifname {interface}"
        else:
            cmd = "nmcli -t -f SSID,SIGNAL,SECURITY device wifi list"
        
        success, output, _ = run_command(cmd)
        if not success:
            self.logger.error("Erro ao escanear redes Wi-Fi")
            return networks
        
        for line in output.split('\n'):
            if line.strip():
                parts = line.split(':')
                if len(parts) >= 3:
                    networks.append({
                        'ssid': parts[0] if parts[0] else 'Hidden',
                        'signal': parts[1] if len(parts) > 1 else '0',
                        'security': parts[2] if len(parts) > 2 else 'none'
                    })
        
        # Remover duplicatas e ordenar por sinal
        unique_networks = []
        seen_ssids = set()
        for net in networks:
            if net['ssid'] not in seen_ssids:
                unique_networks.append(net)
                seen_ssids.add(net['ssid'])
        
        # Ordenar por força do sinal (maior primeiro)
        unique_networks.sort(key=lambda x: int(x['signal']) if x['signal'].isdigit() else 0, reverse=True)
        
        return unique_networks
    
    def connect_wifi(self, ssid: str, password: str, interface: str = None) -> Tuple[bool, str]:
        """Conecta a uma rede Wi-Fi"""
        try:
            # Desconectar de conexões existentes
            if interface:
                run_command(f"nmcli device disconnect {interface}")
            else:
                run_command("nmcli device disconnect")
            
            time.sleep(2)
            
            # Conectar à nova rede
            if interface:
                cmd = f"nmcli device wifi connect '{ssid}' password '{password}' ifname {interface}"
            else:
                cmd = f"nmcli device wifi connect '{ssid}' password '{password}'"
            
            success, output, error = run_command(cmd, timeout=NETWORK_CONFIG["connection_timeout"])
            
            if success:
                self.logger.info(f"Conectado com sucesso à rede {ssid}")
                return True, "Conectado com sucesso"
            else:
                error_msg = error if error else output
                self.logger.error(f"Erro ao conectar à rede {ssid}: {error_msg}")
                return False, f"Erro de conexão: {error_msg}"
                
        except Exception as e:
            self.logger.error(f"Exceção ao conectar Wi-Fi: {e}")
            return False, f"Erro: {str(e)}"
    
    def connect_ethernet(self, interface: str) -> Tuple[bool, str]:
        """Conecta interface Ethernet"""
        try:
            # Configurar DHCP
            cmd = f"nmcli device connect {interface}"
            success, output, error = run_command(cmd, timeout=NETWORK_CONFIG["connection_timeout"])
            
            if success:
                self.logger.info(f"Ethernet conectado: {interface}")
                return True, "Ethernet conectado"
            else:
                error_msg = error if error else output
                self.logger.error(f"Erro ao conectar Ethernet {interface}: {error_msg}")
                return False, f"Erro de conexão: {error_msg}"
                
        except Exception as e:
            self.logger.error(f"Exceção ao conectar Ethernet: {e}")
            return False, f"Erro: {str(e)}"
    
    def disconnect_interface(self, interface: str) -> bool:
        """Desconecta uma interface"""
        success, _, _ = run_command(f"nmcli device disconnect {interface}")
        if success:
            self.logger.info(f"Interface {interface} desconectada")
        return success
    
    def get_connection_status(self) -> Dict[str, str]:
        """Obtém status geral da conexão"""
        status = {
            'connected': 'false',
            'interface': 'none',
            'ip': 'none',
            'ssid': 'none',
            'type': 'none'
        }
        
        interfaces = self.get_network_interfaces()
        for interface in interfaces:
            if interface.status == 'connected':
                status['connected'] = 'true'
                status['interface'] = interface.interface
                status['ip'] = interface.ip or 'none'
                status['ssid'] = interface.ssid or 'none'
                status['type'] = interface.type
                break
        
        return status
    
    def test_internet_connection(self, timeout: int = 10) -> bool:
        """Testa conectividade com internet"""
        try:
            # Tentar ping para Google DNS
            success, _, _ = run_command("ping -c 1 -W 5 8.8.8.8", timeout=timeout)
            if success:
                return True
            
            # Fallback para DNS do Cloudflare
            success, _, _ = run_command("ping -c 1 -W 5 1.1.1.1", timeout=timeout)
            return success
            
        except Exception as e:
            self.logger.error(f"Erro ao testar conectividade: {e}")
            return False
    
    def get_network_speed(self, interface: str) -> Optional[Dict[str, str]]:
        """Obtém velocidade da interface de rede"""
        try:
            # Ler estatísticas da interface
            with open(f'/sys/class/net/{interface}/statistics/rx_bytes', 'r') as f:
                rx_bytes = int(f.read().strip())
            
            with open(f'/sys/class/net/{interface}/statistics/tx_bytes', 'r') as f:
                tx_bytes = int(f.read().strip())
            
            return {
                'rx_bytes': str(rx_bytes),
                'tx_bytes': str(tx_bytes),
                'interface': interface
            }
        except Exception as e:
            self.logger.error(f"Erro ao obter velocidade da interface {interface}: {e}")
            return None 