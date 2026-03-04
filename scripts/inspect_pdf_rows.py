"""
inspect_pdf_rows.py - Dump all PDF table rows to understand EFE structure
"""
import pdfplumber, re, sys, io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

PDF = r'pdfs/matricula/2026-1/EFEs/Horarios-ofertados-en-matricula-2026-I_planes-antiguos.pdf'

with pdfplumber.open(PDF) as pdf:
    for i, page in enumerate(pdf.pages):
        tables = page.find_tables()
        print(f'\n=== PAGE {i+1} ({len(tables)} tables) ===')
        for j, tbl in enumerate(tables):
            rws = tbl.extract()
            print(f'  Table {j+1} ({len(rws)} rows):')
            for k, r in enumerate(rws):
                clean = [str(c).replace('\n',' ') if c else '' for c in r]
                # only print the first 8 cells to keep concise
                print(f'    [{k:03d}]', clean[:9])
