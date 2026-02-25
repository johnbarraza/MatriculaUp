# Desktop Framework Analysis para MatriculaUp

Dado que nuestro objetivo ha cambiado de "una aplicación Python completa" a "un visualizador interactivo de horarios a partir de un JSON", tenemos varias opciones modernas para crear ejecutables de escritorio ligeros y con UI/UX de primer nivel.

Aquí te presento un análisis comparativo de las **3 mejores opciones** para nuestro caso de uso.

## 1. Tauri (Recomendación Principal ⭐)

Tauri utiliza el lenguaje Web (HTML/CSS/JS o React/Vue) para la UI de manera nativa utilizando el motor de renderizado web que el sistema operativo ya trae instalado (WebView2 en Windows), y Rust solo para comunicarse con el sistema (si fuera necesario).

- **Ventajas para nosotros:**
  - **Peso Mínimo:** Los ejecutables suelen pesar entre 5MB y 15MB.
  - **UI/UX Infinito:** Al usar CSS y React (o Svelte/Vue), puedes diseñar una grilla interactiva estilo "drag and drop", usar paletas de colores modernas (Tailwind) y animaciones fluidas con mínimo esfuerzo.
  - **Familiaridad:** Si tienes experiencia web, el desarrollo te será muy natural y rapidísimo (hay miles de componentes de calendario/horarios open source).
  - **Ecosistema JS:** Podemos usar librerías avanzadas para procesar los cruces de horario.
- **Desventajas:**
  - Para interactuar con el sistema (leer archivos, guardar configuraciones) debes usar la API de Rust, aunque Tauri lo abstrae muy bien.
  - El usuario debe tener WebView2 (que Windows 10/11 ya tiene instalado por defecto en el 99% de las computadoras).

## 2. Flutter

Flutter es el framework de Google. Usa el lenguaje **Dart** y dibuja *todo* desde cero en un canvas utilizando su propio motor de renderizado (Skia o Impeller). Funciona para móvil, web y escritorio.

- **Ventajas para nosotros:**
  - **UI Nativa y Hermosa por Defecto:** Flutter es famosa por las animaciones y lo fácil que es hacer interfaces hermosas de manera rápida gracias a Material Design o Cupertino.
  - **Rendimiento:** Compila directo a máquina, por lo que es ultra fluido (120 fps sin sudar) al arrastrar componentes en la grilla del horario.
  - **Single Codebase:** El mismo código que uses para Windows puede ser compilado fácilmente en 1 click para hacer una App en Android/iOS para los estudiantes.
- **Desventajas:**
  - **Peso del Ejecutable:** Más pesado que Tauri (alrededor de 20-30MB en desktop) porque empaqueta su propio motor de renderizado.
  - **Curva de Aprendizaje:** Requiere aprender Dart y el modelo de "Widgets", que es diferente al desarrollo tradicional.
  - **Componentes de grilla complejos:** Dibujar una grilla de calendario no es tan directo como en CSS/Grid, puedes necesitar plugins complejos.

## 3. Electron

Electron es "el papá" de Tauri. Toma la UI en web (React/Vue/JS) y en lugar de usar el motor del sistema, empaqueta el navegador Google Chrome (Chromium) entero junto con un backend ligero de Node.js adentro del ejecutable. Fue usado para construir VS Code, Discord y Slack.

- **Ventajas para nosotros:**
  - **Facilidad de Desarrollo:** Todo está en JavaScript.
  - **Estabilidad Absoluta:** Como tú envías tu propio navegador Chromium dentro de la app, te aseguras que se vea *idéntico* en todas las PCs del mundo.
- **Desventajas:**
  - **Peso del Ejecutable Monstruoso:** Empaquetar todo el entorno la vuelve extremadamente pesada (nuestra app pesaría mínimo 120-150MB solo por tener Electron vacío y gastaría casi 200MB de RAM solo por existir). Esto es exactamente lo que estamos tratando de evitar. (DESCARTADO)

---

## Conclusión y Veredicto

**Para la v1.1, la decisión está entre Tauri y Flutter.**

### Escoge Tauri si:
Quieres usar **React** o **Tailwind CSS**. CSS Grid hace que dibujar "horarios semanales" a medida sea absurdamente fácil (como tablas HTML con vitaminas). El peso final será menor a 10MB y la UI se sentirá de otro planeta comparada con PySide6.

### Escoge Flutter si:
Te interesa que en una próxima "Fase 7" los estudiantes puedan descargar MatriculaUp como **Aplicación Móvil** (Apk de Android) para armar su horario en el celular. Flutter en escritorio funciona bien, pero su punto fuerte es compilar a móvil.

¿Te irías por el ecosistema Web (React+Tauri) o te llama más la atención la idea Multiplataforma Completa (Flutter+Dart)?
