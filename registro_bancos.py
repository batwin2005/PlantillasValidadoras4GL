# -*- coding: utf-8 -*-
"""
Registro de Bancos - Sistema Plantillas4GL
Permite mapear cada banco con su plantilla Excel específica.
"""

import json
from pathlib import Path
from typing import Dict, Optional, List
from dataclasses import dataclass, asdict
from datetime import datetime

# ============================================================
# ESTRUCTURA DE DATOS
# ============================================================

@dataclass
class BancoConfig:
    """Configuración de un banco."""
    codigo: str                    # Código único (ej: "galicia", "nacion")
    nombre: str                    # Nombre completo (ej: "Banco Galicia")
    plantilla: str                 # Ruta a la plantilla Excel
    activo: bool = True            # Si está habilitado
    descripcion: str = ""          # Descripción opcional
    fecha_registro: str = ""       # Fecha de registro
    
    # Campos específicos del banco (opcionales)
    campos_extra: Dict = None      # Campos adicionales específicos
    
    def __post_init__(self):
        if self.campos_extra is None:
            self.campos_extra = {}
        if not self.fecha_registro:
            self.fecha_registro = datetime.now().strftime("%Y-%m-%d %H:%M:%S")


# ============================================================
# REGISTRO DE BANCOS
# ============================================================

