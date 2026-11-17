# Manual de MG Toolkit

**Herramientas de Limpieza y Optimización de Windows** · v1.0 · Creado por **Matthew Garay**

Funciona en **Windows 7, 8, 8.1, 10 y 11**.

---

## 1. Cómo usarlo

1. Haz doble clic en `MG Toolkit.bat` y pulsa **Sí** cuando Windows pida permiso.
2. Escribe el **número** de una opción y pulsa `ENTER`.
3. Al terminar, pulsa `ENTER` para volver al menú. Para salir escribe `0`.

Cuando el programa pregunta, responde:

| Escribe | Significa |
|---|---|
| `S` / `N` | Sí / No |
| `T` | Sí a **todo** lo que queda, sin volver a preguntar |
| `1,3,5` | Varios números de una lista |

> **Primera vez en un equipo:** activa el **modo simulación (39)**. Muestra lo que haría sin cambiar nada.

## 2. Qué opción usar

| Situación | Opciones |
|---|---|
| PC lenta | **3** para ver la causa, luego **1** (preguntando) o **2** (automático) |
| Mantenimiento de un cliente | **2**: lo hace todo solo (30 a 90 min) y entrega un informe |
| Antes de formatear | **23** archivos → **24** drivers → **37** claves WiFi → **50** clave de Windows → **51** lista de programas |
| Después de formatear | **24** drivers → **18** actualizaciones → **49** drivers faltantes → **20** programas → **9** apps basura |
| Virus | **21** (si alguno "no se pudo eliminar", usa el análisis sin conexión) |
| Publicidad o páginas que llevan a otro sitio | **21** → **45** → **46** → **47** |
| Internet lento | **43** para ver la causa → **44** si el DNS es lento |
| "Conexión no segura" en todas las páginas | **48** (hora incorrecta) |
| Sin internet | **43** → **28** y reinicia |
| Virus que no se deja borrar | **52** → modo seguro → **21** |
| Impresora trabada | **30** |
| Windows Update falla | **29** → reiniciar → **18** |
| Disco lleno | **4** → **8** → **7** |
| Pantallas azules | **3** → **25** → **26** → **33** |

## 3. Las opciones

**Hacer todo (terminan con un informe)**
- **1** Todo preguntando paso a paso · **2** Todo automático · **3** Solo revisar (no cambia nada)

**Limpieza**
- **4** Temporales y basura (solo archivos de más de 1 día)
- **5** Caché de navegadores (no borra contraseñas ni favoritos)
- **6** Vaciar la papelera
- **7** Hibernación (libera varios GB)
- **8** Buscar archivos grandes (solo muestra, no borra)
- **9** Quitar apps basura de fábrica (se pueden reinstalar desde la Tienda)

**Velocidad**
- **10** Máximo rendimiento
- **11** Liberar RAM
- **12** Programas de inicio (`D 3` desactiva el 3, `A 3` lo reactiva)
- **13** Qué programas consumen más
- **14** Servicios sin uso (`3 M` manual, `3 D` deshabilitar, `3 A` volver a automático)
- **15** Telemetría y anuncios
- **16** Medir velocidad del disco (LENTO = disco mecánico)
- **17** **Deshacer** los cambios de velocidad

**Actualizar e instalar**
- **18** Actualizaciones de Windows
- **19** Actualizar programas
- **20** Instalar programas básicos (Chrome, 7-Zip, VLC, AnyDesk…)
- **49** Actualizar drivers desde Windows Update (eliges cuáles; crea un punto de restauración antes)

**Red e internet**
- **43** Probar internet: router, pérdida de paquetes, DNS y velocidad de descarga, con el diagnóstico
- **44** Cambiar DNS a Cloudflare o Google, o volver a automático (no toca equipos con IP fija)
- **45** Programas conectados a internet (marca en amarillo los que están en carpetas sospechosas)
- **46** Revisar el archivo hosts y restaurarlo si un virus lo cambió (guarda una copia)
- **47** Quitar el proxy que pone la publicidad (adware)
- **48** Sincronizar la hora

**Seguridad y respaldo**
- **21** Buscar virus (rápido, completo o sin conexión)
- **22** Punto de restauración
- **23** Respaldar archivos a una USB (solo copia, nunca borra)
- **24** Respaldar o restaurar drivers

