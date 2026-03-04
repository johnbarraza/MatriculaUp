import json, pathlib

data = json.loads(pathlib.Path('pdfs/matricula/2026-1/EFEs/efe_ssu_2026-1_v1.json').read_text('utf-8'))

print('=== METADATOS ===')
for k, v in data['metadata'].items():
    print(f'  {k}: {v}')

print()
print(f'=== CURSOS ({len(data["cursos"])} total) ===')

clase_count = ssu_count = 0
ssu_without_excel = []

for c in data['cursos']:
    secciones = c['secciones']
    tipo_efe  = c.get('tipo_efe', '')
    print(f"\n[{c['codigo']}] {c['nombre'][:50]}")
    print(f"  tipo_efe: {tipo_efe[:40]}")
    print(f"  secciones: {len(secciones)}")

    for s in secciones:
        ts = s.get('tipo_sesion', '?')
        if ts == 'CLASE':
            clase_count += 1
            sesiones = s.get('sesiones', [])
            dias_str = ', '.join(x['dia'] + ' ' + x['hora_inicio'] + '-' + x['hora_fin'] for x in sesiones)
            print(f"  Secc {s['seccion']}: CLASE | cupos={s['cupos']} | {dias_str}")
        else:
            ssu_count += 1
            ndias = len(s.get('sesiones_por_dia', []))
            print(f"  Secc {s['seccion']}: INICIO_FIN | {s.get('fecha_inicio')} → {s.get('fecha_fin')} | cupos={s['cupos']} | dias_excel={ndias}")
            if ndias == 0:
                ssu_without_excel.append((c['codigo'], s['seccion']))
            else:
                # Show first day preview
                first_day = s['sesiones_por_dia'][0]
                print(f"    Primer dia: {first_day['fecha']} ({first_day['dia']})")
                for ses in first_day['sesiones']:
                    print(f"      {ses['tipo']}: {ses['hora_inicio']} - {ses['hora_fin']}")

print()
print(f'=== RESUMEN ===')
print(f'  Secciones CLASE:     {clase_count}')
print(f'  Secciones INICIO_FIN:{ssu_count}')
if ssu_without_excel:
    print(f'  SSU sin datos Excel: {ssu_without_excel}')
else:
    print(f'  Todos los SSU tienen datos del Excel.')
