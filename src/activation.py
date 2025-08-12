"""
Módulo de ativação do dispositivo Raspberry Pi
"""

import requests
import json
import time
from typing import Dict, Optional, Tuple
from datetime import datetime, timedelta
import logging

from config.settings import API_BASE_URL, API_ENDPOINTS, TOKEN_FILE
from src.utils import setup_logging, save_json, load_json, get_raspberry_pi_serial


class DeviceActivation:
    """Gerenciador de ativação do dispositivo"""
    
    def __init__(self):
        self.logger = setup_logging("device_activation")
        self.token = None
        self.device_id = None
        self.activation_date = None
        self.expiration_date = None
        self.load_token()
    
    def load_token(self) -> bool:
        """Carrega token salvo localmente"""
        try:
            token_data = load_json(TOKEN_FILE)
            if token_data and self._validate_token_data(token_data):
                self.token = token_data.get('token')
                self.device_id = token_data.get('device_id')
                self.activation_date = datetime.fromisoformat(token_data.get('activation_date'))
                self.expiration_date = datetime.fromisoformat(token_data.get('expiration_date'))
                self.logger.info("Token carregado com sucesso")
                return True
        except Exception as e:
            self.logger.error(f"Erro ao carregar token: {e}")
        
        return False
    
    def _validate_token_data(self, token_data: Dict) -> bool:
        """Valida dados do token"""
        required_fields = ['token', 'device_id', 'activation_date', 'expiration_date']
        
        for field in required_fields:
            if field not in token_data:
                return False
        
        # Verificar se o token não expirou
        try:
            expiration = datetime.fromisoformat(token_data['expiration_date'])
            if datetime.now() > expiration:
                self.logger.warning("Token expirado")
                return False
        except:
            return False
        
        return True
    
    def is_activated(self) -> bool:
        """Verifica se o dispositivo está ativado"""
        if not self.token:
            return False
        
        # Verificar se o token não expirou
        if self.expiration_date and datetime.now() > self.expiration_date:
            self.logger.warning("Token expirado")
            self.clear_token()
            return False
        
        return True
    
    def activate_device(self, activation_key: str) -> Tuple[bool, str]:
        """Ativa o dispositivo usando a chave de ativação"""
        try:
            # Obter serial do Raspberry Pi
            device_serial = get_raspberry_pi_serial()
            
            # Preparar dados para ativação
            activation_data = {
                'activation_key': activation_key,
                'device_serial': device_serial,
                'device_type': 'raspberry_pi',
                'platform': 'linux',
                'timestamp': datetime.now().isoformat()
            }
            
            # Enviar requisição de ativação
            url = f"{API_BASE_URL}{API_ENDPOINTS['ativar']}"
            
            self.logger.info(f"Tentando ativar dispositivo com chave: {activation_key[:8]}...")
            
            response = requests.post(
                url,
                json=activation_data,
                timeout=30,
                headers={'Content-Type': 'application/json'}
            )
            
            if response.status_code == 200:
                response_data = response.json()
                
                if response_data.get('success'):
                    # Salvar token e informações
                    token_info = {
                        'token': response_data['token'],
                        'device_id': response_data['device_id'],
                        'activation_date': response_data['activation_date'],
                        'expiration_date': response_data['expiration_date'],
                        'device_serial': device_serial
                    }
                    
                    if save_json(token_info, TOKEN_FILE):
                        self.token = token_info['token']
                        self.device_id = token_info['device_id']
                        self.activation_date = datetime.fromisoformat(token_info['activation_date'])
                        self.expiration_date = datetime.fromisoformat(token_info['expiration_date'])
                        
                        self.logger.info("Dispositivo ativado com sucesso")
                        return True, "Dispositivo ativado com sucesso"
                    else:
                        return False, "Erro ao salvar token localmente"
                else:
                    error_msg = response_data.get('message', 'Erro desconhecido na ativação')
                    self.logger.error(f"Falha na ativação: {error_msg}")
                    return False, error_msg
            else:
                error_msg = f"Erro HTTP {response.status_code}: {response.text}"
                self.logger.error(f"Erro na requisição de ativação: {error_msg}")
                return False, error_msg
                
        except requests.exceptions.Timeout:
            error_msg = "Timeout na conexão com o servidor"
            self.logger.error(error_msg)
            return False, error_msg
            
        except requests.exceptions.ConnectionError:
            error_msg = "Erro de conexão com o servidor"
            self.logger.error(error_msg)
            return False, error_msg
            
        except requests.exceptions.RequestException as e:
            error_msg = f"Erro na requisição: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg
            
        except Exception as e:
            error_msg = f"Erro inesperado: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg
    
    def validate_token_with_server(self) -> Tuple[bool, str]:
        """Valida token com o servidor"""
        if not self.token:
            return False, "Nenhum token disponível"
        
        try:
            url = f"{API_BASE_URL}{API_ENDPOINTS['status']}"
            
            headers = {
                'Authorization': f'Bearer {self.token}',
                'Content-Type': 'application/json'
            }
            
            data = {
                'device_id': self.device_id,
                'timestamp': datetime.now().isoformat()
            }
            
            response = requests.post(
                url,
                json=data,
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                response_data = response.json()
                if response_data.get('valid'):
                    self.logger.info("Token validado com sucesso no servidor")
                    return True, "Token válido"
                else:
                    error_msg = response_data.get('message', 'Token inválido')
                    self.logger.warning(f"Token inválido no servidor: {error_msg}")
                    return False, error_msg
            elif response.status_code == 401:
                self.logger.warning("Token não autorizado no servidor")
                self.clear_token()
                return False, "Token não autorizado"
            else:
                error_msg = f"Erro HTTP {response.status_code}: {response.text}"
                self.logger.error(f"Erro na validação do token: {error_msg}")
                return False, error_msg
                
        except requests.exceptions.RequestException as e:
            error_msg = f"Erro na validação: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg
    
    def refresh_token(self) -> Tuple[bool, str]:
        """Renova o token se necessário"""
        if not self.token:
            return False, "Nenhum token disponível para renovar"
        
        # Verificar se o token expira em menos de 24 horas
        if self.expiration_date:
            time_until_expiry = self.expiration_date - datetime.now()
            if time_until_expiry > timedelta(hours=24):
                return True, "Token ainda válido por mais de 24 horas"
        
        try:
            url = f"{API_BASE_URL}/refresh_token"  # Endpoint para renovação
            
            headers = {
                'Authorization': f'Bearer {self.token}',
                'Content-Type': 'application/json'
            }
            
            data = {
                'device_id': self.device_id,
                'timestamp': datetime.now().isoformat()
            }
            
            response = requests.post(
                url,
                json=data,
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                response_data = response.json()
                if response_data.get('success'):
                    # Atualizar token
                    new_token_info = {
                        'token': response_data['new_token'],
                        'device_id': self.device_id,
                        'activation_date': self.activation_date.isoformat(),
                        'expiration_date': response_data['new_expiration_date'],
                        'device_serial': get_raspberry_pi_serial()
                    }
                    
                    if save_json(new_token_info, TOKEN_FILE):
                        self.token = new_token_info['token']
                        self.expiration_date = datetime.fromisoformat(new_token_info['expiration_date'])
                        self.logger.info("Token renovado com sucesso")
                        return True, "Token renovado com sucesso"
                    else:
                        return False, "Erro ao salvar novo token"
                else:
                    error_msg = response_data.get('message', 'Erro na renovação')
                    self.logger.error(f"Falha na renovação: {error_msg}")
                    return False, error_msg
            else:
                error_msg = f"Erro HTTP {response.status_code}: {response.text}"
                self.logger.error(f"Erro na renovação do token: {error_msg}")
                return False, error_msg
                
        except requests.exceptions.RequestException as e:
            error_msg = f"Erro na renovação: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg
    
    def clear_token(self) -> bool:
        """Remove token e informações de ativação"""
        try:
            self.token = None
            self.device_id = None
            self.activation_date = None
            self.expiration_date = None
            
            # Remover arquivo de token
            if TOKEN_FILE.exists():
                TOKEN_FILE.unlink()
            
            self.logger.info("Token removido com sucesso")
            return True
            
        except Exception as e:
            self.logger.error(f"Erro ao remover token: {e}")
            return False
    
    def get_activation_info(self) -> Dict:
        """Retorna informações de ativação"""
        return {
            'activated': self.is_activated(),
            'device_id': self.device_id,
            'activation_date': self.activation_date.isoformat() if self.activation_date else None,
            'expiration_date': self.expiration_date.isoformat() if self.expiration_date else None,
            'days_until_expiry': self._get_days_until_expiry(),
            'token_exists': bool(self.token)
        }
    
    def _get_days_until_expiry(self) -> Optional[int]:
        """Calcula dias até a expiração do token"""
        if not self.expiration_date:
            return None
        
        time_until_expiry = self.expiration_date - datetime.now()
        return max(0, time_until_expiry.days)
    
    def deactivate_device(self) -> Tuple[bool, str]:
        """Desativa o dispositivo (remove token)"""
        try:
            if self.token:
                # Notificar servidor sobre desativação
                url = f"{API_BASE_URL}/desativar_dispositivo"
                
                headers = {
                    'Authorization': f'Bearer {self.token}',
                    'Content-Type': 'application/json'
                }
                
                data = {
                    'device_id': self.device_id,
                    'timestamp': datetime.now().isoformat()
                }
                
                try:
                    response = requests.post(
                        url,
                        json=data,
                        headers=headers,
                        timeout=30
                    )
                    
                    if response.status_code == 200:
                        self.logger.info("Dispositivo desativado no servidor")
                    else:
                        self.logger.warning("Erro ao desativar no servidor, mas token local removido")
                        
                except:
                    self.logger.warning("Não foi possível notificar servidor sobre desativação")
            
            # Remover token local
            if self.clear_token():
                return True, "Dispositivo desativado com sucesso"
            else:
                return False, "Erro ao remover token local"
                
        except Exception as e:
            error_msg = f"Erro na desativação: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg 