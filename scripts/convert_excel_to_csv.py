#!/usr/bin/env python3
"""
Script de utilidad para convertir archivos Excel a CSV.
CSV es ~10x más rápido de cargar que Excel.

Uso:
    python scripts/convert_excel_to_csv.py
    python scripts/convert_excel_to_csv.py input_file.xlsx output_file.csv
"""

import pandas as pd
import os
import sys

WORKSPACE_ROOT = os.path.dirname(os.path.dirname(__file__))


def convert_excel_to_csv(excel_path: str, csv_path: str = None) -> bool:
    """
    Convierte un archivo Excel a CSV.

    Args:
        excel_path: Ruta al archivo Excel
        csv_path: Ruta de salida CSV (opcional, se genera automáticamente si no se provee)

    Returns:
        True si la conversión fue exitosa
    """
    try:
        # Generar nombre de archivo CSV si no se provee
        if csv_path is None:
            base = os.path.splitext(excel_path)[0]
            csv_path = f"{base}.csv"

        print(f"📖 Leyendo Excel: {excel_path}")
        df = pd.read_excel(excel_path, engine='openpyxl')

        print(f"✓ Leídos {len(df)} registros")
        print(f"💾 Guardando CSV: {csv_path}")

        df.to_csv(csv_path, index=False, encoding='utf-8')

        # Comparar tamaños de archivo
        excel_size = os.path.getsize(excel_path) / 1024  # KB
        csv_size = os.path.getsize(csv_path) / 1024  # KB

        print(f"\n✅ Conversión exitosa!")
        print(f"   Excel: {excel_size:.1f} KB")
        print(f"   CSV:   {csv_size:.1f} KB")
        print(f"   Reducción: {((excel_size - csv_size) / excel_size * 100):.1f}%")

        return True

    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def main():
    """Función principal."""
    if len(sys.argv) >= 2:
        # Modo con argumentos
        excel_path = sys.argv[1]
        csv_path = sys.argv[2] if len(sys.argv) >= 3 else None

        if not os.path.exists(excel_path):
            print(f"❌ Error: No existe el archivo {excel_path}")
            return

        convert_excel_to_csv(excel_path, csv_path)

    else:
        # Modo automático: convertir archivos por defecto
        print("🔄 Modo automático: Convirtiendo archivos de horarios...")
        print()

        # Buscar archivos Excel en output/
        output_dir = os.path.join(WORKSPACE_ROOT, 'output')

        if not os.path.exists(output_dir):
            print(f"❌ Error: No existe el directorio {output_dir}")
            return

        excel_files = [
            f for f in os.listdir(output_dir)
            if f.endswith(('.xlsx', '.xls'))
        ]

        if not excel_files:
            print(f"⚠ No se encontraron archivos Excel en {output_dir}")
            return

        print(f"📁 Encontrados {len(excel_files)} archivo(s) Excel:\n")

        for excel_file in excel_files:
            excel_path = os.path.join(output_dir, excel_file)
            csv_file = os.path.splitext(excel_file)[0] + '.csv'
            csv_path = os.path.join(output_dir, csv_file)

            print(f"➡️  {excel_file}")
            convert_excel_to_csv(excel_path, csv_path)
            print()

        print("✅ Conversión completa!")
        print("\n💡 Tip: Ahora puedes usar los archivos .csv en la aplicación")
        print("   para una carga ~10x más rápida.")


if __name__ == '__main__':
    main()