**Reparación**
- **25** Reparar archivos de Windows (DISM + SFC)
- **26** Revisar errores del disco (CHKDSK)
- **27** Optimizar el disco
- **28** Reparar internet (corta la conexión unos segundos; no borra una IP fija)
- **29** Reparar Windows Update
- **30** Destrabar la impresora
- **31** Reiniciar servicios trabados (audio, impresión, red)
- **32** Restablecer el firewall (borra las reglas de los programas)
- **33** Probar la memoria RAM (reinicia el equipo)

**Información:** **34** datos del equipo · **35** batería · **36** activación · **37** contraseñas WiFi · **50** clave de producto de Windows · **51** lista de programas instalados (se guarda en un archivo). Las claves y contraseñas solo se muestran en pantalla, nunca se guardan.

**Otros:** **38** mantenimiento semanal automático · **39** modo simulación · **40** carpeta de informes · **41** opciones avanzadas · **42** este manual · **52** reiniciar en modo seguro, BIOS u opciones avanzadas (y volver a normal) · **53** atajos a 22 herramientas de Windows (dispositivos, eventos, discos, servicios…)

> Si usas el **modo seguro (52)**, el equipo arrancará así cada vez hasta que vuelvas a normal con **52 → 3**. El menú muestra un aviso mientras esté activo.

## 4. El informe

Las opciones **1**, **2** y **3** terminan con un informe que se abre en el navegador y se guarda en `Escritorio\MG Toolkit - Informes`.

- **Puntuación de 0 a 100:** 90 o más = excelente · 75 a 89 = bueno · 50 a 74 = regular · menos de 50 = malo.
- **Lo que falta para tener Windows al 100%**, con la solución de cada problema.
- **Programas que faltan**, con cómo instalarlos.

Un disco mecánico (HDD), poca RAM o una batería gastada no se arreglan con ningún programa: el informe indica qué pieza cambiar.

## 5. Seguridad y cómo deshacer

**Lo que protege:**
- Crea un punto de restauración antes de los cambios grandes.
- Las acciones delicadas (red, firewall, reinicios) siempre preguntan, aunque elijas `T`.
- Nunca borra documentos ni fotos, ni desactiva el antivirus o las actualizaciones.
- Todo queda anotado en un registro (log) en la carpeta de informes.

**Cómo deshacer:**

| Cambio | Cómo deshacerlo |
|---|---|
| Velocidad, efectos visuales, telemetría | Opción **17** |
| Un programa de inicio | Opción **12** → `A número` |
| Un servicio | Opción **14** → `número A` |
| Cualquier otro cambio | `Win` + `R` → escribe `rstrui` → elige el punto **"MG Toolkit"** |

## 6. Windows 7 y 8

El programa detecta la versión de Windows y se adapta solo. En las versiones antiguas, algunas funciones no existen y el programa lo avisa:

| Función | Windows 7 | Windows 8 / 8.1 |
|---|---|---|
| Reparar Windows (opción 25) | Solo SFC (DISM no existe) | Completo |
| Optimizar disco (27) | Solo analiza, para no desgastar un SSD | Completo |
| Antivirus (21) | Usa Microsoft Security Essentials, si está instalado | Defender |
| Quitar apps basura (9) | No aplica (no hay Tienda) | Sí |
| Respaldar drivers (24) | No: descárgalos de la web del fabricante | Solo 8.1 |
| Actualizar e instalar programas (19, 20) | Muestra los enlaces de descarga | Muestra los enlaces de descarga |
| Reporte de batería y de WiFi | No | Sí |
| Entrar a la BIOS / opciones avanzadas (52) | No: pulsa F2, Supr o F8 al encender | Sí |
| Clave de producto en la BIOS (50) | No (se muestra la instalada) | Sí |

> **Windows 7 y 8 ya no reciben parches de seguridad.** El informe lo marca como problema crítico y recomienda pasar a Windows 11 si el equipo es compatible.

## 7. Mantenimiento semanal (opción 38)

Una vez por semana borra temporales y hace un análisis rápido de virus, sin cerrar programas ni reiniciar. Si el equipo está apagado a la hora programada, lo hace al encenderlo. Se desactiva con la misma opción.

## 8. Problemas comunes

- **"Windows protegió su PC":** pulsa **Más información** → **Ejecutar de todas formas**.
- **La ventana se cierra al abrir:** pulsaste "No" al pedir permisos. Ábrelo de nuevo y pulsa **Sí**.
- **Una tarea dice "aviso":** suele ser normal (un archivo en uso). El detalle está en el log (opción **40**).
- **No hay internet después de la opción 28:** reinicia el equipo.
- **La RAM se vuelve a llenar:** es normal, Windows la usa como caché. Si el equipo va lento, el informe dirá si falta RAM.
