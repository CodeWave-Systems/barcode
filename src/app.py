"""
Aplicação principal GUI para sistema de scanner Raspberry Pi
"""

import customtkinter as ctk
import threading
import time
from datetime import datetime
from typing import Dict, List
import logging
import os
import sys

# Adicionar diretório pai ao path para imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config.settings import GUI_CONFIG
from src.utils import setup_logging, is_raspberry_pi
from src.network import NetworkManager
from src.activation import DeviceActivation
from src.scanner import BarcodeScanner, MockScanner
from src.sync import DataSync
from src.datetime_config import DateTimeManager


class ScannerApp:
    """Aplicação principal do sistema de scanner"""
    
    def __init__(self):
        # Configurar CustomTkinter
        ctk.set_appearance_mode(GUI_CONFIG["theme"])
        ctk.set_default_color_theme("blue")
        
        # Configurar logger
        self.logger = setup_logging("scanner_app")
        
        # Inicializar gerenciadores
        self.network_manager = NetworkManager()
        self.activation_manager = DeviceActivation()
        self.datetime_manager = DateTimeManager()
        
        # Usar scanner simulado se não for Raspberry Pi
        if is_raspberry_pi():
            self.scanner = BarcodeScanner()
        else:
            self.scanner = MockScanner()
        
        self.data_sync = DataSync(self.activation_manager)
        
        # Configurar callback do scanner
        self.scanner.set_callback(self._on_barcode_scanned)
        
        # Estado da aplicação
        self.current_frame = None
        self.scanned_codes = []
        self.is_activated = False
        
        # Criar janela principal
        self.root = ctk.CTk()
        self._setup_main_window()
        
        # Inicializar interface
        self._init_interface()
        
        # Verificar ativação
        self._check_activation()
        
        # Iniciar scanner se ativado
        if self.is_activated:
            self._start_scanner()
    
    def _setup_main_window(self):
        """Configura janela principal"""
        self.root.title(GUI_CONFIG["title"])
        self.root.geometry(f"{GUI_CONFIG['width']}x{GUI_CONFIG['height']}")
        
        if GUI_CONFIG["fullscreen"]:
            self.root.attributes('-fullscreen', True)
            self.root.focus_force()
        
        # Bloquear fechamento da janela
        self.root.protocol("WM_DELETE_WINDOW", self._on_closing)
        self.root.bind("<Escape>", self._on_escape)
        
        # Configurar grid
        self.root.grid_rowconfigure(0, weight=1)
        self.root.grid_columnconfigure(0, weight=1)
    
    def _init_interface(self):
        """Inicializa interface principal"""
        # Frame principal
        self.main_frame = ctk.CTkFrame(self.root)
        self.main_frame.grid(row=0, column=0, sticky="nsew", padx=10, pady=10)
        self.main_frame.grid_rowconfigure(1, weight=1)
        self.main_frame.grid_columnconfigure(0, weight=1)
        
        # Barra de título
        self._create_title_bar()
        
        # Frame de conteúdo
        self.content_frame = ctk.CTkFrame(self.main_frame)
        self.content_frame.grid(row=1, column=0, sticky="nsew", padx=10, pady=10)
        self.content_frame.grid_rowconfigure(0, weight=1)
        self.content_frame.grid_columnconfigure(0, weight=1)
        
        # Mostrar tela inicial
        self._show_welcome_screen()
    
    def _create_title_bar(self):
        """Cria barra de título com informações do sistema"""
        title_frame = ctk.CTkFrame(self.main_frame)
        title_frame.grid(row=0, column=0, sticky="ew", padx=10, pady=(10, 5))
        title_frame.grid_columnconfigure(1, weight=1)
        
        # Título
        title_label = ctk.CTkLabel(
            title_frame, 
            text=GUI_CONFIG["title"],
            font=ctk.CTkFont(size=20, weight="bold")
        )
        title_label.grid(row=0, column=0, padx=10, pady=10)
        
        # Status da rede
        self.network_status_label = ctk.CTkLabel(
            title_frame,
            text="Rede: Verificando...",
            font=ctk.CTkFont(size=12)
        )
        self.network_status_label.grid(row=0, column=1, padx=10, pady=10)
        
        # Status da ativação
        self.activation_status_label = ctk.CTkLabel(
            title_frame,
            text="Ativação: Verificando...",
            font=ctk.CTkFont(size=12)
        )
        self.activation_status_label.grid(row=0, column=2, padx=10, pady=10)
        
        # Data e hora
        self.datetime_label = ctk.CTkLabel(
            title_frame,
            text="",
            font=ctk.CTkFont(size=12)
        )
        self.datetime_label.grid(row=0, column=3, padx=10, pady=10)
        
        # Botões de ação
        button_frame = ctk.CTkFrame(title_frame)
        button_frame.grid(row=0, column=4, padx=10, pady=10)
        
        # Botão de configuração
        self.config_button = ctk.CTkButton(
            button_frame,
            text="⚙️",
            width=40,
            command=self._show_config_screen
        )
        self.config_button.grid(row=0, column=0, padx=2)
        
        # Botão de rede
        self.network_button = ctk.CTkButton(
            button_frame,
            text="🌐",
            width=40,
            command=self._show_network_screen
        )
        self.network_button.grid(row=0, column=1, padx=2)
        
        # Atualizar status periodicamente
        self._update_status()
    
    def _show_welcome_screen(self):
        """Mostra tela de boas-vindas"""
        self._clear_content_frame()
        
        welcome_frame = ctk.CTkFrame(self.content_frame)
        welcome_frame.grid(row=0, column=0, sticky="nsew", padx=20, pady=20)
        welcome_frame.grid_rowconfigure(1, weight=1)
        welcome_frame.grid_columnconfigure(0, weight=1)
        
        # Título de boas-vindas
        welcome_label = ctk.CTkLabel(
            welcome_frame,
            text="Bem-vindo ao Sistema de Scanner",
            font=ctk.CTkFont(size=24, weight="bold")
        )
        welcome_label.grid(row=0, column=0, pady=(20, 10))
        
        # Status do sistema
        status_frame = ctk.CTkFrame(welcome_frame)
        status_frame.grid(row=1, column=0, sticky="ew", padx=20, pady=10)
        
        # Status da ativação
        activation_status = "✅ Ativado" if self.is_activated else "❌ Não ativado"
        activation_label = ctk.CTkLabel(
            status_frame,
            text=f"Status: {activation_status}",
            font=ctk.CTkFont(size=16)
        )
        activation_label.grid(row=0, column=0, padx=20, pady=10, sticky="w")
        
        # Status da rede
        network_status = self.network_manager.get_connection_status()
        network_text = f"Rede: {network_status['type']} - {network_status['ssid'] or network_status['ip']}"
        network_label = ctk.CTkLabel(
            status_frame,
            text=network_text,
            font=ctk.CTkFont(size=16)
        )
        network_label.grid(row=1, column=0, padx=20, pady=10, sticky="w")
        
        # Status do scanner
        scanner_status = self.scanner.get_scanner_status()
        scanner_text = f"Scanner: {'✅ Ativo' if scanner_status['running'] else '❌ Inativo'}"
        scanner_label = ctk.CTkLabel(
            status_frame,
            text=scanner_text,
            font=ctk.CTkFont(size=16)
        )
        scanner_label.grid(row=2, column=0, padx=20, pady=10, sticky="w")
        
        # Botões de ação
        button_frame = ctk.CTkFrame(welcome_frame)
        button_frame.grid(row=2, column=0, pady=20)
        
        if not self.is_activated:
            # Botão de ativação
            activate_button = ctk.CTkButton(
                button_frame,
                text="Ativar Dispositivo",
                command=self._show_activation_screen,
                font=ctk.CTkFont(size=16)
            )
            activate_button.grid(row=0, column=0, padx=10, pady=10)
        else:
            # Botão para ir para tela de scanner
            scanner_button = ctk.CTkButton(
                button_frame,
                text="Ir para Scanner",
                command=self._show_scanner_screen,
                font=ctk.CTkFont(size=16)
            )
            scanner_button.grid(row=0, column=0, padx=10, pady=10)
        
        # Botão de configuração de rede
        network_config_button = ctk.CTkButton(
            button_frame,
            text="Configurar Rede",
            command=self._show_network_screen,
            font=ctk.CTkFont(size=16)
        )
        network_config_button.grid(row=0, column=1, padx=10, pady=10)
        
        # Botão de configuração de data/hora
        datetime_config_button = ctk.CTkButton(
            button_frame,
            text="Data/Hora",
            command=self._show_datetime_screen,
            font=ctk.CTkFont(size=16)
        )
        datetime_config_button.grid(row=0, column=2, padx=10, pady=10)
    
    def _show_activation_screen(self):
        """Mostra tela de ativação"""
        self._clear_content_frame()
        
        activation_frame = ctk.CTkFrame(self.content_frame)
        activation_frame.grid(row=0, column=0, sticky="nsew", padx=20, pady=20)
        activation_frame.grid_rowconfigure(2, weight=1)
        activation_frame.grid_columnconfigure(0, weight=1)
        
        # Título
        title_label = ctk.CTkLabel(
            activation_frame,
            text="Ativação do Dispositivo",
            font=ctk.CTkFont(size=24, weight="bold")
        )
        title_label.grid(row=0, column=0, pady=(20, 10))
        
        # Formulário de ativação
        form_frame = ctk.CTkFrame(activation_frame)
        form_frame.grid(row=1, column=0, sticky="ew", padx=20, pady=10)
        
        # Campo de chave de ativação
        key_label = ctk.CTkLabel(form_frame, text="Chave de Ativação:")
        key_label.grid(row=0, column=0, padx=10, pady=10, sticky="w")
        
        self.activation_key_entry = ctk.CTkEntry(
            form_frame,
            placeholder_text="Digite sua chave de ativação",
            width=300
        )
        self.activation_key_entry.grid(row=0, column=1, padx=10, pady=10)
        
        # Botão de ativação
        activate_button = ctk.CTkButton(
            form_frame,
            text="Ativar",
            command=self._activate_device,
            font=ctk.CTkFont(size=16)
        )
        activate_button.grid(row=0, column=2, padx=10, pady=10)
        
        # Status da ativação
        self.activation_status_label = ctk.CTkLabel(
            activation_frame,
            text="",
            font=ctk.CTkFont(size=14)
        )
        self.activation_status_label.grid(row=2, column=0, pady=20)
        
        # Botão voltar
        back_button = ctk.CTkButton(
            activation_frame,
            text="← Voltar",
            command=self._show_welcome_screen,
            font=ctk.CTkFont(size=14)
        )
        back_button.grid(row=3, column=0, pady=10)
    
    def _show_scanner_screen(self):
        """Mostra tela principal do scanner"""
        if not self.is_activated:
            self._show_welcome_screen()
            return
        
        self._clear_content_frame()
        
        scanner_frame = ctk.CTkFrame(self.content_frame)
        scanner_frame.grid(row=0, column=0, sticky="nsew", padx=20, pady=20)
        scanner_frame.grid_rowconfigure(1, weight=1)
        scanner_frame.grid_columnconfigure(0, weight=1)
        
        # Título
        title_label = ctk.CTkLabel(
            scanner_frame,
            text="Scanner de Códigos de Barras",
            font=ctk.CTkFont(size=24, weight="bold")
        )
        title_label.grid(row=0, column=0, pady=(20, 10))
        
        # Frame para lista de códigos
        codes_frame = ctk.CTkFrame(scanner_frame)
        codes_frame.grid(row=1, column=0, sticky="nsew", padx=20, pady=10)
        codes_frame.grid_rowconfigure(0, weight=1)
        codes_frame.grid_columnconfigure(0, weight=1)
        
        # Lista de códigos escaneados
        codes_label = ctk.CTkLabel(
            codes_frame,
            text="Códigos Escaneados:",
            font=ctk.CTkFont(size=16, weight="bold")
        )
        codes_label.grid(row=0, column=0, padx=10, pady=10, sticky="w")
        
        # Textbox para códigos
        self.codes_textbox = ctk.CTkTextbox(
            codes_frame,
            width=600,
            height=400
        )
        self.codes_textbox.grid(row=1, column=0, padx=10, pady=10, sticky="nsew")
        
        # Atualizar lista de códigos
        self._update_codes_display()
        
        # Botões de ação
        button_frame = ctk.CTkFrame(scanner_frame)
        button_frame.grid(row=2, column=0, pady=20)
        
        # Botão de sincronização forçada
        sync_button = ctk.CTkButton(
            button_frame,
            text="🔄 Sincronizar",
            command=self._force_sync,
            font=ctk.CTkFont(size=14)
        )
        sync_button.grid(row=0, column=0, padx=10, pady=10)
        
        # Botão voltar
        back_button = ctk.CTkButton(
            button_frame,
            text="← Voltar",
            command=self._show_welcome_screen,
            font=ctk.CTkFont(size=14)
        )
        back_button.grid(row=0, column=1, padx=10, pady=10)
    
    def _show_network_screen(self):
        """Mostra tela de configuração de rede"""
        self._clear_content_frame()
        
        network_frame = ctk.CTkFrame(self.content_frame)
        network_frame.grid(row=0, column=0, sticky="nsew", padx=20, pady=20)
        network_frame.grid_rowconfigure(1, weight=1)
        network_frame.grid_columnconfigure(0, weight=1)
        
        # Título
        title_label = ctk.CTkLabel(
            network_frame,
            text="Configuração de Rede",
            font=ctk.CTkFont(size=24, weight="bold")
        )
        title_label.grid(row=0, column=0, pady=(20, 10))
        
        # Frame para configurações
        config_frame = ctk.CTkFrame(network_frame)
        config_frame.grid(row=1, column=0, sticky="ew", padx=20, pady=10)
        
        # Status atual da rede
        status_frame = ctk.CTkFrame(config_frame)
        status_frame.grid(row=0, column=0, sticky="ew", padx=10, pady=10)
        
        network_status = self.network_manager.get_connection_status()
        status_text = f"Status: {'Conectado' if network_status['connected'] == 'true' else 'Desconectado'}"
        status_label = ctk.CTkLabel(
            status_frame,
            text=status_text,
            font=ctk.CTkFont(size=16)
        )
        status_label.grid(row=0, column=0, padx=10, pady=10, sticky="w")
        
        # Configuração Wi-Fi
        wifi_frame = ctk.CTkFrame(config_frame)
        wifi_frame.grid(row=1, column=0, sticky="ew", padx=10, pady=10)
        
        wifi_label = ctk.CTkLabel(
            wifi_frame,
            text="Configuração Wi-Fi:",
            font=ctk.CTkFont(size=16, weight="bold")
        )
        wifi_label.grid(row=0, column=0, padx=10, pady=10, sticky="w")
        
        # Campo SSID
        ssid_label = ctk.CTkLabel(wifi_frame, text="SSID:")
        ssid_label.grid(row=1, column=0, padx=10, pady=5, sticky="w")
        
        self.ssid_entry = ctk.CTkEntry(
            wifi_frame,
            placeholder_text="Nome da rede Wi-Fi",
            width=200
        )
        self.ssid_entry.grid(row=1, column=1, padx=10, pady=5)
        
        # Campo senha
        password_label = ctk.CTkLabel(wifi_frame, text="Senha:")
        password_label.grid(row=2, column=0, padx=10, pady=5, sticky="w")
        
        self.password_entry = ctk.CTkEntry(
            wifi_frame,
            placeholder_text="Senha da rede",
            width=200,
            show="*"
        )
        self.password_entry.grid(row=2, column=1, padx=10, pady=5)
        
        # Botão conectar
        connect_button = ctk.CTkButton(
            wifi_frame,
            text="Conectar Wi-Fi",
            command=self._connect_wifi,
            font=ctk.CTkFont(size=14)
        )
        connect_button.grid(row=2, column=2, padx=10, pady=5)
        
        # Botão voltar
        back_button = ctk.CTkButton(
            network_frame,
            text="← Voltar",
            command=self._show_welcome_screen,
            font=ctk.CTkFont(size=14)
        )
        back_button.grid(row=2, column=0, pady=20)
    
    def _show_datetime_screen(self):
        """Mostra tela de configuração de data e hora"""
        self._clear_content_frame()
        
        datetime_frame = ctk.CTkFrame(self.content_frame)
        datetime_frame.grid(row=0, column=0, sticky="nsew", padx=20, pady=20)
        datetime_frame.grid_rowconfigure(1, weight=1)
        datetime_frame.grid_columnconfigure(0, weight=1)
        
        # Título
        title_label = ctk.CTkLabel(
            datetime_frame,
            text="Configuração de Data e Hora",
            font=ctk.CTkFont(size=24, weight="bold")
        )
        title_label.grid(row=0, column=0, pady=(20, 10))
        
        # Status atual
        status_frame = ctk.CTkFrame(datetime_frame)
        status_frame.grid(row=1, column=0, sticky="ew", padx=20, pady=10)
        
        datetime_status = self.datetime_manager.get_datetime_status()
        
        # Data e hora atual
        current_time = self.datetime_manager.format_datetime_for_display()
        time_label = ctk.CTkLabel(
            status_frame,
            text=f"Data/Hora Atual: {current_time}",
            font=ctk.CTkFont(size=16)
        )
        time_label.grid(row=0, column=0, padx=10, pady=10, sticky="w")
        
        # Timezone
        timezone_label = ctk.CTkLabel(
            status_frame,
            text=f"Timezone: {datetime_status['timezone']}",
            font=ctk.CTkFont(size=16)
        )
        timezone_label.grid(row=1, column=0, padx=10, pady=10, sticky="w")
        
        # Botões de ação
        button_frame = ctk.CTkFrame(datetime_frame)
        button_frame.grid(row=2, column=0, pady=20)
        
        # Botão sincronizar NTP
        ntp_button = ctk.CTkButton(
            button_frame,
            text="🕐 Sincronizar NTP",
            command=self._sync_ntp,
            font=ctk.CTkFont(size=14)
        )
        ntp_button.grid(row=0, column=0, padx=10, pady=10)
        
        # Botão voltar
        back_button = ctk.CTkButton(
            button_frame,
            text="← Voltar",
            command=self._show_welcome_screen,
            font=ctk.CTkFont(size=14)
        )
        back_button.grid(row=0, column=1, padx=10, pady=10)
    
    def _show_config_screen(self):
        """Mostra tela de configurações gerais"""
        self._clear_content_frame()
        
        config_frame = ctk.CTkFrame(self.content_frame)
        config_frame.grid(row=0, column=0, sticky="nsew", padx=20, pady=20)
        config_frame.grid_rowconfigure(1, weight=1)
        config_frame.grid_columnconfigure(0, weight=1)
        
        # Título
        title_label = ctk.CTkLabel(
            config_frame,
            text="Configurações do Sistema",
            font=ctk.CTkFont(size=24, weight="bold")
        )
        title_label.grid(row=0, column=0, pady=(20, 10))
        
        # Opções de configuração
        options_frame = ctk.CTkFrame(config_frame)
        options_frame.grid(row=1, column=0, sticky="ew", padx=20, pady=10)
        
        # Botão para sair do fullscreen
        fullscreen_button = ctk.CTkButton(
            options_frame,
            text="🖥️ Sair do Fullscreen",
            command=self._toggle_fullscreen,
            font=ctk.CTkFont(size=16)
        )
        fullscreen_button.grid(row=0, column=0, padx=10, pady=10)
        
        # Botão para reiniciar aplicação
        restart_button = ctk.CTkButton(
            options_frame,
            text="🔄 Reiniciar Aplicação",
            command=self._restart_app,
            font=ctk.CTkFont(size=16)
        )
        restart_button.grid(row=1, column=0, padx=10, pady=10)
        
        # Botão voltar
        back_button = ctk.CTkButton(
            config_frame,
            text="← Voltar",
            command=self._show_welcome_screen,
            font=ctk.CTkFont(size=14)
        )
        back_button.grid(row=2, column=0, pady=20)
    
    def _clear_content_frame(self):
        """Limpa o frame de conteúdo"""
        for widget in self.content_frame.winfo_children():
            widget.destroy()
    
    def _check_activation(self):
        """Verifica status da ativação"""
        self.is_activated = self.activation_manager.is_activated()
        self.logger.info(f"Status da ativação: {self.is_activated}")
    
    def _activate_device(self):
        """Ativa o dispositivo"""
        activation_key = self.activation_key_entry.get().strip()
        
        if not activation_key:
            self.activation_status_label.configure(
                text="❌ Digite uma chave de ativação",
                text_color="red"
            )
            return
        
        # Desabilitar botão durante ativação
        self.activation_status_label.configure(
            text="⏳ Ativando dispositivo...",
            text_color="orange"
        )
        
        # Executar ativação em thread separada
        def activate_thread():
            success, message = self.activation_manager.activate_device(activation_key)
            
            if success:
                self.is_activated = True
                self.activation_status_label.configure(
                    text=f"✅ {message}",
                    text_color="green"
                )
                
                # Iniciar scanner após ativação
                self._start_scanner()
                
                # Voltar para tela principal após 2 segundos
                self.root.after(2000, self._show_welcome_screen)
            else:
                self.activation_status_label.configure(
                    text=f"❌ {message}",
                    text_color="red"
                )
        
        threading.Thread(target=activate_thread, daemon=True).start()
    
    def _start_scanner(self):
        """Inicia o scanner"""
        if self.scanner.start_capture():
            self.logger.info("Scanner iniciado com sucesso")
        else:
            self.logger.error("Falha ao iniciar scanner")
    
    def _on_barcode_scanned(self, code: str, timestamp: datetime):
        """Callback chamado quando um código é escaneado"""
        self.logger.info(f"Código escaneado: {code}")
        
        # Adicionar à lista local
        code_data = {
            'code': code,
            'timestamp': timestamp,
            'formatted_time': timestamp.strftime("%d/%m/%Y %H:%M:%S")
        }
        self.scanned_codes.append(code_data)
        
        # Adicionar para sincronização
        self.data_sync.add_code(code, timestamp)
        
        # Atualizar interface se estiver na tela de scanner
        if hasattr(self, 'codes_textbox'):
            self._update_codes_display()
        
        # Feedback visual
        self._show_scan_feedback(code)
    
    def _show_scan_feedback(self, code: str):
        """Mostra feedback visual do escaneamento"""
        # Criar popup temporário
        feedback_window = ctk.CTkToplevel(self.root)
        feedback_window.title("Código Escaneado")
        feedback_window.geometry("300x150")
        feedback_window.attributes('-topmost', True)
        
        # Centralizar na tela
        feedback_window.update_idletasks()
        x = (feedback_window.winfo_screenwidth() // 2) - (300 // 2)
        y = (feedback_window.winfo_screenheight() // 2) - (150 // 2)
        feedback_window.geometry(f"300x150+{x}+{y}")
        
        # Conteúdo
        ctk.CTkLabel(
            feedback_window,
            text="✅ Código Escaneado!",
            font=ctk.CTkFont(size=18, weight="bold")
        ).pack(pady=20)
        
        ctk.CTkLabel(
            feedback_window,
            text=f"Código: {code}",
            font=ctk.CTkFont(size=14)
        ).pack(pady=10)
        
        # Fechar automaticamente após 2 segundos
        feedback_window.after(2000, feedback_window.destroy)
    
    def _update_codes_display(self):
        """Atualiza exibição dos códigos escaneados"""
        if not hasattr(self, 'codes_textbox'):
            return
        
        self.codes_textbox.delete("1.0", "end")
        
        if not self.scanned_codes:
            self.codes_textbox.insert("1.0", "Nenhum código escaneado ainda.")
            return
        
        # Mostrar últimos 50 códigos
        recent_codes = self.scanned_codes[-50:]
        
        for code_data in reversed(recent_codes):
            line = f"{code_data['formatted_time']} - {code_data['code']}\n"
            self.codes_textbox.insert("1.0", line)
    
    def _force_sync(self):
        """Força sincronização imediata"""
        def sync_thread():
            successful, failed = self.data_sync.force_sync()
            
            # Mostrar resultado
            if successful > 0 or failed > 0:
                message = f"Sincronização: {successful} sucessos, {failed} falhas"
                self.logger.info(message)
            else:
                message = "Nenhum código para sincronizar"
                self.logger.info(message)
        
        threading.Thread(target=sync_thread, daemon=True).start()
    
    def _connect_wifi(self):
        """Conecta à rede Wi-Fi"""
        ssid = self.ssid_entry.get().strip()
        password = self.password_entry.get().strip()
        
        if not ssid or not password:
            return
        
        def connect_thread():
            success, message = self.network_manager.connect_wifi(ssid, password)
            self.logger.info(f"Tentativa de conexão Wi-Fi: {message}")
        
        threading.Thread(target=connect_thread, daemon=True).start()
    
    def _sync_ntp(self):
        """Sincroniza com servidor NTP"""
        def sync_thread():
            success, message = self.datetime_manager.sync_with_ntp()
            self.logger.info(f"Sincronização NTP: {message}")
        
        threading.Thread(target=sync_thread, daemon=True).start()
    
    def _toggle_fullscreen(self):
        """Alterna modo fullscreen"""
        if self.root.attributes('-fullscreen'):
            self.root.attributes('-fullscreen', False)
        else:
            self.root.attributes('-fullscreen', True)
            self.root.focus_force()
    
    def _restart_app(self):
        """Reinicia a aplicação"""
        self.root.quit()
        os.execv(sys.executable, ['python'] + sys.argv)
    
    def _update_status(self):
        """Atualiza status da interface"""
        try:
            # Status da rede
            network_status = self.network_manager.get_connection_status()
            if network_status['connected'] == 'true':
                network_text = f"🌐 {network_status['type']}: {network_status['ssid'] or network_status['ip']}"
                network_color = "green"
            else:
                network_text = "🌐 Desconectado"
                network_color = "red"
            
            self.network_status_label.configure(text=network_text, text_color=network_color)
            
            # Status da ativação
            if self.is_activated:
                activation_text = "✅ Ativado"
                activation_color = "green"
            else:
                activation_text = "❌ Não ativado"
                activation_color = "red"
            
            self.activation_status_label.configure(text=activation_text, text_color=activation_color)
            
            # Data e hora
            current_time = self.datetime_manager.format_datetime_for_display()
            self.datetime_label.configure(text=f"🕐 {current_time}")
            
        except Exception as e:
            self.logger.error(f"Erro ao atualizar status: {e}")
        
        # Agendar próxima atualização
        self.root.after(1000, self._update_status)
    
    def _on_closing(self):
        """Trata fechamento da aplicação"""
        self.logger.info("Aplicação sendo fechada")
        
        # Parar scanner
        if hasattr(self, 'scanner'):
            self.scanner.stop_capture()
        
        # Parar sincronização
        if hasattr(self, 'data_sync'):
            self.data_sync.stop_sync_thread()
        
        # Fechar aplicação
        self.root.quit()
    
    def _on_escape(self, event):
        """Trata tecla Escape"""
        # Não permitir sair com Escape em modo kiosk
        if GUI_CONFIG["fullscreen"]:
            return "break"
    
    def run(self):
        """Executa a aplicação"""
        try:
            self.logger.info("Iniciando aplicação de scanner")
            self.root.mainloop()
        except Exception as e:
            self.logger.error(f"Erro na aplicação: {e}")
            raise


def main():
    """Função principal"""
    try:
        app = ScannerApp()
        app.run()
    except Exception as e:
        print(f"Erro fatal na aplicação: {e}")
        logging.error(f"Erro fatal na aplicação: {e}")


if __name__ == "__main__":
    main() 