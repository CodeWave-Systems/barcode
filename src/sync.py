"""
Módulo de sincronização de dados offline
"""

import requests
import json
import csv
import threading
import time
from typing import Dict, List, Optional, Tuple
from datetime import datetime, timedelta
import logging
from queue import Queue
import os

from config.settings import API_BASE_URL, API_ENDPOINTS, PENDING_FILE, SCANNER_CONFIG
from src.utils import setup_logging, append_csv_row, load_csv, save_csv, format_timestamp


class DataSync:
    """Gerenciador de sincronização de dados offline"""
    
    def __init__(self, activation_manager):
        self.logger = setup_logging("data_sync")
        self.activation_manager = activation_manager
        self.pending_codes = []
        self.sync_thread = None
        self.is_running = False
        self.last_sync = None
        self.sync_interval = SCANNER_CONFIG["sync_interval"]
        self.max_retries = SCANNER_CONFIG["max_retries"]
        self.sync_queue = Queue()
        
        # Carregar códigos pendentes
        self._load_pending_codes()
        
        # Iniciar thread de sincronização
        self.start_sync_thread()
    
    def _load_pending_codes(self):
        """Carrega códigos pendentes do arquivo CSV"""
        try:
            if PENDING_FILE.exists():
                self.pending_codes = load_csv(PENDING_FILE)
                self.logger.info(f"Carregados {len(self.pending_codes)} códigos pendentes")
            else:
                self.pending_codes = []
        except Exception as e:
            self.logger.error(f"Erro ao carregar códigos pendentes: {e}")
            self.pending_codes = []
    
    def add_code(self, code: str, timestamp: datetime, metadata: Dict = None):
        """Adiciona novo código para sincronização"""
        try:
            code_data = {
                'code': code,
                'timestamp': timestamp.isoformat(),
                'formatted_time': format_timestamp(timestamp),
                'device_id': self.activation_manager.device_id,
                'retry_count': 0,
                'last_attempt': None,
                'status': 'pending'
            }
            
            # Adicionar metadados se fornecidos
            if metadata:
                code_data.update(metadata)
            
            # Adicionar à lista local
            self.pending_codes.append(code_data)
            
            # Salvar no arquivo CSV
            fieldnames = list(code_data.keys())
            if append_csv_row(code_data, PENDING_FILE, fieldnames):
                self.logger.info(f"Código {code} adicionado para sincronização")
                
                # Tentar sincronização imediata se online
                if self._is_online():
                    self.sync_queue.put(('immediate', code_data))
                return True
            else:
                self.logger.error(f"Erro ao salvar código {code} no arquivo")
                return False
                
        except Exception as e:
            self.logger.error(f"Erro ao adicionar código {code}: {e}")
            return False
    
    def start_sync_thread(self):
        """Inicia thread de sincronização automática"""
        if self.is_running:
            return
        
        self.is_running = True
        self.sync_thread = threading.Thread(target=self._sync_loop, daemon=True)
        self.sync_thread.start()
        self.logger.info("Thread de sincronização iniciada")
    
    def stop_sync_thread(self):
        """Para thread de sincronização"""
        self.is_running = False
        if self.sync_thread:
            self.sync_thread.join(timeout=5)
        self.logger.info("Thread de sincronização parada")
    
    def _sync_loop(self):
        """Loop principal de sincronização"""
        last_hourly_sync = None
        
        while self.is_running:
            try:
                current_time = datetime.now()
                
                # Verificar se é hora de sincronização horária
                if (last_hourly_sync is None or 
                    current_time - last_hourly_sync >= timedelta(hours=1)):
                    
                    self.logger.info("Iniciando sincronização horária")
                    self._sync_all_pending()
                    last_hourly_sync = current_time
                
                # Processar itens da fila de sincronização imediata
                try:
                    while not self.sync_queue.empty():
                        sync_type, data = self.sync_queue.get_nowait()
                        if sync_type == 'immediate':
                            self._sync_single_code(data)
                except:
                    pass
                
                # Aguardar próximo ciclo
                time.sleep(60)  # Verificar a cada minuto
                
            except Exception as e:
                self.logger.error(f"Erro no loop de sincronização: {e}")
                time.sleep(60)
    
    def _sync_all_pending(self):
        """Sincroniza todos os códigos pendentes"""
        if not self.pending_codes:
            self.logger.info("Nenhum código pendente para sincronizar")
            return
        
        if not self._is_online():
            self.logger.info("Sem conexão com internet, pulando sincronização")
            return
        
        self.logger.info(f"Sincronizando {len(self.pending_codes)} códigos pendentes")
        
        successful_syncs = []
        failed_syncs = []
        
        for code_data in self.pending_codes[:]:  # Copiar lista para iteração
            try:
                if self._sync_single_code(code_data):
                    successful_syncs.append(code_data)
                else:
                    failed_syncs.append(code_data)
                
                # Pequena pausa entre sincronizações
                time.sleep(0.1)
                
            except Exception as e:
                self.logger.error(f"Erro ao sincronizar código {code_data.get('code', 'unknown')}: {e}")
                failed_syncs.append(code_data)
        
        # Remover códigos sincronizados com sucesso
        if successful_syncs:
            self._remove_synced_codes(successful_syncs)
            self.logger.info(f"Sincronizados {len(successful_syncs)} códigos com sucesso")
        
        # Atualizar contadores de tentativa para códigos falhados
        if failed_syncs:
            self._update_failed_syncs(failed_syncs)
            self.logger.warning(f"Falharam {len(failed_syncs)} códigos na sincronização")
    
    def _sync_single_code(self, code_data: Dict) -> bool:
        """Sincroniza um código individual"""
        try:
            # Verificar se ainda está pendente
            if code_data.get('status') != 'pending':
                return True
            
            # Verificar limite de tentativas
            retry_count = code_data.get('retry_count', 0)
            if retry_count >= self.max_retries:
                self.logger.warning(f"Código {code_data.get('code')} excedeu limite de tentativas")
                code_data['status'] = 'failed'
                return False
            
            # Preparar dados para envio
            sync_data = {
                'code': code_data['code'],
                'timestamp': code_data['timestamp'],
                'device_id': code_data['device_id'],
                'metadata': {k: v for k, v in code_data.items() 
                           if k not in ['code', 'timestamp', 'device_id', 'retry_count', 'last_attempt', 'status']}
            }
            
            # Enviar para API
            url = f"{API_BASE_URL}{API_ENDPOINTS['registrar']}"
            headers = {
                'Authorization': f'Bearer {self.activation_manager.token}',
                'Content-Type': 'application/json'
            }
            
            response = requests.post(
                url,
                json=sync_data,
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                response_data = response.json()
                if response_data.get('success'):
                    code_data['status'] = 'synced'
                    self.logger.debug(f"Código {code_data.get('code')} sincronizado com sucesso")
                    return True
                else:
                    error_msg = response_data.get('message', 'Erro desconhecido')
                    self.logger.warning(f"Falha na sincronização do código {code_data.get('code')}: {error_msg}")
            else:
                error_msg = f"HTTP {response.status_code}: {response.text}"
                self.logger.warning(f"Erro HTTP na sincronização: {error_msg}")
            
            # Incrementar contador de tentativas
            code_data['retry_count'] = retry_count + 1
            code_data['last_attempt'] = datetime.now().isoformat()
            
            return False
            
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Erro de rede na sincronização: {e}")
            code_data['retry_count'] = retry_count + 1
            code_data['last_attempt'] = datetime.now().isoformat()
            return False
            
        except Exception as e:
            self.logger.error(f"Erro inesperado na sincronização: {e}")
            return False
    
    def _remove_synced_codes(self, synced_codes: List[Dict]):
        """Remove códigos sincronizados com sucesso"""
        try:
            # Remover da lista local
            for synced_code in synced_codes:
                if synced_code in self.pending_codes:
                    self.pending_codes.remove(synced_code)
            
            # Reescrever arquivo CSV
            if self.pending_codes:
                fieldnames = list(self.pending_codes[0].keys())
                save_csv(self.pending_codes, PENDING_FILE, fieldnames)
            else:
                # Se não há mais códigos, remover arquivo
                if PENDING_FILE.exists():
                    PENDING_FILE.unlink()
            
            self.logger.info(f"Removidos {len(synced_codes)} códigos sincronizados")
            
        except Exception as e:
            self.logger.error(f"Erro ao remover códigos sincronizados: {e}")
    
    def _update_failed_syncs(self, failed_codes: List[Dict]):
        """Atualiza contadores de tentativas para códigos falhados"""
        try:
            # Atualizar arquivo CSV
            if self.pending_codes:
                fieldnames = list(self.pending_codes[0].keys())
                save_csv(self.pending_codes, PENDING_FILE, fieldnames)
            
        except Exception as e:
            self.logger.error(f"Erro ao atualizar códigos falhados: {e}")
    
    def _is_online(self) -> bool:
        """Verifica se há conexão com internet"""
        try:
            # Verificar se o dispositivo está ativado
            if not self.activation_manager.is_activated():
                return False
            
            # Testar conectividade
            response = requests.get("https://httpbin.org/get", timeout=5)
            return response.status_code == 200
            
        except:
            return False
    
    def force_sync(self) -> Tuple[int, int]:
        """Força sincronização imediata de todos os códigos pendentes"""
        self.logger.info("Sincronização forçada solicitada")
        
        if not self.pending_codes:
            return 0, 0
        
        if not self._is_online():
            self.logger.warning("Sem conexão com internet para sincronização forçada")
            return 0, len(self.pending_codes)
        
        successful = 0
        failed = 0
        
        for code_data in self.pending_codes[:]:
            if self._sync_single_code(code_data):
                successful += 1
            else:
                failed += 1
        
        # Remover códigos sincronizados
        if successful > 0:
            synced_codes = [c for c in self.pending_codes if c.get('status') == 'synced']
            self._remove_synced_codes(synced_codes)
        
        self.logger.info(f"Sincronização forçada: {successful} sucessos, {failed} falhas")
        return successful, failed
    
    def get_sync_status(self) -> Dict:
        """Retorna status da sincronização"""
        return {
            'running': self.is_running,
            'pending_count': len(self.pending_codes),
            'last_sync': self.last_sync.isoformat() if self.last_sync else None,
            'sync_interval': self.sync_interval,
            'online': self._is_online(),
            'queue_size': self.sync_queue.qsize()
        }
    
    def get_pending_codes(self) -> List[Dict]:
        """Retorna lista de códigos pendentes"""
        return self.pending_codes.copy()
    
    def clear_failed_codes(self) -> int:
        """Remove códigos que falharam na sincronização"""
        failed_codes = [c for c in self.pending_codes if c.get('status') == 'failed']
        
        for failed_code in failed_codes:
            self.pending_codes.remove(failed_code)
        
        # Reescrever arquivo CSV
        if self.pending_codes:
            fieldnames = list(self.pending_codes[0].keys())
            save_csv(self.pending_codes, PENDING_FILE, fieldnames)
        else:
            if PENDING_FILE.exists():
                PENDING_FILE.unlink()
        
        self.logger.info(f"Removidos {len(failed_codes)} códigos falhados")
        return len(failed_codes)
    
    def export_pending_data(self, file_path: str) -> bool:
        """Exporta dados pendentes para arquivo"""
        try:
            if not self.pending_codes:
                return False
            
            fieldnames = list(self.pending_codes[0].keys())
            return save_csv(self.pending_codes, file_path, fieldnames)
            
        except Exception as e:
            self.logger.error(f"Erro ao exportar dados: {e}")
            return False 