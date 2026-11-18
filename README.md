# MG Toolkit

**Herramientas de Limpieza y Optimización de Windows** · Creado por **Matthew Garay**

MG Toolkit es una herramienta de consola para **Windows 7, 8, 8.1, 10 y 11** que reúne en un solo archivo `.bat` el mantenimiento que hace un técnico de soporte: limpiar, acelerar, reparar Windows, buscar virus, respaldar, instalar programas y revisar el equipo. Al terminar genera un **informe con una puntuación de 0 a 100** que dice qué le falta a Windows para estar al 100% y cómo arreglarlo.

Usa solo herramientas que ya trae Windows (DISM, SFC, CHKDSK, Microsoft Defender, robocopy, pnputil, winget). No instala nada por su cuenta ni toca archivos internos de Windows.

```
  ==================================================================  Matthew Garay
        MG Toolkit  -  Herramientas de Limpieza y Optimizacion de Windows
                       v1.0   |   Creado por Matthew Garay
  ==================================================================
   HACER TODO (con informe al final)                 SEGURIDAD Y RESPALDO
       1  Todo PREGUNTANDO (S/N, T = si a todo)        21  Buscar virus (Defender)
       2  Todo AUTOMATICO, sin preguntar               22  Crear punto de restauracion
       3  Solo revisar y ver el informe                23  Respaldar archivos del usuario
                                                       24  Respaldar / restaurar drivers
   LIMPIEZA
       4  Borrar temporales y basura                 REPARACION
       5  Borrar cache de navegadores                  25  Reparar archivos de Windows
       ...                                             ...
```

## Inicio rápido

1. Descarga `MG Toolkit.bat` y `MANUAL.md` (botón verde **Code** → **Download ZIP**).
2. Haz doble clic en `MG Toolkit.bat` y acepta los permisos de administrador.
3. Escribe el número de una opción y pulsa `ENTER`.

Para ver lo que haría sin cambiar nada, activa el **modo simulación** (opción 39) o ábrelo así:

```bat
"MG Toolkit.bat" --dry-run
```

## Qué incluye

| Área | Herramientas |
|---|---|
| **Hacer todo** | Todo preguntando paso a paso (S / N / T = sí a todo) · Todo automático · Solo diagnóstico con informe |
| **Limpieza** | Temporales y basura · Caché de navegadores · Papelera · Hibernación · Buscar archivos grandes · Quitar apps basura de fábrica · Ver qué ocupa el disco · Buscar archivos duplicados |
| **Velocidad** | Máximo rendimiento · Liberar RAM · Programas de inicio · Qué consume más · Servicios sin uso · Telemetría y anuncios · Medir velocidad del disco · Inicio rápido · Deshacer cambios |
| **Actualizar** | Actualizaciones de Windows · Actualizar drivers · Actualizar todos los programas · Instalar programas básicos (Chrome, 7-Zip, VLC, AnyDesk…) · Compatibilidad con Windows 11 |
| **Red e internet** | Probar internet (router, DNS, velocidad) · Cambiar DNS · Programas conectados a internet · Archivo hosts · Quitar proxy de publicidad · Sincronizar la hora |
| **Seguridad y respaldo** | Buscar virus con Defender (rápido, completo y sin conexión) · Punto de restauración · Respaldar archivos a USB · Respaldar y restaurar drivers · Cuentas de usuario |
| **Reparación** | DISM + SFC · CHKDSK · Optimizar disco · Reparar internet · Reparar Windows Update · Destrabar impresora · Reiniciar servicios · Firewall · Probar RAM · Dispositivos sin driver · Reparar búsqueda · Reparar iconos · Problemas de suspensión |
| **Información** | Datos del equipo y salud del disco · Batería · Activación de Windows y Office · Contraseñas y reporte de WiFi · Clave de producto · Lista de programas instalados · Historial de fallos y pantallas azules |
| **Sistema** | Mantenimiento semanal programado · Reiniciar en modo seguro o a la BIOS · Atajos a 22 herramientas de Windows |

## El informe

Al terminar las opciones 1, 2 o 3 se abre un informe HTML (guardado en `Escritorio\MG Toolkit - Informes`) con:

- **Puntuación de 0 a 100** del estado de Windows.
- **Lo que falta para tener Windows al 100%**, con la solución de cada problema.
- **Programas y herramientas que faltan**, con el comando para instalarlos.
- Diagnóstico de Windows, seguridad, hardware, drivers, estabilidad (pantallas azules, errores de disco) e internet.

## Seguridad

- Crea un **punto de restauración** antes de los cambios grandes.
- **Modo simulación** para ver todo sin aplicar nada.
- Solo borra temporales con **más de 1 día**, para no romper programas abiertos.
- Las acciones delicadas (red, firewall, reinicios) **siempre preguntan**.
- No borra una **IP fija** al reparar la red.
- El respaldo de archivos **solo copia**: nunca borra ni mueve.
- Las contraseñas WiFi **no se guardan** en ningún archivo.
- Los cambios de velocidad se deshacen con una opción del menú (17).

## Requisitos

- Windows 7 SP1, 8, 8.1, 10 u 11 (32 o 64 bits).
- Cuenta de administrador.
- Internet solo para actualizaciones, instalar programas y actualizar el antivirus.

En Windows 7 y 8 el programa se adapta solo: las funciones que esas versiones no tienen se avisan en pantalla, en vez de fallar. El detalle está en el [manual](MANUAL.md#6-windows-7-y-8). Se probó con PowerShell 2.0, el motor que trae Windows 7.

## Documentación

El manual completo, con todas las opciones, qué usar en cada caso y cómo deshacer cambios, está en **[MANUAL.md](MANUAL.md)**.

## Licencia

Distribuido bajo la licencia **MIT**: puedes usarlo, copiarlo, modificarlo y compartirlo libremente, incluso con fines comerciales, siempre que mantengas el aviso de copyright. Se entrega "tal cual", sin garantía. Ver [LICENSE](LICENSE).

## Autor

Creado por **Matthew Garay**.