class RegistroBancos:
    """
    Registro central de bancos y sus plantillas.
    
    Uso:
        registro = RegistroBancos()
        registro.registrar_banco("galicia", "Banco Galicia", "plantillas/galicia.xlsx")
        registro.registrar_banco("nacion", "Banco Nación", "plantillas/nacion.xlsx")
        
        # Obtener plantilla
        ruta = registro.obtener_plantilla("galicia")
        
        # Listar bancos activos
        bancos = registro.listar_bancos_activos()
    """
    
    def __init__(self, archivo_config: str = "bancos_config.json"):
        self.archivo_config = Path(archivo_config)
        self.bancos: Dict[str, BancoConfig] = {}
        self._cargar_config()
    
    def _cargar_config(self):
        """Carga la configuración desde archivo JSON."""
        if self.archivo_config.exists():
            try:
                with open(self.archivo_config, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    for codigo, config in data.get('bancos', {}).items():
                        self.bancos[codigo] = BancoConfig(**config)
                print(f"[OK] Cargados {len(self.bancos)} bancos desde {self.archivo_config}")
            except Exception as e:
                print(f"[ERROR] Error cargando config: {e}")
                self.bancos = {}
        else:
            print(f"[INFO] No existe config, creando registro vacío")
            self.bancos = {}
    
    def _guardar_config(self):
        """Guarda la configuración en archivo JSON."""
        try:
            data = {
                'bancos': {
                    codigo: asdict(banco) 
                    for codigo, banco in self.bancos.items()
                },
                'actualizado': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
            with open(self.archivo_config, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            print(f"[OK] Config guardada en {self.archivo_config}")
            return True
        except Exception as e:
            print(f"[ERROR] Error guardando config: {e}")
            return False
    
    # ============================================================
    # OPERACIONES CRUD
    # ============================================================
    
    def registrar_banco(self, codigo: str, nombre: str, plantilla: str, 
                       descripcion: str = "", campos_extra: Dict = None) -> bool:
        """
        Registra un nuevo banco.
        
        Args:
            codigo: Código único del banco (minúsculas, sin espacios)
            nombre: Nombre completo del banco
            plantilla: Ruta al archivo de plantilla Excel
            descripcion: Descripción opcional
            campos_extra: Campos adicionales específicos del banco
        
        Returns:
            True si se registró correctamente
        """
        # Validar código
        if codigo in self.bancos:
            print(f"[WARNING] El banco '{codigo}' ya existe. Use actualizar_banco().")
            return False
        
        # Crear config
        banco = BancoConfig(
            codigo=codigo,
            nombre=nombre,
            plantilla=plantilla,
            descripcion=descripcion,
            campos_extra=campos_extra or {}
        )
        
        # Verificar que la plantilla existe
        if not Path(plantilla).exists():
            print(f"[WARNING] La plantilla '{plantilla}' no existe. Verifique la ruta.")
            # No bloqueamos, puede crearla después
        
        self.bancos[codigo] = banco
        self._guardar_config()
        
        print(f"[OK] Banco registrado: {nombre} ({codigo})")
        print(f"     Plantilla: {plantilla}")
        return True
    
    def actualizar_banco(self, codigo: str, **kwargs) -> bool:
        """
        Actualiza un banco existente.
        
        Args:
            codigo: Código del banco
            **kwargs: Campos a actualizar (nombre, plantilla, activo, etc.)
        
        Returns:
            True si se actualizó correctamente
        """
        if codigo not in self.bancos:
            print(f"[ERROR] Banco '{codigo}' no encontrado")
            return False
        
        banco = self.bancos[codigo]
        
        for key, value in kwargs.items():
            if hasattr(banco, key):
                setattr(banco, key, value)
            else:
                print(f"[WARNING] Campo '{key}' no existe")
        
        self._guardar_config()
        print(f"[OK] Banco '{codigo}' actualizado")
        return True
    
    def eliminar_banco(self, codigo: str) -> bool:
        """Elimina un banco del registro."""
        if codigo not in self.bancos:
            print(f"[ERROR] Banco '{codigo}' no encontrado")
            return False
        
        nombre = self.bancos[codigo].nombre
        del self.bancos[codigo]
        self._guardar_config()
        print(f"[OK] Banco '{nombre}' eliminado")
        return True
    
    def desactivar_banco(self, codigo: str) -> bool:
        """Desactiva un banco (no se elimina, solo se deshabilita)."""
        return self.actualizar_banco(codigo, activo=False)
    
    def activar_banco(self, codigo: str) -> bool:
        """Activa un banco."""
        return self.actualizar_banco(codigo, activo=True)
    
    # ============================================================
    # CONSULTAS
    # ============================================================
    
    def obtener_banco(self, codigo: str) -> Optional[BancoConfig]:
        """Obtiene la configuración de un banco."""
        return self.bancos.get(codigo)
    
    def obtener_plantilla(self, codigo: str) -> Optional[str]:
        """
        Obtiene la ruta de la plantilla de un banco.
        
        Args:
            codigo: Código del banco
        
        Returns:
            Ruta a la plantilla o None si no existe
        """
        banco = self.bancos.get(codigo)
        if not banco:
            print(f"[ERROR] Banco '{codigo}' no registrado")
            return None
        
        if not banco.activo:
            print(f"[WARNING] Banco '{codigo}' está desactivado")
            return None
        
        # Verificar que la plantilla existe
        plantilla_path = Path(banco.plantilla)
        if not plantilla_path.exists():
            print(f"[ERROR] Plantilla no encontrada: {banco.plantilla}")
            return None
        
        return banco.plantilla
    
    def listar_bancos(self) -> List[BancoConfig]:
        """Lista todos los bancos registrados."""
        return list(self.bancos.values())
    
    def listar_bancos_activos(self) -> List[BancoConfig]:
        """Lista solo los bancos activos."""
        return [b for b in self.bancos.values() if b.activo]
    
    def buscar_banco(self, termino: str) -> List[BancoConfig]:
        """Busca bancos por nombre o código."""
        termino_lower = termino.lower()
        return [
            b for b in self.bancos.values()
            if termino_lower in b.nombre.lower() or termino_lower in b.codigo.lower()
        ]
    
    def existe_banco(self, codigo: str) -> bool:
        """Verifica si un banco está registrado."""
        return codigo in self.bancos


# ============================================================
# FUNCIONES DE CONVENIENCIA (API GLOBAL)
# ============================================================

# Instancia global por defecto
_registro_global: Optional[RegistroBancos] = None


def get_registro() -> RegistroBancos:
    """Obtiene la instancia global del registro."""
    global _registro_global
    if _registro_global is None:
        _registro_global = RegistroBancos()
    return _registro_global


def registrar_banco(codigo: str, nombre: str, plantilla: str, **kwargs) -> bool:
    """Registra un banco (función global)."""
    return get_registro().registrar_banco(codigo, nombre, plantilla, **kwargs)


def obtener_plantilla_banco(codigo: str) -> Optional[str]:
    """Obtiene la plantilla de un banco (función global)."""
    return get_registro().obtener_plantilla(codigo)


def listar_bancos() -> List[BancoConfig]:
    """Lista todos los bancos (función global)."""
    return get_registro().listar_bancos()


def procesar_plantilla_banco(codigo_banco: str, datos: Dict, 
                            filas_tabla: Dict = None, 
                            output_path: str = None) -> bool:
    """
    Procesa la plantilla de un banco específico.
    
    Args:
        codigo_banco: Código del banco registrado
        datos: Dict con datos para llenar (ej: {'empresa.nombre': 'Mi Empresa'})
        filas_tabla: Dict con datos tabulares
        output_path: Ruta de salida (si None, genera automáticamente)
    
    Returns:
        True si procesó correctamente
    """
    from tools.excel_template_processor import procesar_plantilla
    
    # Obtener plantilla del banco
    plantilla = obtener_plantilla_banco(codigo_banco)
    if not plantilla:
        return False
    
    # Generar nombre de salida si no se especifica
    if output_path is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = f"salida_{codigo_banco}_{timestamp}.xlsx"
    
    # Procesar
    print(f"[INFO] Procesando plantilla de {codigo_banco}...")
    print(f"       Plantilla: {plantilla}")
    print(f"       Salida: {output_path}")
    
    return procesar_plantilla(
        template_path=plantilla,
        datos=datos,
        output_path=output_path,
        filas_tabla=filas_tabla
    )


# ============================================================
# INICIALIZACIÓN CON BANCOS DE EJEMPLO
# ============================================================

def inicializar_bancos_ejemplo():
    """Inicializa el registro con bancos de ejemplo."""
    registro = get_registro()
    
    bancos_ejemplo = [
        {
            'codigo': 'nacion',
            'nombre': 'Banco de la Nación Argentina',
            'plantilla': 'plantillas/nacion.xlsx',
            'descripcion': 'Banco estatal argentino',
            'campos_extra': {
                'swift': 'NACNARBAXXX',
                'cba': '011'
            }
        },
        {
            'codigo': 'galicia',
            'nombre': 'Banco Galicia',
            'plantilla': 'plantillas/galicia.xlsx',
            'descripcion': 'Banco privado',
            'campos_extra': {
                'swift': 'BCRAARBAXXX',
                'cba': '007'
            }
        },
        {
            'codigo': 'santander',
            'nombre': 'Banco Santander Río',
            'plantilla': 'plantillas/santander.xlsx',
            'descripcion': 'Banco internacional',
            'campos_extra': {
                'swift': 'BSCHARBAXXX',
                'cba': '072'
            }
        },
        {
            'codigo': 'bbva',
            'nombre': 'BBVA Argentina',
            'plantilla': 'plantillas/bbva.xlsx',
            'descripcion': 'Banco español',
            'campos_extra': {
                'swift': 'BBVAARBAXXX',
                'cba': '014'
            }
        },
        {
            'codigo': 'provincia',
            'nombre': 'Banco Provincia',
            'plantilla': 'plantillas/provincia.xlsx',
            'descripcion': 'Banco provincial',
            'campos_extra': {
                'swift': 'BSPCRBAVXXX',
                'cba': '020'
            }
        }
    ]
    
    print("\n" + "="*60)
    print("INICIALIZANDO REGISTRO DE BANCOS")
    print("="*60 + "\n")
    
    for banco in bancos_ejemplo:
        if not registro.existe_banco(banco['codigo']):
            registro.registrar_banco(**banco)
        else:
            print(f"[SKIP] Banco '{banco['codigo']}' ya existe")
    
    print("\n" + "="*60)
    print(f"TOTAL: {len(registro.listar_bancos())} bancos registrados")
    print("="*60 + "\n")
    
    return registro


# ============================================================
# MAIN - DEMOSTRACIÓN
# ============================================================

if __name__ == "__main__":
    print("="*60)
    print("REGISTRO DE BANCOS - DEMOSTRACIÓN")
    print("="*60 + "\n")
    
    # Inicializar con ejemplos
    registro = inicializar_bancos_ejemplo()
    
    # Listar todos
    print("\n📋 BANCOS REGISTRADOS:")
    print("-"*60)
    for banco in registro.listar_bancos():
        estado = "✅" if banco.activo else "❌"
        print(f"  {estado} {banco.codigo:15} | {banco.nombre}")
        print(f"     Plantilla: {banco.plantilla}")
    
    # Buscar
    print("\n🔍 BUSCAR 'galicia':")
    print("-"*60)
    resultados = registro.buscar_banco('galicia')
    for banco in resultados:
        print(f"  Encontrado: {banco.nombre} ({banco.codigo})")
    
    # Obtener plantilla
    print("\n📂 OBTENER PLANTILLA 'nacion':")
    print("-"*60)
    plantilla = registro.obtener_plantilla('nacion')
    if plantilla:
        print(f"  Ruta: {plantilla}")
    
    print("\n" + "="*60)
    print("FIN DEMOSTRACIÓN")
    print("="*60)
