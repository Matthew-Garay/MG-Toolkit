# Manual de MG Toolkit

**Herramientas de Limpieza y Optimización de Windows** · Versión 1.0 · Creado por **Matthew Garay**

Manual de uso para Windows 10 y Windows 11.

## Contenido

1. [Qué es MG Toolkit](#1-qué-es-mg-toolkit)
2. [Antes de empezar](#2-antes-de-empezar)
3. [Cómo abrirlo y usar el menú](#3-cómo-abrirlo-y-usar-el-menú)
4. [Qué opción usar en cada caso](#4-qué-opción-usar-en-cada-caso)
5. [Todas las opciones, una por una](#5-todas-las-opciones-una-por-una)
6. [Cómo leer el informe](#6-cómo-leer-el-informe)
7. [Seguridad: qué protege y cómo deshacer](#7-seguridad-qué-protege-y-cómo-deshacer)
8. [Mantenimiento automático semanal](#8-mantenimiento-automático-semanal)
9. [Archivos que crea](#9-archivos-que-crea)
10. [Problemas y preguntas frecuentes](#10-problemas-y-preguntas-frecuentes)

---

## 1. Qué es MG Toolkit

MG Toolkit es un programa de consola (ventana negra con menú) que reúne en un solo archivo las tareas de mantenimiento de un técnico de soporte: limpiar, acelerar, reparar Windows, buscar virus, respaldar, instalar programas y revisar el equipo.

Al final de las opciones grandes genera un **informe con una puntuación de 0 a 100** que explica qué le falta a Windows para estar al 100% y cómo arreglarlo.

> **Importante:** MG Toolkit usa solo herramientas que ya vienen dentro de Windows (DISM, SFC, CHKDSK, Defender, robocopy, pnputil, winget). No descarga programas raros ni modifica archivos internos de Windows.

## 2. Antes de empezar

- **Sistema:** Windows 10 u 11.
- **Permisos:** necesita una cuenta de **administrador**. El programa los pide solo al abrirse.
- **Internet:** solo hace falta para actualizar Windows, actualizar o instalar programas y actualizar el antivirus. Lo demás funciona sin conexión.
- **Para llevarlo en una USB:** copia juntos `MG Toolkit.bat` y `MANUAL.md`.
- **Recomendación:** antes de cambios grandes, crea un **punto de restauración** (opción 22). Las opciones 1 y 2 lo crean solas.

## 3. Cómo abrirlo y usar el menú

1. Haz **doble clic** en `MG Toolkit.bat`.
2. Windows pregunta *"¿Quieres permitir que esta aplicación haga cambios?"*: pulsa **Sí**.
3. Aparece el menú en dos columnas. **Escribe el número** de la opción y pulsa `ENTER`.
4. Al terminar cada tarea verás un resumen. Pulsa `ENTER` para volver al menú.
5. Para salir escribe `0`.

### Cómo responder las preguntas

| Escribe | Significa |
|---|---|
| `S` | Sí, hazlo. |
| `N` | No, sáltalo. |
| `T` | **Sí a todo**: hace este paso y todos los que quedan sin volver a preguntar. Solo aparece en las preguntas normales. |
| `1,3,5` | En las listas puedes elegir varios números separados por coma. |

> Si pulsas `ENTER` sin escribir nada en una pregunta S/N, el programa vuelve a preguntar. Nunca toma una decisión por accidente.

### Modo simulación (opción 39)

Con el modo simulación **ENCENDIDO**, el programa muestra todo lo que haría (qué archivos borraría, cuánto espacio liberaría, qué comandos ejecutaría) **sin cambiar nada**. Úsalo la primera vez en un equipo nuevo para ver qué va a pasar. Aparece una franja amarilla arriba mientras está activo.

También se puede abrir directamente en simulación desde una consola:

```bat
"MG Toolkit.bat" --dry-run
```

## 4. Qué opción usar en cada caso

| Situación | Qué hacer |
|---|---|
| **La PC está lenta** | **3** (solo revisar) para ver la causa → **1** (todo preguntando) o **2** (todo automático). Si el informe dice "disco mecánico (HDD)" o "poca RAM", la solución es de hardware: cambiar a SSD o ampliar RAM. |
| **Mantenimiento general de un cliente** | **2** (todo automático). Tarda de 30 a 90 minutos. Al final se abre el informe para entregarlo o imprimirlo. |
| **Antes de formatear** | **23** respaldar archivos (a una USB) → **24** respaldar drivers → **37** anotar contraseñas WiFi → **34** información del equipo (número de serie). |
| **Después de formatear** | **24** restaurar drivers → **18** actualizaciones de Windows → **20** programas básicos → **9** quitar apps basura → **3** informe final. |
| **Sospecha de virus** | **21** buscar virus → análisis completo. Si alguna amenaza dice "NO SE PUDO ELIMINAR", usa el análisis sin conexión (opción 3 dentro de la 21). |
| **No hay internet o las páginas no cargan** | **28** reparar internet / red, y después reinicia el equipo. |
| **La impresora no imprime** | **30** destrabar la impresora. |
| **Windows Update da error o no avanza** | **29** reparar Windows Update → reiniciar → **18** actualizaciones de Windows. |
| **El disco está lleno** | **4** temporales y basura → **8** buscar archivos grandes → **7** hibernación (libera varios GB). |
| **Pantallas azules o reinicios solos** | **3** informe (muestra cuántas hubo) → **25** reparar archivos de Windows → **26** revisar disco → **33** probar la memoria RAM. |

## 5. Todas las opciones, una por una

Columna **¿Cambia algo?**:
- 🟢 **Solo mira:** no modifica nada.
- 🟡 **Cambia:** modifica el equipo de forma segura.
- 🔴 **Pregunta siempre:** acción delicada que siempre pide confirmación.

### Hacer todo (con informe al final)

| # | Opción | Qué hace | ¿Cambia algo? |
|---|---|---|---|
| 1 | Todo PREGUNTANDO | Recorre 32 pasos (análisis, punto de restauración, virus, limpieza, RAM, rendimiento, reparación, actualizaciones) y pregunta antes de cada uno: S, N o T. Termina con el informe y ofrece instalar lo que falta. | 🟡 Cambia |
| 2 | Todo AUTOMÁTICO | Hace lo mismo sin preguntar, usando siempre la opción segura: no cierra navegadores ni programas del usuario, no toca la red ni el firewall, y solo programa CHKDSK si encontró errores. 30-90 minutos. | 🟡 Cambia |
| 3 | Solo revisar y ver el informe | Revisa Windows, seguridad, hardware, drivers, estabilidad, internet y programas esenciales, y muestra el informe. Ideal para ver cómo llega un equipo. | 🟢 Solo mira |

### Limpieza

| # | Opción | Qué hace | ¿Cambia algo? |
|---|---|---|---|
| 4 | Borrar temporales y basura | Temporales con más de 1 día, caché de Windows Update, volcados de memoria, reportes de error, caché de la Tienda, miniaturas, DNS y componentes viejos de Windows. El Explorador se reinicia un momento. | 🟡 Cambia |
| 5 | Borrar caché de navegadores | Chrome, Edge, Firefox, Opera y Brave. **No borra** contraseñas, favoritos, historial ni sesiones. Si un navegador está abierto, pregunta antes de cerrarlo. | 🟡 Cambia |
| 6 | Vaciar la papelera | Vacía la papelera de todas las unidades y de todos los usuarios. **Lo borrado no se puede recuperar.** | 🟡 Cambia |
| 7 | Liberar espacio (hibernación) | Muestra cuánto ocupa `hiberfil.sys` y permite desactivarlo, reducirlo (mantiene el inicio rápido) o activarlo de nuevo. | 🟡 Cambia |
| 8 | Buscar archivos grandes | Lista las carpetas que más ocupan y los archivos de más de 250 MB. Escribiendo el número de un archivo se abre su carpeta. **No borra nada.** | 🟢 Solo mira |
| 9 | Quitar apps basura de fábrica | Muestra las apps innecesarias instaladas (Candy Crush, Noticias, Solitaire, Skype, etc.) y quita las que elijas. **Nunca** toca la Tienda, la Calculadora, Fotos, el Paint clásico, el Bloc de notas ni la Configuración. Todas se pueden reinstalar gratis desde la Microsoft Store. | 🟡 Cambia |

### Velocidad

| # | Opción | Qué hace | ¿Cambia algo? |
|---|---|---|---|
| 10 | Poner en máximo rendimiento | Plan de energía "Máximo rendimiento", procesador al 100% cuando está enchufado, menos efectos visuales y Modo Juego. Se deshace con la opción 17. | 🟡 Cambia |
| 11 | Liberar memoria RAM | Cierra procesos de fondo innecesarios (pregunta antes), limpia el portapapeles y libera memoria. El efecto es temporal: Windows vuelve a usar la RAM como caché, y eso es normal. | 🟡 Cambia |
| 12 | Programas que arrancan con Windows | Lista los programas y las tareas de inicio. Comandos: `D 3` desactiva el 3, `A 3` lo vuelve a activar, `V 3` muestra el comando. Es lo mismo que hace el Administrador de tareas: no borra nada. | 🟡 Cambia |
| 13 | Ver qué programas consumen más | Los 12 programas que más RAM usan y alerta si alguno pasa del 20%. Permite subirle la prioridad a un programa abierto. | 🟢 Solo mira |
| 14 | Desactivar servicios sin uso | Lista servicios opcionales (Xbox, Fax, Mapas, indexado, etc.) con su estado. `3 M` = manual (recomendado si dudas), `3 D` = deshabilitar, `3 A` = automático (volver atrás). | 🟡 Cambia |
| 15 | Desactivar telemetría y anuncios | Detiene el envío de datos de diagnóstico, las sugerencias, los anuncios del menú Inicio y Cortana. Se deshace con la opción 17. | 🟡 Cambia |
| 16 | Medir velocidad del disco | Prueba de 1-2 minutos con la herramienta de Windows. Dice si el disco es **LENTO** (mecánico), **BUENO** (SSD) o **EXCELENTE** (SSD NVMe). Sirve para mostrarle al cliente la mejora al cambiar a SSD. | 🟢 Solo mira |
| 17 | Deshacer cambios de velocidad | Vuelve al plan Equilibrado y restaura los efectos visuales, las apps en segundo plano, la telemetría y la programación de GPU. | 🟡 Cambia |

### Actualizar e instalar

| # | Opción | Qué hace | ¿Cambia algo? |
|---|---|---|---|
| 18 | Instalar actualizaciones de Windows | Busca, descarga e instala las actualizaciones de seguridad y calidad. **No** instala cambios de versión (por ejemplo, de Windows 10 a 11). | 🟡 Cambia |
| 19 | Actualizar todos los programas | Actualiza con winget los programas que tengan versión nueva. Puede cerrar un programa mientras lo actualiza. | 🟡 Cambia |
| 20 | Instalar programas básicos | Muestra 12 programas útiles (Chrome, Firefox, 7-Zip, VLC, Acrobat Reader, LibreOffice, AnyDesk, TeamViewer, Zoom, Notepad++, Visual C++, WebView2) indicando cuáles ya están instalados. Elige números o `F` para instalar todos los que faltan. Descarga las versiones oficiales. | 🟡 Cambia |

### Seguridad y respaldo

| # | Opción | Qué hace | ¿Cambia algo? |
|---|---|---|---|
| 21 | Buscar virus (Defender) | Actualiza el antivirus y ofrece: **1** análisis rápido (5-15 min), **2** completo (1-3 horas), **3** sin conexión (reinicia el equipo, para virus que no se dejan borrar) y **4** ver amenazas de los últimos 90 días. Si el equipo usa otro antivirus, avisa y no hace nada. | 🟡 Cambia |
| 22 | Crear punto de restauración | Guarda una copia del estado de Windows para volver atrás si algo sale mal. | 🟡 Cambia |
| 23 | Respaldar archivos del usuario | Eliges el usuario y el destino (USB u otro disco). Copia Escritorio, Documentos, Imágenes, Música, Videos, Descargas, las carpetas de OneDrive y los favoritos de los navegadores. Antes calcula el tamaño y revisa que quepa. **Solo copia: nunca borra ni mueve nada.** Deja un `LEEME.txt` con instrucciones para restaurar. | 🟢 Solo copia |
| 24 | Respaldar / restaurar drivers | **1** Respaldar: copia todos los drivers instalados a una carpeta (hazlo antes de formatear). **2** Restaurar: los instala desde esa carpeta. Usa la restauración solo en el **mismo modelo** de equipo. | 🟡 Cambia |

### Reparación

| # | Opción | Qué hace | ¿Cambia algo? |
|---|---|---|---|
| 25 | Reparar archivos de Windows | DISM (repara la imagen de Windows, 10-30 min, necesita internet) y luego SFC (repara archivos del sistema). Son las herramientas oficiales de Microsoft. | 🟡 Cambia |
| 26 | Revisar errores del disco | Escaneo de CHKDSK sin reiniciar. Si encuentra errores, ofrece programar la reparación completa en el próximo reinicio. Esa reparación puede tardar horas: **no apagues** el equipo mientras corre. | 🟡 Cambia |
| 27 | Optimizar el disco | Desfragmenta los discos mecánicos y hace TRIM en los SSD. Windows elige lo correcto para cada tipo de disco. | 🟡 Cambia |
| 28 | Reparar internet / red | Limpia DNS, ARP y NetBIOS, reinicia Winsock y TCP/IP y renueva la IP. **Corta la conexión unos segundos**: si estás por AnyDesk o TeamViewer, se desconectará. Si el equipo tiene **IP fija**, la guarda en un archivo y no la borra. | 🔴 Pregunta siempre |
| 29 | Reparar Windows Update | Procedimiento oficial de Microsoft: detiene Update, **renombra** (no borra) sus carpetas de caché y lo vuelve a iniciar. El historial de actualizaciones puede aparecer vacío, pero las actualizaciones siguen instaladas. | 🟡 Cambia |
| 30 | Destrabar la impresora | Detiene la cola de impresión, borra los documentos atascados y la vuelve a iniciar. Muestra las impresoras instaladas. | 🟡 Cambia |
| 31 | Reiniciar servicios trabados | Reinicia los servicios de impresión, Windows Update, red, WiFi, audio y temas. Útil cuando "no suena", "no imprime" o "no se conecta". | 🟡 Cambia |
| 32 | Restablecer el firewall | Vuelve el firewall a valores de fábrica. **Borra las reglas de los programas** (sistemas de facturación, impresoras de red, juegos). Úsalo solo si el firewall está dañado. | 🔴 Pregunta siempre |
| 33 | Probar la memoria RAM | Abre el Diagnóstico de memoria de Windows, que **reinicia el equipo** y prueba la RAM. El resultado aparece al volver a Windows. | 🔴 Reinicia |

### Información

| # | Opción | Qué hace | ¿Cambia algo? |
|---|---|---|---|
| 34 | Información del equipo | Marca, modelo, número de serie, procesador, RAM (módulos y ranuras), tarjeta gráfica, salud y desgaste de los discos, y espacio libre. | 🟢 Solo mira |
| 35 | Reporte de batería | Porcentaje de salud de la batería y reporte completo de Windows (solo portátiles). | 🟢 Solo mira |
| 36 | Ver si Windows está activado | Estado de la licencia y clave parcial. | 🟢 Solo mira |
| 37 | Contraseñas y reporte de WiFi | Muestra las redes WiFi guardadas con su contraseña (útil antes de formatear) y genera el reporte de problemas WiFi de Windows. Las contraseñas **solo se muestran en pantalla**: no se guardan en ningún archivo. | 🟢 Solo mira |

### Otros

| # | Opción | Qué hace |
|---|---|---|
| 38 | Mantenimiento automático semanal | Ver la [sección 8](#8-mantenimiento-automático-semanal). |
| 39 | Modo simulación | Enciende o apaga el modo "ver sin cambiar nada". |
| 40 | Abrir carpeta de informes | Abre la carpeta del Escritorio con los informes y registros. |
| 41 | Opciones avanzadas | Las 38 tareas por separado (Prefetch, registros de eventos, archivo de paginación, temporizador, etc.), para técnicos que quieren elegir una por una. |
| 42 | Ver el manual | Abre este manual (debe estar en la misma carpeta que `MG Toolkit.bat`). |

## 6. Cómo leer el informe

Las opciones 1, 2 y 3 terminan con un informe que aparece en la consola y se abre en el navegador. Se guarda en `Escritorio\MG Toolkit - Informes` y se puede imprimir o enviar al cliente.

| Puntuación | Significado |
|---|---|
| **90 – 100** | Excelente: Windows está en buen estado. |
| **75 – 89** | Bueno: algunos detalles por mejorar. |
| **50 – 74** | Regular: hay problemas que conviene atender. |
| **0 – 49** | Malo: problemas importantes (hardware, seguridad o estabilidad). |

Cada problema **CRITICO** resta 12 puntos y cada **ATENCION** resta 4. Los **OK** e **INFO** no restan.

Secciones del informe:

- **Lo que se hizo:** espacio liberado, RAM, actualizaciones instaladas y duración.
- **Lo que falta para tener Windows al 100%:** cada problema con su solución, ordenado de más a menos grave.
- **Herramientas y programas que faltan:** con el comando exacto para instalarlos. Al terminar, el programa ofrece instalarlos.
- **Diagnóstico completo:** todo lo revisado, incluido lo que está bien.
- **Datos del equipo:** modelo, serie, procesador, RAM, etc.

> ⚠️ Algunas cosas no se arreglan con ningún programa: un **disco mecánico (HDD)**, **poca RAM**, un **disco que está fallando** o una **batería gastada** se resuelven cambiando la pieza. El informe lo indica claramente.

## 7. Seguridad: qué protege y cómo deshacer

### Protecciones incluidas

- **Punto de restauración** automático al inicio de las opciones 1 y 2.
- **Modo simulación** para ver todo antes de hacerlo.
- Los temporales solo se borran si tienen **más de 1 día**, para no romper instalaciones o programas abiertos. Los archivos en uso se saltan.
- **Acciones delicadas siempre preguntan**, aunque se haya elegido "sí a todo": reparar la red, el firewall, Prefetch, el registro de seguridad, el análisis sin conexión y reiniciar.
- La reparación de red **detecta la IP fija**, la guarda en un archivo y no la borra.
- El respaldo de archivos **solo copia**, revisa el espacio antes y no permite guardar el respaldo dentro del mismo usuario.
- Reparar Windows Update **renombra** las carpetas en vez de borrarlas.
- Las contraseñas WiFi **no se guardan** en los registros.
- Las apps que se quitan se pueden **reinstalar gratis** desde la Microsoft Store.
- Cada acción queda anotada en un **registro (log)** con fecha y hora.

### Lo que MG Toolkit nunca hace

- No desactiva el antivirus, el firewall ni las actualizaciones de Windows.
- No borra documentos, fotos ni archivos personales (salvo vaciar la papelera, que lo dice claramente).
- No modifica archivos internos de Windows ni "limpia el registro".
- No instala programas de terceros sin que los elijas.
- No reinicia el equipo sin preguntar.

### Cómo deshacer cambios

| Si quieres deshacer… | Haz esto |
|---|---|
| Máximo rendimiento, efectos visuales, telemetría | Opción **17**. |
| Un servicio desactivado | Opción **14** → `número A` (automático) o `número M` (manual). |
| Un programa de inicio desactivado | Opción **12** → `A número`. |
| Una app quitada | Reinstalarla desde la Microsoft Store. |
| La hibernación | Opción **7** → activar. |
| Cualquier otro cambio | Restaurar Windows: pulsa `Win` + `R`, escribe `rstrui`, pulsa `ENTER` y elige el punto **"MG Toolkit …"**. No borra tus archivos. |

## 8. Mantenimiento automático semanal

La opción **38** crea una tarea de Windows que cada semana hace, en segundo plano y sin molestar:

- Borra los temporales con más de 1 día, los volcados de memoria y la caché DNS.
- Hace un análisis rápido de virus con Defender (si está activo).

**No** cierra programas, **no** reinicia y **no** cambia configuraciones. Si el equipo está apagado a la hora elegida, el mantenimiento se hace la próxima vez que se encienda.

| Opción | Qué hace |
|---|---|
| 1 | Activar o cambiar el día y la hora (por defecto: miércoles a las 12:00). |
| 2 | Desactivar (borra la tarea). |
| 3 | Ejecutarlo ahora para probar. |
| 4 | Ver los registros del mantenimiento. |

El programa se copia a `C:\ProgramData\MGToolkit\MGToolkit.bat` para que siga funcionando aunque borres el original del Escritorio.

## 9. Archivos que crea

| Dónde | Qué hay |
|---|---|
| `Escritorio\MG Toolkit - Informes` | Informes HTML, registros (log) de cada uso, reporte de batería, configuración de IP fija (si la había) y registros de los respaldos. |
| `C:\ProgramData\MGToolkit` | Solo si activas el mantenimiento semanal: la copia del programa y sus registros (los de más de 90 días se borran solos). |
| La USB o disco que elijas | Respaldos de archivos (`Respaldo_usuario_equipo_fecha`) y de drivers (`Drivers_equipo_fecha`), cada uno con su `LEEME.txt`. |

## 10. Problemas y preguntas frecuentes

**Aparece "Windows protegió su PC"**
Es normal en archivos `.bat` descargados o copiados. Pulsa **Más información** → **Ejecutar de todas formas**.

**El antivirus bloquea el archivo**
Algunos antivirus desconfían de los archivos `.bat` que piden permisos de administrador. Agrégalo como excepción o ábrelo desde una carpeta confiable.

**La ventana se cierra sola al abrirlo**
Probablemente pulsaste "No" cuando Windows pidió permisos. Ábrelo de nuevo y pulsa **Sí**.

**Una tarea dice "aviso" o "error"**
El resumen indica cuántos hubo. El detalle está en el log (opción 40). Los avisos más comunes son normales: un archivo en uso que no se pudo borrar o un servicio que ya estaba detenido.

**DISM falla con error**
Necesita internet. Revisa la conexión y repite. Si sigue fallando, Windows puede repararse con una "actualización en sitio" desde la ISO oficial de Microsoft (conserva archivos y programas).

**"Liberar RAM" no cambió mucho o la RAM se vuelve a llenar**
Es normal: Windows usa la RAM libre como caché para ir más rápido. Si siempre está llena y el equipo va lento, el informe recomendará ampliar la RAM.

**Después de "Reparar internet" no hay conexión**
Reinicia el equipo: el reinicio de red se completa al reiniciar. Si el equipo tenía IP fija, la configuración quedó guardada en la carpeta de informes (`IP_fija_...txt`).

**¿Puedo usarlo en muchos equipos?**
Sí. Llévalo en una USB junto con este manual. Cada equipo guarda sus propios informes en su Escritorio.

---

MG Toolkit v1.0 · Herramientas de Limpieza y Optimización de Windows · Creado por **Matthew Garay**
