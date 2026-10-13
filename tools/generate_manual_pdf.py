#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generate_manual_pdf.py
Genera Manual_PlantillasValidadoras4GL.pdf desde MANUAL_USO.md
con diseno profesional: portada, indice, encabezados, tablas, codigo.
Requiere: pip install fpdf2 markdown
Uso: py tools/generate_manual_pdf.py
"""
import os
import re
import sys
from pathlib import Path

try:
    from fpdf import FPDF
except ImportError:
    print("Falta fpdf2: py -m pip install fpdf2")
    sys.exit(1)

BASE = Path(__file__).resolve().parent.parent
MD_PATH = BASE / "MANUAL_USO.md"
PDF_PATH = BASE / "docs" / "Manual_PlantillasValidadoras4GL.pdf"

AZUL = (0, 51, 102)
AZUL_CLARO = (232, 240, 254)
GRIS = (102, 102, 102)
ROJO = (204, 0, 0)
NEGRO = (0, 0, 0)
BLANCO = (255, 255, 255)


FONT = "ArialU"
REG = r"C:\Windows\Fonts\arial.ttf"
BOLD = r"C:\Windows\Fonts\arialbd.ttf"
ITAL = r"C:\Windows\Fonts\ariali.ttf"
BI = r"C:\Windows\Fonts\arialbi.ttf"


class ManualPDF(FPDF):
    def __init__(self):
        super().__init__(orientation="P", unit="mm", format="A4")
        self.set_auto_page_break(True, margin=20)
        self.toc = []  # (nivel, titulo, pagina)
        self.add_font(FONT, "", REG, uni=True)
        self.add_font(FONT, "B", BOLD, uni=True)
        self.add_font(FONT, "I", ITAL, uni=True)
        self.add_font(FONT, "BI", BI, uni=True)

    def header(self):
        if self.page_no() == 1:
            return
        self.set_font(FONT, "I", 8)
        self.set_text_color(*GRIS)
        self.cell(0, 6, "PlantillasValidadoras4GL - Manual de Uso", align="L")
        self.cell(0, 6, f"Pag. {self.page_no()}", align="R", new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(*AZUL)
        self.set_line_width(0.4)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(3)

    def footer(self):
        if self.page_no() == 1:
            return
        self.set_y(-15)
        self.set_font(FONT, "", 8)
        self.set_text_color(*GRIS)
        self.cell(0, 10, "PlantillasValidadoras4GL v2.0 - Informix 14.10 / Genero BDL", align="C")

    def _linea_centrada(self, texto, h=8):
        self.set_x(10)
        self.cell(190, h, texto, align="C", new_x="LMARGIN", new_y="NEXT")

    def portada(self):
        from datetime import date
        self.add_page()
        self.set_fill_color(*AZUL)
        self.rect(0, 0, 210, 130, "F")
        self.set_y(38)
        self.set_font(FONT, "B", 24)
        self.set_text_color(*BLANCO)
        self._linea_centrada("PlantillasValidadoras4GL", 12)
        self.set_font(FONT, "", 15)
        self._linea_centrada("Manual de Uso del Programa", 10)
        self.set_font(FONT, "", 11)
        self.set_text_color(200, 220, 255)
        self._linea_centrada("Validacion de plantillas Excel con Genero 4GL e Informix 14.10", 8)
        self.ln(8)
        self.set_font(FONT, "", 11)
        self.set_text_color(*BLANCO)
        self._linea_centrada("Parte 1: Sin Python (100% Genero 4GL - SpreadsheetML)", 7)
        self._linea_centrada("Parte 2: Con Python (archivos .xlsx nativos)", 7)
        self.set_y(140)
        self.set_font(FONT, "", 10)
        self.set_text_color(*GRIS)
        self._linea_centrada(f"Version 2.0 - {date.today().strftime('%d/%m/%Y')}", 7)
        self._linea_centrada("Compatibilidad: Genero BDL 1.x / 2.x / 3.x / 4.x", 7)

    def titulo1(self, texto):
        self.ln(4)
        self.set_font(FONT, "B", 16)
        self.set_text_color(*AZUL)
        self.multi_cell(0, 9, texto)
        self.set_draw_color(*AZUL)
        self.set_line_width(0.7)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(3)
        self.toc.append((1, texto, self.page_no()))

    def titulo2(self, texto):
        self.ln(2)
        self.set_font(FONT, "B", 13)
        self.set_text_color(0, 64, 128)
        self.multi_cell(0, 8, texto)
        self.ln(1)
        self.toc.append((2, texto, self.page_no()))

    def titulo3(self, texto):
        self.set_font(FONT, "B", 11)
        self.set_text_color(*NEGRO)
        self.multi_cell(0, 7, texto)
        self.ln(1)

    def parrafo(self, texto):
        self.set_font(FONT, "", 10)
        self.set_text_color(*NEGRO)
        self.multi_cell(0, 5.5, texto)
        self.ln(1)

    def viñeta(self, texto):
        self.set_font(FONT, "", 10)
        self.set_text_color(*NEGRO)
        x = self.get_x()
        self.cell(6, 5.5, chr(8226))
        self.multi_cell(0, 5.5, texto)
        self.ln(0.5)

    def codigo(self, lineas):
        self.set_fill_color(245, 245, 245)
        self.set_draw_color(200, 200, 200)
        self.set_font(FONT, "", 8)
        self.set_text_color(30, 30, 30)
        for ln in lineas:
            if self.get_y() > 265:
                self.add_page()
            self.cell(0, 4.5, "  " + ln[:110], new_x="LMARGIN", new_y="NEXT", fill=True)
        self.ln(2)

    def tabla(self, filas):
        if not filas:
            return
        ncols = max(len(f) for f in filas)
        ancho = (190) / ncols
        # encabezado
        self.set_font(FONT, "B", 9)
        self.set_fill_color(*AZUL)
        self.set_text_color(*BLANCO)
        for c in filas[0]:
            self.cell(ancho, 7, c[:int(ancho / 1.8)], border=1, fill=True)
        self.ln()
        # datos
        self.set_font(FONT, "", 9)
        self.set_text_color(*NEGRO)
        for i, f in enumerate(filas[1:]):
            if self.get_y() > 265:
                self.add_page()
            fill = (i % 2 == 0)
            if fill:
                self.set_fill_color(*AZUL_CLARO)
            for c in f:
                self.cell(ancho, 6, c[:int(ancho / 1.8)], border=1, fill=fill)
            self.ln()
        self.ln(3)


def limpiar_md(texto):
    texto = texto.replace("**", "")
    texto = texto.replace("`", "")
    return texto.strip()


def parsear_y_generar(md_texto, pdf):
    lineas = md_texto.split("\n")
    i = 0
    # saltar titulo principal (ya esta en portada)
    while i < len(lineas) and not lineas[i].startswith("# "):
        i += 1
    if i < len(lineas):
        i += 1
    bloque_codigo = None
    tabla_actual = None

    def volcar_tabla():
        nonlocal tabla_actual
        if tabla_actual:
            pdf.tabla(tabla_actual)
            tabla_actual = None

    while i < len(lineas):
        ln = lineas[i]
        rst = ln.rstrip()

        if rst.strip().startswith("```"):
            if bloque_codigo is None:
                bloque_codigo = []
                volcar_tabla()
            else:
                pdf.codigo(bloque_codigo)
                bloque_codigo = None
            i += 1
            continue
        if bloque_codigo is not None:
            bloque_codigo.append(rst)
            i += 1
            continue
        if rst.startswith("# "):
            volcar_tabla()
            pdf.titulo1(limpiar_md(rst[2:]))
        elif rst.startswith("## "):
            volcar_tabla()
            pdf.titulo2(limpiar_md(rst[3:]))
        elif rst.startswith("### "):
            volcar_tabla()
            pdf.titulo3(limpiar_md(rst[4:]))
        elif rst.strip().startswith("|") and "|" in rst.strip()[1:]:
            celdas = [limpiar_md(c) for c in rst.strip().strip("|").split("|")]
            if all(set(c) <= set("-: ") and c for c in celdas):
                i += 1
                continue  # fila separadora
            if tabla_actual is None:
                tabla_actual = []
            tabla_actual.append(celdas)
        elif rst.strip().startswith("- [ ]") or rst.strip().startswith("- [x]"):
            volcar_tabla()
            pdf.viñeta("[ ] " + limpiar_md(rst.strip()[5:]))
        elif rst.strip().startswith("- ") or rst.strip().startswith("* "):
            volcar_tabla()
            pdf.viñeta(limpiar_md(rst.strip()[2:]))
        elif re.match(r"^\d+\.\s", rst.strip()):
            volcar_tabla()
            pdf.viñeta(limpiar_md(re.sub(r"^\d+\.\s", "", rst.strip())))
        elif rst.strip() == "" or rst.strip() == "---":
            volcar_tabla()
        else:
            volcar_tabla()
            pdf.parrafo(limpiar_md(rst))
        i += 1
    volcar_tabla()


def main():
    if not MD_PATH.exists():
        print(f"No existe {MD_PATH}")
        sys.exit(1)
    md = MD_PATH.read_text(encoding="utf-8")
    pdf = ManualPDF()
    pdf.set_title("Manual de Uso - PlantillasValidadoras4GL")
    pdf.set_author("PlantillasValidadoras4GL")
    pdf.portada()
    parsear_y_generar(md, pdf)
    PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(PDF_PATH))
    print(f"OK: {PDF_PATH} ({PDF_PATH.stat().st_size} bytes, {pdf.pages_count} pags)")


if __name__ == "__main__":
    main()
