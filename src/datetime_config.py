"""
Módulo de configuração de data e hora para Raspberry Pi
"""

import subprocess
import time
from datetime import datetime, timedelta
from typing import Dict, Tuple, Optional, List
import logging
import os

from src.utils import setup_logging, run_command


class DateTimeManager:
    """Gerenciador de data e hora do sistema"""
    
    def __init__(self):
        self.logger = setup_logging("datetime_manager")
        self.ntp_servers = [
            "pool.ntp.org",
            "time.google.com",
            "time.windows.com",
            "time.nist.gov"
        ]
    
    def get_current_datetime(self) -> datetime:
        """Obtém data e hora atuais do sistema"""
        return datetime.now()
    
    def get_system_datetime(self) -> datetime:
        """Obtém data e hora do sistema (pode ser diferente do Python)"""
        try:
            # Usar comando date do sistema
            success, output, _ = run_command("date")
            if success:
                # Parsear saída do comando date
                # Formato típico: "Mon Dec 25 10:30:00 UTC 2023"
                return datetime.strptime(output.strip(), "%a %b %d %H:%M:%S %Z %Y")
        except Exception as e:
            self.logger.error(f"Erro ao obter data do sistema: {e}")
        
        # Fallback para datetime do Python
        return datetime.now()
    
    def set_system_datetime(self, new_datetime: datetime) -> Tuple[bool, str]:
        """Define nova data e hora do sistema"""
        try:
            # Formatar data para comando date
            date_string = new_datetime.strftime("%Y-%m-%d %H:%M:%S")
            
            # Comando para definir data e hora
            cmd = f"sudo date -s '{date_string}'"
            
            success, output, error = run_command(cmd)
            
            if success:
                self.logger.info(f"Data e hora alteradas para: {date_string}")
                
                # Sincronizar hardware clock
                self._sync_hardware_clock()
                
                return True, "Data e hora alteradas com sucesso"
            else:
                error_msg = error if error else output
                self.logger.error(f"Erro ao alterar data/hora: {error_msg}")
                return False, f"Erro ao alterar data/hora: {error_msg}"
                
        except Exception as e:
            error_msg = f"Erro inesperado: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg
    
    def _sync_hardware_clock(self):
        """Sincroniza relógio de hardware com o sistema"""
        try:
            # Sincronizar sistema -> hardware
            run_command("sudo hwclock --systohc")
            
            # Verificar se sincronizou
            success, output, _ = run_command("sudo hwclock --show")
            if success:
                self.logger.info("Relógio de hardware sincronizado")
            else:
                self.logger.warning("Não foi possível sincronizar relógio de hardware")
                
        except Exception as e:
            self.logger.error(f"Erro ao sincronizar relógio de hardware: {e}")
    
    def sync_with_ntp(self, server: str = None) -> Tuple[bool, str]:
        """Sincroniza data e hora com servidor NTP"""
        try:
            if not server:
                # Tentar servidores em ordem
                for ntp_server in self.ntp_servers:
                    if self._try_ntp_sync(ntp_server):
                        return True, f"Sincronizado com {ntp_server}"
                
                return False, "Falha na sincronização com todos os servidores NTP"
            else:
                return self._try_ntp_sync(server)
                
        except Exception as e:
            error_msg = f"Erro na sincronização NTP: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg
    
    def _try_ntp_sync(self, server: str) -> Tuple[bool, str]:
        """Tenta sincronizar com um servidor NTP específico"""
        try:
            self.logger.info(f"Tentando sincronizar com {server}")
            
            # Verificar se ntpdate está disponível
            success, _, _ = run_command("which ntpdate")
            if not success:
                # Tentar instalar ntpdate
                self.logger.info("Instalando ntpdate...")
                run_command("sudo apt-get update")
                run_command("sudo apt-get install -y ntpdate")
            
            # Tentar sincronização
            cmd = f"sudo ntpdate -s {server}"
            success, output, error = run_command(cmd, timeout=60)
            
            if success:
                self.logger.info(f"Sincronizado com sucesso com {server}")
                
                # Sincronizar hardware clock
                self._sync_hardware_clock()
                
                return True, f"Sincronizado com {server}"
            else:
                error_msg = error if error else output
                self.logger.warning(f"Falha na sincronização com {server}: {error_msg}")
                return False, f"Falha com {server}: {error_msg}"
                
        except Exception as e:
            self.logger.error(f"Erro ao sincronizar com {server}: {e}")
            return False, f"Erro com {server}: {str(e)}"
    
    def get_timezone_info(self) -> Dict:
        """Obtém informações sobre timezone"""
        try:
            # Obter timezone atual
            success, timezone, _ = run_command("timedatectl show --property=Timezone --value")
            if not success:
                # Fallback para arquivo
                try:
                    with open('/etc/timezone', 'r') as f:
                        timezone = f.read().strip()
                except:
                    timezone = "Unknown"
            
            # Obter offset UTC
            success, offset, _ = run_command("date +%z")
            if not success:
                offset = "Unknown"
            
            return {
                'timezone': timezone,
                'utc_offset': offset,
                'is_dst': self._is_dst()
            }
            
        except Exception as e:
            self.logger.error(f"Erro ao obter informações de timezone: {e}")
            return {
                'timezone': 'Unknown',
                'utc_offset': 'Unknown',
                'is_dst': False
            }
    
    def _is_dst(self) -> bool:
        """Verifica se está em horário de verão"""
        try:
            # Comparar horário atual com horário UTC
            success, local_time, _ = run_command("date +%H:%M")
            success2, utc_time, _ = run_command("date -u +%H:%M")
            
            if success and success2:
                local_hour = int(local_time.split(':')[0])
                utc_hour = int(utc_time.split(':')[0])
                
                # Lógica simples: se hora local > UTC, provavelmente está em DST
                return local_hour > utc_hour
                
        except Exception as e:
            self.logger.error(f"Erro ao verificar DST: {e}")
        
        return False
    
    def set_timezone(self, timezone: str) -> Tuple[bool, str]:
        """Define novo timezone"""
        try:
            # Verificar se timezone é válido
            success, output, _ = run_command(f"timedatectl list-timezones | grep -x '{timezone}'")
            if not success:
                return False, f"Timezone '{timezone}' não é válido"
            
            # Definir timezone
            cmd = f"sudo timedatectl set-timezone {timezone}"
            success, output, error = run_command(cmd)
            
            if success:
                self.logger.info(f"Timezone alterado para: {timezone}")
                return True, f"Timezone alterado para {timezone}"
            else:
                error_msg = error if error else output
                self.logger.error(f"Erro ao alterar timezone: {error_msg}")
                return False, f"Erro ao alterar timezone: {error_msg}"
                
        except Exception as e:
            error_msg = f"Erro inesperado: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg
    
    def get_available_timezones(self) -> List[str]:
        """Lista timezones disponíveis"""
        try:
            success, output, _ = run_command("timedatectl list-timezones")
            if success:
                return [tz.strip() for tz in output.split('\n') if tz.strip()]
        except Exception as e:
            self.logger.error(f"Erro ao listar timezones: {e}")
        
        # Lista básica de timezones comuns
        return [
            "America/Sao_Paulo",
            "America/New_York",
            "America/Los_Angeles",
            "Europe/London",
            "Europe/Paris",
            "Asia/Tokyo",
            "UTC"
        ]
    
    def get_datetime_status(self) -> Dict:
        """Retorna status completo de data e hora"""
        current_dt = self.get_current_datetime()
        system_dt = self.get_system_datetime()
        timezone_info = self.get_timezone_info()
        
        # Verificar se há diferença entre Python e sistema
        time_diff = abs((current_dt - system_dt).total_seconds())
        time_synced = time_diff < 5  # Considerar sincronizado se diferença < 5s
        
        return {
            'python_datetime': current_dt.isoformat(),
            'system_datetime': system_dt.isoformat(),
            'time_synced': time_synced,
            'time_difference_seconds': time_diff,
            'timezone': timezone_info['timezone'],
            'utc_offset': timezone_info['utc_offset'],
            'is_dst': timezone_info['is_dst'],
            'ntp_available': self._check_ntp_availability()
        }
    
    def _check_ntp_availability(self) -> bool:
        """Verifica se NTP está disponível"""
        try:
            # Verificar se ntpdate ou systemd-timesyncd estão disponíveis
            success1, _, _ = run_command("which ntpdate")
            success2, _, _ = run_command("which timedatectl")
            
            return success1 or success2
            
        except Exception as e:
            self.logger.error(f"Erro ao verificar disponibilidade NTP: {e}")
            return False
    
    def enable_ntp_sync(self) -> Tuple[bool, str]:
        """Habilita sincronização automática NTP"""
        try:
            # Verificar se systemd-timesyncd está disponível
            success, _, _ = run_command("which timedatectl")
            if success:
                # Habilitar NTP
                cmd = "sudo timedatectl set-ntp true"
                success, output, error = run_command(cmd)
                
                if success:
                    self.logger.info("Sincronização NTP automática habilitada")
                    return True, "Sincronização NTP automática habilitada"
                else:
                    error_msg = error if error else output
                    self.logger.error(f"Erro ao habilitar NTP: {error_msg}")
                    return False, f"Erro ao habilitar NTP: {error_msg}"
            else:
                return False, "systemd-timesyncd não está disponível"
                
        except Exception as e:
            error_msg = f"Erro ao habilitar NTP: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg
    
    def disable_ntp_sync(self) -> Tuple[bool, str]:
        """Desabilita sincronização automática NTP"""
        try:
            success, _, _ = run_command("which timedatectl")
            if success:
                cmd = "sudo timedatectl set-ntp false"
                success, output, error = run_command(cmd)
                
                if success:
                    self.logger.info("Sincronização NTP automática desabilitada")
                    return True, "Sincronização NTP automática desabilitada"
                else:
                    error_msg = error if error else output
                    self.logger.error(f"Erro ao desabilitar NTP: {error_msg}")
                    return False, f"Erro ao desabilitar NTP: {error_msg}"
            else:
                return False, "systemd-timesyncd não está disponível"
                
        except Exception as e:
            error_msg = f"Erro ao desabilitar NTP: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg
    
    def format_datetime_for_display(self, dt: datetime = None) -> str:
        """Formata data e hora para exibição amigável"""
        if dt is None:
            dt = datetime.now()
        
        return dt.strftime("%d/%m/%Y %H:%M:%S")
    
    def get_uptime(self) -> str:
        """Obtém tempo de atividade do sistema"""
        try:
            success, output, _ = run_command("uptime -p")
            if success:
                return output.strip()
        except Exception as e:
            self.logger.error(f"Erro ao obter uptime: {e}")
        
        return "Desconhecido" 