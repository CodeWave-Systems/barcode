"""
Módulo de captura global do scanner de códigos de barras
"""

import evdev
import threading
import time
import queue
from typing import Dict, List, Optional, Callable
from datetime import datetime
import logging
import os
import subprocess

from config.settings import SCANNER_CONFIG
from src.utils import setup_logging, run_command


class BarcodeScanner:
    """Capturador global de códigos de barras usando evdev"""
    
    def __init__(self):
        self.logger = setup_logging("barcode_scanner")
        self.scanner_devices = []
        self.is_running = False
        self.scanner_thread = None
        self.code_buffer = ""
        self.last_key_time = 0
        self.key_timeout = 0.1  # 100ms entre teclas para considerar como um código
        self.callback = None
        self.device_paths = []
        
        # Encontrar dispositivos de scanner
        self._find_scanner_devices()
    
    def _find_scanner_devices(self):
        """Encontra dispositivos de scanner USB"""
        try:
            # Listar dispositivos de entrada
            success, output, _ = run_command("ls /dev/input/event*")
            if not success:
                self.logger.error("Erro ao listar dispositivos de entrada")
                return
            
            for device_path in output.split():
                try:
                    device = evdev.InputDevice(device_path)
                    
                    # Verificar se é um dispositivo de teclado (scanner simula teclado)
                    if evdev.ecodes.EV_KEY in device.capabilities():
                        # Tentar identificar se é um scanner (geralmente tem nome específico)
                        device_name = device.name.lower()
                        if any(keyword in device_name for keyword in ['scanner', 'barcode', 'usb']):
                            self.scanner_devices.append(device)
                            self.device_paths.append(device_path)
                            self.logger.info(f"Scanner encontrado: {device.name} em {device_path}")
                        else:
                            # Verificar se é um teclado USB genérico (pode ser scanner)
                            if 'usb' in device_name and 'keyboard' in device_name:
                                self.scanner_devices.append(device)
                                self.device_paths.append(device_path)
                                self.logger.info(f"Teclado USB encontrado (possível scanner): {device.name} em {device_path}")
                    
                    device.close()
                    
                except Exception as e:
                    self.logger.debug(f"Erro ao verificar dispositivo {device_path}: {e}")
                    continue
            
            if not self.scanner_devices:
                self.logger.warning("Nenhum scanner encontrado. Tentando usar teclado padrão...")
                self._setup_fallback_keyboard()
                
        except Exception as e:
            self.logger.error(f"Erro ao encontrar dispositivos de scanner: {e}")
            self._setup_fallback_keyboard()
    
    def _setup_fallback_keyboard(self):
        """Configura teclado padrão como fallback"""
        try:
            # Tentar usar teclado padrão
            success, output, _ = run_command("ls /dev/input/event*")
            if success:
                for device_path in output.split():
                    try:
                        device = evdev.InputDevice(device_path)
                        if evdev.ecodes.EV_KEY in device.capabilities():
                            self.scanner_devices.append(device)
                            self.device_paths.append(device_path)
                            self.logger.info(f"Usando teclado padrão: {device.name} em {device_path}")
                            break
                        device.close()
                    except:
                        continue
        except Exception as e:
            self.logger.error(f"Erro ao configurar teclado padrão: {e}")
    
    def set_callback(self, callback: Callable[[str, datetime], None]):
        """Define callback para quando um código for capturado"""
        self.callback = callback
    
    def start_capture(self):
        """Inicia captura de códigos de barras"""
        if self.is_running:
            self.logger.warning("Captura já está rodando")
            return False
        
        if not self.scanner_devices:
            self.logger.error("Nenhum dispositivo de scanner disponível")
            return False
        
        self.is_running = True
        self.scanner_thread = threading.Thread(target=self._capture_loop, daemon=True)
        self.scanner_thread.start()
        
        self.logger.info("Captura de scanner iniciada")
        return True
    
    def stop_capture(self):
        """Para captura de códigos de barras"""
        self.is_running = False
        if self.scanner_thread:
            self.scanner_thread.join(timeout=2)
        
        # Fechar dispositivos
        for device in self.scanner_devices:
            try:
                device.close()
            except:
                pass
        
        self.scanner_devices.clear()
        self.logger.info("Captura de scanner parada")
    
    def _capture_loop(self):
        """Loop principal de captura"""
        try:
            # Criar lista de dispositivos para monitorar
            devices = []
            for device_path in self.device_paths:
                try:
                    device = evdev.InputDevice(device_path)
                    devices.append(device)
                except Exception as e:
                    self.logger.error(f"Erro ao abrir dispositivo {device_path}: {e}")
            
            if not devices:
                self.logger.error("Nenhum dispositivo pode ser aberto")
                return
            
            # Monitorar eventos de todos os dispositivos
            while self.is_running:
                try:
                    # Usar select para monitorar múltiplos dispositivos
                    import select
                    ready, _, _ = select.select(devices, [], [], 0.1)
                    
                    for device in ready:
                        try:
                            for event in device.read():
                                if event.type == evdev.ecodes.EV_KEY:
                                    self._process_key_event(event)
                        except (OSError, BlockingIOError):
                            continue
                        except Exception as e:
                            self.logger.error(f"Erro ao ler eventos do dispositivo {device.path}: {e}")
                            continue
                            
                except Exception as e:
                    self.logger.error(f"Erro no loop de captura: {e}")
                    time.sleep(0.1)
                    
        except Exception as e:
            self.logger.error(f"Erro fatal no loop de captura: {e}")
        finally:
            # Fechar dispositivos
            for device in devices:
                try:
                    device.close()
                except:
                    pass
    
    def _process_key_event(self, event):
        """Processa evento de tecla do scanner"""
        if event.code == evdev.ecodes.KEY_ENTER:
            # Enter indica fim do código
            if self.code_buffer:
                self._process_complete_code()
        elif event.code == evdev.ecodes.KEY_BACKSPACE:
            # Backspace remove último caractere
            if self.code_buffer:
                self.code_buffer = self.code_buffer[:-1]
        elif event.value == 1:  # Tecla pressionada
            # Verificar timeout entre teclas
            current_time = time.time()
            if current_time - self.last_key_time > self.key_timeout:
                self.code_buffer = ""
            
            self.last_key_time = current_time
            
            # Converter código de tecla para caractere
            char = self._keycode_to_char(event.code)
            if char:
                self.code_buffer += char
    
    def _keycode_to_char(self, keycode):
        """Converte código de tecla para caractere"""
        # Mapeamento básico de códigos de tecla para caracteres
        key_mapping = {
            evdev.ecodes.KEY_A: 'a', evdev.ecodes.KEY_B: 'b', evdev.ecodes.KEY_C: 'c',
            evdev.ecodes.KEY_D: 'd', evdev.ecodes.KEY_E: 'e', evdev.ecodes.KEY_F: 'f',
            evdev.ecodes.KEY_G: 'g', evdev.ecodes.KEY_H: 'h', evdev.ecodes.KEY_I: 'i',
            evdev.ecodes.KEY_J: 'j', evdev.ecodes.KEY_K: 'k', evdev.ecodes.KEY_L: 'l',
            evdev.ecodes.KEY_M: 'm', evdev.ecodes.KEY_N: 'n', evdev.ecodes.KEY_O: 'o',
            evdev.ecodes.KEY_P: 'p', evdev.ecodes.KEY_Q: 'q', evdev.ecodes.KEY_R: 'r',
            evdev.ecodes.KEY_S: 's', evdev.ecodes.KEY_T: 't', evdev.ecodes.KEY_U: 'u',
            evdev.ecodes.KEY_V: 'v', evdev.ecodes.KEY_W: 'w', evdev.ecodes.KEY_X: 'x',
            evdev.ecodes.KEY_Y: 'y', evdev.ecodes.KEY_Z: 'z',
            evdev.ecodes.KEY_0: '0', evdev.ecodes.KEY_1: '1', evdev.ecodes.KEY_2: '2',
            evdev.ecodes.KEY_3: '3', evdev.ecodes.KEY_4: '4', evdev.ecodes.KEY_5: '5',
            evdev.ecodes.KEY_6: '6', evdev.ecodes.KEY_7: '7', evdev.ecodes.KEY_8: '8',
            evdev.ecodes.KEY_9: '9',
            evdev.ecodes.KEY_MINUS: '-', evdev.ecodes.KEY_EQUAL: '=',
            evdev.ecodes.KEY_LEFTBRACE: '[', evdev.ecodes.KEY_RIGHTBRACE: ']',
            evdev.ecodes.KEY_BACKSLASH: '\\', evdev.ecodes.KEY_SEMICOLON: ';',
            evdev.ecodes.KEY_APOSTROPHE: "'", evdev.ecodes.KEY_GRAVE: '`',
            evdev.ecodes.KEY_COMMA: ',', evdev.ecodes.KEY_DOT: '.',
            evdev.ecodes.KEY_SLASH: '/', evdev.ecodes.KEY_SPACE: ' '
        }
        
        return key_mapping.get(keycode, '')
    
    def _process_complete_code(self):
        """Processa código completo capturado"""
        if not self.code_buffer:
            return
        
        code = self.code_buffer.strip()
        timestamp = datetime.now()
        
        self.logger.info(f"Código capturado: {code} em {timestamp}")
        
        # Chamar callback se definido
        if self.callback:
            try:
                self.callback(code, timestamp)
            except Exception as e:
                self.logger.error(f"Erro no callback: {e}")
        
        # Limpar buffer
        self.code_buffer = ""
    
    def get_scanner_status(self) -> Dict:
        """Retorna status do scanner"""
        return {
            'running': self.is_running,
            'devices_found': len(self.scanner_devices),
            'device_paths': self.device_paths,
            'current_buffer': self.code_buffer,
            'last_activity': self.last_key_time
        }
    
    def test_scanner(self) -> bool:
        """Testa se o scanner está funcionando"""
        try:
            if not self.scanner_devices:
                return False
            
            # Tentar abrir um dispositivo
            device = evdev.InputDevice(self.device_paths[0])
            device.close()
            return True
            
        except Exception as e:
            self.logger.error(f"Erro no teste do scanner: {e}")
            return False
    
    def refresh_devices(self):
        """Atualiza lista de dispositivos"""
        self.stop_capture()
        self._find_scanner_devices()
        if self.is_running:
            self.start_capture()


class MockScanner(BarcodeScanner):
    """Scanner simulado para testes"""
    
    def __init__(self):
        super().__init__()
        self.logger.info("Usando scanner simulado para testes")
    
    def simulate_barcode(self, code: str):
        """Simula leitura de código de barras"""
        if self.callback:
            self.callback(code, datetime.now())
    
    def _find_scanner_devices(self):
        """Não procura dispositivos reais"""
        pass
    
    def start_capture(self):
        """Não inicia captura real"""
        self.is_running = True
        self.logger.info("Scanner simulado ativado")
        return True
    
    def stop_capture(self):
        """Para scanner simulado"""
        self.is_running = False
        self.logger.info("Scanner simulado parado") 