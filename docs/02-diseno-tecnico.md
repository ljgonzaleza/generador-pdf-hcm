# 02 — Documento de Diseño de Software (SDD)

## Generador de documentos PDF HCM

| Campo | Valor |
|-------|-------|
| Proyecto | Generador de documentos PDF HCM (certificados, cartas, constancias) |
| Sistema | SAP S/4HANA 2023 · ABAP Platform 7.58 |
| Módulo | HCM (infotipos PA clásicos `PAnnnn`) · MOLGA PE (Perú) |
| UI | SAP GUI clásico (Dynpro / ALV OO). Sin Fiori, RAP, CDS de UI ni OData |
| Empaquetado de código | abapGit · paquete Z único |
| Estado del documento | Borrador para validación |
| Fase | Diseño (sin código; pendiente de `CODIFICAR`) |
| Documentos relacionados | `01-especificacion-funcional.md`, `03-preguntas-abiertas.md`, `requisitos.md` |
| Estándar aplicado | "Estándar de Desarrollos SAP S/4 v1.0" — Grupo LATAM Airlines (regla `estandares-abap.mdc`) |

> **Nota 1 — Validación pendiente:** los nombres de objeto son **propuestas** sujetas a tu aprobación (ver `03-preguntas-abiertas.md`). No se ha creado ningún objeto ni código todavía.
>
> **Nota 2 — Supuestos por defecto:** mientras no se respondan las preguntas abiertas, este SDD adopta las suposiciones por defecto de `03` (motor Smart Forms, almacenamiento en tabla Z, etc.), marcadas con la etiqueta *(provisional, P-x)*.

---

## Índice

1. Introducción y alcance
2. Arquitectura de la solución
3. Modelo de datos
4. Diseño de objetos (programas, transacciones, includes)
5. Diseño de clases y responsabilidades
6. Flujos de proceso (secuencias)
7. Motor de generación PDF
8. Almacenamiento de los PDF
9. Lectura de datos HCM
10. Seguridad y autorizaciones
11. Manejo de errores y excepciones
12. Internacionalización (ES/EN/PT)
13. Estrategia de transporte vs. PRD
14. Paquete de desarrollo y abapGit
15. Cumplimiento de estándares (checklist)
16. Matriz de trazabilidad
17. Supuestos, dependencias y riesgos

---

## 1. Introducción y alcance

### 1.1 Objetivo
Diseñar una solución a medida, simple y pragmática, que permita al personal de RRHH generar documentos PDF para empleados a partir de **plantillas mantenibles directamente en productivo**, sin requerir una orden de transporte por cada nuevo documento.

### 1.2 Alcance funcional (solo tres funcionalidades)
1. **Gestión de plantillas** (crear/editar/copiar/desactivar, versionado, mapeo de placeholders, firma).
2. **Generación de documentos por persona** (selección PERNR + plantilla activa, vista previa, PDF, registro).
3. **Consulta de históricos** (ALV de documentos generados, reapertura del PDF, consulta de versiones).

Fuera de alcance: generación masiva, multilenguaje de documentos, firma digital, workflows, autorización por datos HR.

### 1.3 Principio rector del diseño
> El **contenido** de la plantilla (texto + placeholders + mapeo + firma) se almacena como **dato de aplicación en tablas Z (clase de entrega `A`)**, editable en PRD sin transporte. El **motor PDF** es una **cáscara genérica única** que renderiza el texto ya resuelto; se transporta una sola vez y no cambia al crear/editar plantillas.

Esto desacopla el "qué se imprime" (dato, en PRD) del "cómo se imprime" (formulario, en repositorio), cumpliendo el requisito central de mantenibilidad en productivo.

---

## 2. Arquitectura de la solución

### 2.1 Estilo arquitectónico
ABAP orientado a objetos en **tres capas lógicas**, sin sobre-ingeniería:

- **Capa de presentación (UI):** programas ejecutables (reportes tipo 1) con pantallas de selección, Dynpros y ALV OO. Contiene solo orquestación de UI y eventos; delega la lógica a las clases.
- **Capa de aplicación / dominio:** clases `ZCL_CP_*` que concentran las reglas de negocio (gestión de plantillas, resolución de placeholders, generación, histórico, firmas).
- **Capa de persistencia / acceso a datos:** tablas Z `ZHHR_CP_*`, lectura de infotipos HCM vía API estándar, y el Smart Form/Adobe Form como recurso de renderizado.

### 2.2 Diagrama de componentes (textual)

```
+---------------------------------------------------------------+
|                     CAPA DE PRESENTACIÓN                      |
|  ZHHRR_775 (plantillas)  ZHHRR_776 (generar)  ZHHRR_777 (hist)|
|  Dynpro/ALV OO + pantallas de selección + visor PDF           |
+----------------------------+----------------------------------+
                             | usa
                             v
+---------------------------------------------------------------+
|                  CAPA DE APLICACIÓN / DOMINIO                  |
|  ZCL_CP_TPL_MANAGER   ZCL_CP_DOC_SERVICE   ZCL_CP_DOC_HISTORY  |
|  ZCL_CP_PH_RESOLVER   ZCL_CP_PDF_BUILDER   ZCL_CP_FIRMA        |
|  ZCL_CP_HR_READER          ZCX_CP_ERROR (excepción)           |
+--------+------------------------+----------------------+-------+
         | persiste               | renderiza            | lee
         v                        v                      v
+-----------------+   +-----------------------+   +---------------+
| Tablas Z (cl. A)|   | Smart Form/Adobe Form |   | Infotipos PA  |
| TPLH TPLV MAP   |   | ZHHR_CP_SF_DOC        |   | HR_READ_INFO- |
| FIRM DLOG PDF   |   | (-> OTF -> PDF)       |   | TYPE (PA0002) |
+-----------------+   +-----------------------+   +---------------+
```

### 2.3 Mapeo funcionalidad → programa

| Funcionalidad | Programa | Transacción | Clase orquestadora principal |
|---------------|----------|-------------|------------------------------|
| Gestión de plantillas | `ZHHRR_775` | `ZHHRT_775` | `ZCL_CP_TPL_MANAGER` |
| Generación por persona | `ZHHRR_776` | `ZHHRT_776` | `ZCL_CP_DOC_SERVICE` |
| Consulta de históricos | `ZHHRR_777` | `ZHHRT_777` | `ZCL_CP_DOC_HISTORY` |

---

## 3. Modelo de datos

Todas las tablas Z son **datos de aplicación** → **clase de entrega `A`** (no customizing). Su **contenido se crea/modifica directamente en PRD sin orden de transporte**; lo que viaja por transporte es la **definición** DDIC (ver §13).

Convención de nomenclatura (LATAM): `Z` + `H` (RRHH) + `HR` (módulo) + tipo + `_` + correlativo (desde **775**). El "resto de objetos" lleva el identificador `CP`: prefijo **`ZHHR_CP_`** para tablas/estructuras/elementos/dominios y `ZCL_CP_` / `ZCX_CP_` para clases/excepciones. (Longitud máx. de nombre de tabla = 16; todos cumplen.)

### 3.1 `ZHHR_CP_TPLH` — Cabecera de plantilla (1 fila por plantilla lógica)

| Campo | Tipo / elem. datos | Clave | Descripción |
|-------|--------------------|:----:|-------------|
| `MANDT` | MANDT | ✔ | Mandante |
| `TPL_ID` | `ZDE_CP_TPL_ID` (CHAR 20) | ✔ | Id de plantilla |
| `DESCR` | `ZDE_CP_TPL_TXT` (CHAR 60) | | Descripción |
| `ACTIVE_VER` | `ZDE_CP_TPL_VER` (NUMC 4) | | Versión Activa vigente (0 = ninguna) |
| `ERNAM` / `ERDAT` | ERNAM / ERDAT | | Creado por / el |
| `AENAM` / `AEDAT` | AENAM / AEDAT | | Modificado por / el |

### 3.2 `ZHHR_CP_TPLV` — Versiones de plantilla (cuerpo del documento)

| Campo | Tipo / elem. datos | Clave | Descripción |
|-------|--------------------|:----:|-------------|
| `MANDT` | MANDT | ✔ | Mandante |
| `TPL_ID` | `ZDE_CP_TPL_ID` | ✔ | Plantilla (FK → TPLH) |
| `VERSION` | `ZDE_CP_TPL_VER` | ✔ | Versión |
| `STATUS` | `ZDE_CP_TPL_ST` (dom. `ZDO_CP_TPL_ST`) | | Estado: `B` Borrador / `A` Activa / `O` Obsoleta |
| `TITULO` | `ZDE_CP_TPL_TXT` | | Título/asunto del documento |
| `FIRM_ID` | `ZDE_CP_FIRM_ID` | | Firmante (FK → FIRM) |
| `BODY` | STRING | | Cuerpo con placeholders `{{...}}` |
| `ERNAM`/`ERDAT`/`AENAM`/`AEDAT` | estándar | | Auditoría de la versión |

### 3.3 `ZHHR_CP_MAP` — Mapeo de placeholders (por versión)

| Campo | Tipo / elem. datos | Clave | Descripción |
|-------|--------------------|:----:|-------------|
| `MANDT` | MANDT | ✔ | Mandante |
| `TPL_ID` | `ZDE_CP_TPL_ID` | ✔ | Plantilla |
| `VERSION` | `ZDE_CP_TPL_VER` | ✔ | Versión |
| `PLACEHOLDER` | `ZDE_CP_PHOLD` (CHAR 30) | ✔ | Placeholder sin llaves |
| `INFTY` | INFTY (CHAR 4) | | Infotipo origen (p. ej. `0002`) |
| `FIELDNAME` | FDNAME (CHAR 30) | | Campo del infotipo (p. ej. `VORNA`) |
| `FMT` | `ZDE_CP_FMT` (dom. `ZDO_CP_FMT`) | | Formato: `TEXTO`/`FECHA`/`FECHA_LARGA`/`IMPORTE` |

### 3.4 `ZHHR_CP_FIRM` — Firmantes e imagen de firma

Imagen almacenada como binario en tabla (no SE78/BDS, que requeriría transporte) → mantenible en PRD.

| Campo | Tipo / elem. datos | Clave | Descripción |
|-------|--------------------|:----:|-------------|
| `MANDT` | MANDT | ✔ | Mandante |
| `FIRM_ID` | `ZDE_CP_FIRM_ID` (CHAR 10) | ✔ | Id firmante |
| `NOMBRE` | `ZDE_CP_TPL_TXT` | | Nombre del firmante |
| `CARGO` | `ZDE_CP_TPL_TXT` | | Cargo del firmante |
| `MIMETYPE` | CHAR 40 | | Tipo MIME (image/png, image/jpeg) |
| `IMG` | XSTRING | | Imagen de firma (binario) |
| auditoría | estándar | | Creado/modificado por/el |

### 3.5 `ZHHR_CP_DLOG` — Log de documentos generados (cabecera de histórico)

| Campo | Tipo / elem. datos | Clave | Descripción |
|-------|--------------------|:----:|-------------|
| `MANDT` | MANDT | ✔ | Mandante |
| `DOC_ID` | `ZDE_CP_DOC_ID` (NUMC 12) | ✔ | Id de documento (rango de números) |
| `PERNR` | PERNR_D | | Número de personal |
| `TPL_ID` | `ZDE_CP_TPL_ID` | | Plantilla usada |
| `VERSION` | `ZDE_CP_TPL_VER` | | Versión usada |
| `FECHA_REF` | DATUM | | Fecha de referencia de lectura |
| `FECHA_GEN` | DATUM | | Fecha de generación |
| `HORA_GEN` | UZEIT | | Hora de generación |
| `USUARIO` | XUBNAME | | Usuario que generó |

### 3.6 `ZHHR_CP_PDF` — Binario del PDF generado (1:1 con DLOG)

| Campo | Tipo / elem. datos | Clave | Descripción |
|-------|--------------------|:----:|-------------|
| `MANDT` | MANDT | ✔ | Mandante |
| `DOC_ID` | `ZDE_CP_DOC_ID` | ✔ | Id documento (FK → DLOG) |
| `FILENAME` | CHAR 100 | | Nombre de archivo sugerido |
| `FILESIZE` | INT4 | | Tamaño en bytes |
| `PDF` | XSTRING | | Contenido del PDF |

### 3.7 Modelo entidad-relación (textual)

```
ZHHR_CP_TPLH 1 ----< N ZHHR_CP_TPLV 1 ----< N ZHHR_CP_MAP
                            |
                            | FIRM_ID
                            v
                      ZHHR_CP_FIRM
ZHHR_CP_DLOG 1 ---- 1 ZHHR_CP_PDF
ZHHR_CP_DLOG (TPL_ID, VERSION) ----> ZHHR_CP_TPLV   (versión usada; trazabilidad)
```

### 3.8 Elementos de datos y dominios

| Objeto | Tipo | Descripción / valores |
|--------|------|-----------------------|
| `ZDO_CP_TPL_ST` | Dominio CHAR 1 | Valores fijos `B`/`A`/`O` |
| `ZDO_CP_FMT` | Dominio CHAR 12 | `TEXTO`/`FECHA`/`FECHA_LARGA`/`IMPORTE` |
| `ZDE_CP_TPL_ID` | Elem. datos CHAR 20 | Id de plantilla |
| `ZDE_CP_TPL_VER` | Elem. datos NUMC 4 | Versión de plantilla |
| `ZDE_CP_TPL_ST` | Elem. datos (dom. `ZDO_CP_TPL_ST`) | Estado de versión |
| `ZDE_CP_TPL_TXT` | Elem. datos CHAR 60 | Texto descriptivo |
| `ZDE_CP_PHOLD` | Elem. datos CHAR 30 | Placeholder |
| `ZDE_CP_FMT` | Elem. datos (dom. `ZDO_CP_FMT`) | Tipo de formato |
| `ZDE_CP_FIRM_ID` | Elem. datos CHAR 10 | Id de firmante |
| `ZDE_CP_DOC_ID` | Elem. datos NUMC 12 | Id de documento |

### 3.9 Estructuras auxiliares (DDIC)

| Objeto | Descripción |
|--------|-------------|
| `ZHHR_CP_S_PHVAL` | Par placeholder → valor resuelto (entrada al motor PDF) |
| `ZHHR_CP_S_DOCROW` | Fila de salida ALV del histórico (PERNR, nombre, plantilla, versión, fecha, usuario) |

---

## 4. Diseño de objetos (programas, transacciones, includes)

### 4.1 Programas, transacciones e includes

| Funcionalidad | Programa | Transacción | Includes |
|---------------|----------|-------------|----------|
| Gestión de plantillas | `ZHHRR_775` | `ZHHRT_775` | `ZHHRR_775_TOP`, `ZHHRR_775_SEL`, `ZHHRR_775_CLA`, `ZHHRR_775_F00` |
| Generación por persona | `ZHHRR_776` | `ZHHRT_776` | `ZHHRR_776_TOP`, `ZHHRR_776_SEL`, `ZHHRR_776_CLA`, `ZHHRR_776_F00` |
| Consulta de históricos | `ZHHRR_777` | `ZHHRT_777` | `ZHHRR_777_TOP`, `ZHHRR_777_SEL`, `ZHHRR_777_CLA`, `ZHHRR_777_F00` |

Contenido por include (estándar LATAM):
- `_TOP`: declaraciones globales (tipos, datos, constantes, referencias a clases).
- `_SEL`: pantalla de selección (`PARAMETERS`/`SELECT-OPTIONS`) y textos.
- `_CLA`: definición/implementación de clases locales de controlador de UI (si aplica).
- `_F00`: subrutinas/módulos auxiliares.

Los programas `ZHHRR_775` y `ZHHRR_776`/`777` que usen Dynpros con visor o editor añadirán módulos de pantalla `..._O01` (PBO) e `..._I01` (PAI) según necesidad, respetando el estándar.

**Opcional (P-15):** menú de área `ZHHR_CP_MENU` agrupando las tres transacciones.

### 4.2 Objetos de presentación / impresión

| Objeto | Tipo | Descripción |
|--------|------|-------------|
| `ZHHR_CP_SF_DOC` | Smart Form | Cáscara genérica de impresión *(recomendado por defecto, §7)*. Recibe texto resuelto + título + imagen de firma; produce OTF → PDF. |
| `ZHHR_CP_AF_DOC` + `ZHHR_CP_AF_IF` | Adobe Form + Interface | Alternativa si se confirma ADS *(P-1)*. |

### 4.3 Objetos de soporte

| Objeto | Tipo | Descripción |
|--------|------|-------------|
| `ZHHR_CP_MSG` | Clase de mensajes | Mensajes de aplicación, con traducción ES/EN/PT |
| `ZCP_DOCNR` | Objeto de rango de números | Correlativo de `DOC_ID` (definición viaja por TR; **intervalos se mantienen en PRD**) |
| Grupo de autorización tablas | Customizing SE54 | Grupo `S_TABU_DIS` asignado a las tablas Z *(valor a confirmar, P-10)* |
| Vistas de mantenimiento (opc.) | SM30/SE54 | Mantenedores de respaldo para `FIRM`/`MAP` *(P-12)* |

---

## 5. Diseño de clases y responsabilidades

> Se describen métodos **conceptualmente** (nombre + propósito + entradas/salidas). **No es código ABAP**; las firmas definitivas se fijarán en la fase `CODIFICAR`.

### 5.1 `ZCL_CP_TPL_MANAGER` — Gestión y versionado de plantillas
Única clase que escribe en `TPLH`/`TPLV`/`MAP`.

| Método | Propósito | Entrada → Salida |
|--------|-----------|------------------|
| `get_list` | Lista de plantillas con su versión activa y estado | — → tabla de cabeceras |
| `read_version` | Lee una versión concreta (cuerpo + mapeo + firmante) | TPL_ID, VERSION → datos de versión |
| `create` | Crea plantilla nueva con versión 1 en Borrador | datos de cabecera + cuerpo + mapeo → TPL_ID |
| `save_draft` | Guarda Borrador; si la vigente está Activa, crea nueva versión Borrador | TPL_ID + datos → VERSION |
| `copy` | Duplica contenido a una nueva plantilla en Borrador | TPL_ID origen, TPL_ID destino → — |
| `activate` | Valida placeholders y activa la versión; obsoletea la anterior | TPL_ID, VERSION → — |
| `deactivate` | Obsoletea la versión Activa (plantilla sin versión activa) | TPL_ID → — |
| `validate_placeholders` | Comprueba que todo `{{...}}` del cuerpo tenga mapeo | cuerpo + mapeo → lista de faltantes |

### 5.2 `ZCL_CP_FIRMA` — Firmantes e imagen de firma
| Método | Propósito |
|--------|-----------|
| `get_list` | Catálogo de firmantes (para ayuda de búsqueda) |
| `read` | Lee firmante + binario de imagen + MIME |
| `save` | Alta/modificación de firmante e imagen (valida MIME y tamaño) |

### 5.3 `ZCL_CP_HR_READER` — Lectura de infotipos
Encapsula `HR_READ_INFOTYPE` **sin** authority check, con validación de `SY-SUBRC`. Sin `SELECT *`.

| Método | Propósito | Entrada → Salida |
|--------|-----------|------------------|
| `read_field` | Devuelve el valor de un campo del registro vigente | PERNR, INFTY, FIELDNAME, fecha ref → valor |
| `read_infotype` | Devuelve el registro vigente completo de un infotipo | PERNR, INFTY, fecha ref → registro |

### 5.4 `ZCL_CP_PH_RESOLVER` — Resolución y formateo de placeholders
| Método | Propósito |
|--------|-----------|
| `resolve` | Recorre el mapeo, pide valores a `HR_READER`, aplica formato y devuelve tabla `ZHHR_CP_S_PHVAL` |
| `apply_format` | Formatea según `ZDO_CP_FMT` (texto, fecha, fecha larga, importe) |
| `substitute` | Sustituye `{{...}}` en el cuerpo por los valores resueltos |

### 5.5 `ZCL_CP_PDF_BUILDER` — Motor PDF (envoltorio único)
Aísla la tecnología de renderizado tras una interfaz; el resto del código no depende del motor.

| Método | Propósito | Entrada → Salida |
|--------|-----------|------------------|
| `build` | Renderiza el documento a PDF | título + cuerpo resuelto + imagen firma → XSTRING PDF |

### 5.6 `ZCL_CP_DOC_SERVICE` — Orquestación de la generación (Func. 2)
| Método | Propósito |
|--------|-----------|
| `preview` | Obtiene versión Activa, resuelve placeholders y devuelve el PDF para vista previa (no registra) |
| `generate_and_log` | Igual que preview + asigna `DOC_ID` y graba `DLOG` + `PDF` |

### 5.7 `ZCL_CP_DOC_HISTORY` — Consulta de históricos (Func. 3)
| Método | Propósito |
|--------|-----------|
| `search` | Selección filtrada sobre `DLOG` (PERNR, plantilla, fecha, usuario) → filas ALV |
| `get_pdf` | Recupera el binario almacenado para reabrir/descargar |
| `get_template_version` | Devuelve la versión de plantilla usada (solo lectura) |

### 5.8 `ZCX_CP_ERROR` — Excepción de aplicación
Hereda de `CX_STATIC_CHECK`. Casos: plantilla inexistente, sin versión activa, placeholder sin mapeo, error de lectura HR, error de render PDF, error de persistencia.

---

## 6. Flujos de proceso (secuencias)

### 6.1 Activación de una plantilla (Func. 1)

```
Usuario        ZHHRR_775        ZCL_CP_TPL_MANAGER       Tablas Z
  |  Activar v.    |                    |                    |
  |--------------->| activate(TPL,VER)  |                    |
  |                |------------------->| validate_placeholders
  |                |                    |--- lee MAP/BODY -->|
  |                |                    |<-- faltantes ------|
  |                |   (si faltan) error ZCX_CP_ERROR        |
  |                |                    | UPDATE TPLV: ant->O|
  |                |                    | UPDATE TPLV: VER->A|
  |                |                    | UPDATE TPLH.ACTIVE |
  |                |<-- ok / excepción -|------------------->|
  |<-- mensaje ----|                    |                    |
```

### 6.2 Generación de documento por persona (Func. 2)

```
Usuario   ZHHRR_776   DOC_SERVICE   TPL_MANAGER  PH_RESOLVER  HR_READER  PDF_BUILDER  Tablas
  | PERNR+TPL+fecha |       |            |            |           |           |          |
  |---------------->|preview|            |            |           |           |          |
  |                 |------>|read_version|            |           |           |          |
  |                 |       |----------->| (Activa)   |           |           |          |
  |                 |       |  resolve   |            |           |           |          |
  |                 |       |------------------------>|read_field |           |          |
  |                 |       |            |            |---------->| (vigente) |          |
  |                 |       |            |            |<-- valor -|           |          |
  |                 |       |            |  substitute+apply_format|           |          |
  |                 |       |  build(texto, firma)    |           |           |          |
  |                 |       |------------------------------------------------>| OTF->PDF |
  |                 |<------|<-- XSTRING PDF -------------------------------- -|          |
  |<-- vista previa-|       |            |            |           |           |          |
  | Generar+registrar       |            |            |           |           |          |
  |---------------->|generate_and_log    |            |           |           |          |
  |                 |  (DOC_ID rango) INSERT DLOG + INSERT PDF --------------------------->|
  |<-- confirmación-|       |            |            |           |           |          |
```

### 6.3 Consulta de histórico y reapertura (Func. 3)

```
Usuario        ZHHRR_777        ZCL_CP_DOC_HISTORY        Tablas Z
  | filtros        |                    |                    |
  |--------------->| search(filtros)    |                    |
  |                |------------------->| SELECT DLOG ------->|
  |                |<-- filas ALV ------|<-------------------|
  |<-- ALV --------|                    |                    |
  | doble clic     |                    |                    |
  |--------------->| get_pdf(DOC_ID)    |                    |
  |                |------------------->| SELECT PDF -------->|
  |<-- abre PDF ---|<-- XSTRING --------|                    |
```

---

## 7. Motor de generación PDF

**Punto clave:** sea cual sea el motor, la plantilla editable en PRD vive en tablas Z; el motor es solo una cáscara genérica que renderiza el texto ya resuelto. Crear/cambiar una plantilla **no** requiere transporte.

| Criterio | Smart Forms + OTF→PDF | Adobe Forms (ADS) |
|----------|------------------------|-------------------|
| Licencia / infraestructura | No requiere nada adicional | Requiere ADS configurado y licenciado |
| Calidad de maquetación | Suficiente para certificados/cartas | Superior (PDF nativo) |
| Imagen de firma | Soportada | Soportada (mejor) |
| Conversión a PDF | `CONVERT_OTF` / FM estándar | PDF nativo directo |
| Riesgo / simplicidad | Bajo, muy probado | Depende de ADS |

**Recomendación:** **Smart Forms + OTF→PDF** por defecto (más simple, sin dependencias; funciona aunque no haya ADS). Si se confirma ADS *(P-1)*, se puede optar por Adobe Forms por mejor calidad. La decisión queda aislada en `ZCL_CP_PDF_BUILDER`, de modo que cambiar de motor no afecta al resto.

---

## 8. Almacenamiento de los PDF

**Recomendación por defecto:** binario del PDF en la tabla Z `ZHHR_CP_PDF` (`XSTRING`), enlazada 1:1 con `ZHHR_CP_DLOG`.
- Ventajas: simplicidad máxima, reapertura/descarga inmediata del documento *tal como se generó* (trazabilidad), sin dependencias externas, mantenible en PRD sin transporte.
- Límite: con volumen/retención altos, la tabla crece.

**Alternativa escalable *(P-2)*:** ArchiveLink / Content Server (o GOS), guardando en `DLOG` solo el identificador de archivado. Camino estándar SAP para contenido masivo. Decisión según volumen y política de retención.

---

## 9. Lectura de datos HCM

- `HR_READ_INFOTYPE` con authority check **desactivado** (no se valida por PERNR, conforme a requisitos), leyendo el **registro vigente** a la fecha de referencia (`BEGDA ≤ fecha ≤ ENDDA`).
- Validación inmediata de `SY-SUBRC`; operaciones críticas con TRY/CATCH (`ZCX_CP_ERROR` + excepciones estándar).
- **Sin `SELECT *`**: solo se leen los campos del mapeo (`INFTY` + `FIELDNAME`).
- Infotipo base esperado: **PA0002** (datos personales). Otros infotipos/campos según placeholders definidos *(lista a confirmar, P-3)*.

---

## 10. Seguridad y autorizaciones

- Control de acceso **únicamente a nivel de transacción**: `AUTHORITY-CHECK` del objeto `S_TCODE` al inicio de cada programa, con validación inmediata de `SY-SUBRC` y `LEAVE PROGRAM` si falla.
- **No** hay authority check por número de personal ni por datos HR: sin `P_PERNR`, sin `P_ORGIN`, sin restricciones por sociedad/área de personal/unidad organizativa ni objetos de autorización Z.
- Cualquier usuario con acceso a la transacción puede generar documentos para cualquier PERNR.
- Segregación funcional posible vía transacciones separadas (775 plantillas / 776 generación / 777 históricos) *(a confirmar el modelo de roles, P-12)*.
- Tablas Z con **grupo de autorización** (`S_TABU_DIS`) asignado en SE54 *(valor a confirmar, P-10)*.

---

## 11. Manejo de errores y excepciones

Obligatorio por estándar LATAM:
- Toda sentencia que modifique `SY-SUBRC` (SELECT, READ TABLE, CALL FUNCTION, UPDATE/INSERT/MODIFY) lleva **validación inmediata** del código de retorno.
- Operaciones susceptibles de excepción en runtime envueltas en **TRY/CATCH** con las clases adecuadas (p. ej. `CX_SY_FILE_*` en archivos, `CX_SY_ARITHMETIC_*` en cálculos).
- Errores de negocio canalizados por `ZCX_CP_ERROR` y mensajes de `ZHHR_CP_MSG` (sin textos hardcodeados).
- Sin breakpoints en código productivo.

| Situación | Tratamiento |
|-----------|-------------|
| Plantilla sin versión Activa | Excepción `ZCX_CP_ERROR` + mensaje; no se genera |
| Placeholder sin mapeo al activar | Bloquea la activación (RN-1.3) |
| Placeholder sin dato del empleado | *(provisional, P-14)* en blanco + aviso antes de registrar |
| Error de lectura de infotipo | Validación de `SY-SUBRC` + excepción |
| Error de render/conversión PDF | TRY/CATCH + excepción + mensaje |
| Error al asignar `DOC_ID`/grabar | Validación + rollback lógico, no se registra a medias |

---

## 12. Internacionalización (ES/EN/PT)

- **Documentos generados:** en español (Perú) *(confirmar plantillas solo en ES, P-5)*.
- **Interfaz de los programas** (parámetros, títulos, columnas ALV, textos de selección) y **clase de mensajes** `ZHHR_CP_MSG`: traducción obligatoria a **español, inglés y portugués** como requisito de pase a productivo (estándar LATAM).
- Comentarios y documentación de código: español.

---

## 13. Estrategia de transporte vs. PRD

### 13.1 Viaja por orden de transporte (objetos de repositorio / definición)
- Programas `ZHHRR_775/776/777` e includes.
- Transacciones `ZHHRT_775/776/777` (y menú de área si se crea).
- Clases `ZCL_CP_*` y excepción `ZCX_CP_*`.
- **Definición** DDIC de tablas `ZHHR_CP_*`, estructuras `ZHHR_CP_S_*`, elementos `ZDE_CP_*`, dominios `ZDO_CP_*`.
- Smart Form `ZHHR_CP_SF_DOC` (o Adobe Form `ZHHR_CP_AF_DOC` + interface).
- Clase de mensajes `ZHHR_CP_MSG` (incl. traducciones).
- **Definición** del objeto de rango de números `ZCP_DOCNR`.
- Asignación de grupo de autorización de tablas (SE54) y vistas de mantenimiento, si se generan.

### 13.2 Se mantiene en PRD (datos de aplicación / contenido — sin transporte)
- Contenido de plantillas: `ZHHR_CP_TPLH`, `ZHHR_CP_TPLV`, `ZHHR_CP_MAP`.
- Firmantes e imágenes: `ZHHR_CP_FIRM`.
- Histórico de documentos: `ZHHR_CP_DLOG` y binarios `ZHHR_CP_PDF` (o ArchiveLink si se elige).
- **Intervalos** del rango de números `ZCP_DOCNR`.

> Posible por la **clase de entrega `A`** de las tablas: la estructura viaja, el contenido es local de cada sistema → cumple "crear/editar plantillas en PRD sin orden de transporte".

---

## 14. Paquete de desarrollo y abapGit

- **Paquete Z único** para todos los objetos (sin subpaquetes, sin `$TMP`). Nombre/descripción/capa a confirmar *(P-7)*.
- Estructura compatible con **abapGit** (`STARTING_FOLDER = /src/`, lógica `PREFIX`, según `.abapgit.xml`).
- `/docs` y `/.cursor` están en IGNORE de `.abapgit.xml` → **no viajan a SAP**.

---

## 15. Cumplimiento de estándares (checklist)

- [x] Cabecera de documentación obligatoria en cada programa (descripción, fecha, creador, empresa LATAM, histórico `@001`, `@002`…).
- [x] Prefijos de variables `g_/l_`, `gt_/lt_`, `gwa_/lwa_`, `gc_/lc_`, `gr_/lr_`, `go_/lo_`; pantalla `P_` / `S_`.
- [x] `AUTHORITY-CHECK` de `S_TCODE` al inicio + validación de `SY-SUBRC` + `LEAVE PROGRAM` (sin chequeo por PERNR).
- [x] Validación de `SY-SUBRC` tras toda operación; TRY/CATCH con clases de excepción adecuadas.
- [x] ALV orientado a objetos (`CL_GUI_CUSTOM_CONTAINER`; `CL_GUI_DOCKING_CONTAINER` en fondo).
- [x] Sin textos hardcodeados (clase de mensajes + textos ES/EN/PT), sin `SELECT *`, sin breakpoints.
- [x] Elementos de datos `ZDE_*`, dominios `ZDO_*` (con identificador `CP`).
- [x] Mantenedores de tablas Z desde SE11/SE54 con grupo de autorización.
- [x] Code Inspector (SCI) limpio por objeto.
- [x] Compatible con abapGit, paquete Z único.

---

## 16. Matriz de trazabilidad (requisito → objeto/diseño)

| Requisito | Cubierto por |
|-----------|--------------|
| Crear/editar/copiar/desactivar plantillas en PRD | `ZHHRR_775` + `ZCL_CP_TPL_MANAGER` + `TPLH/TPLV/MAP` (clase entrega `A`) |
| Plantillas como dato de aplicación sin transporte | Tablas Z clase `A`; §13 |
| Placeholders `{{...}}` y mapeo a infotipos | `ZHHR_CP_MAP` + `ZCL_CP_PH_RESOLVER` + `ZCL_CP_HR_READER` |
| Lectura del registro vigente a la fecha | `ZCL_CP_HR_READER.read_field` (BEGDA/ENDDA) |
| Formateo de fechas e importes | `ZCL_CP_PH_RESOLVER.apply_format` + `ZDO_CP_FMT` |
| Imagen de firma configurable por plantilla | `ZHHR_CP_FIRM` + `ZHHR_CP_TPLV.FIRM_ID` |
| Versionado Borrador/Activa/Obsoleta | `ZHHR_CP_TPLV.STATUS` + `ZCL_CP_TPL_MANAGER.activate/deactivate` |
| Generación por persona con vista previa | `ZHHRR_776` + `ZCL_CP_DOC_SERVICE.preview` |
| Motor PDF más simple | `ZCL_CP_PDF_BUILDER` + `ZHHR_CP_SF_DOC` (Smart Forms) |
| Registro de cada documento generado | `ZHHR_CP_DLOG` + `ZHHR_CP_PDF` |
| ALV de históricos + reapertura | `ZHHRR_777` + `ZCL_CP_DOC_HISTORY` |
| Consulta de versiones anteriores | `ZCL_CP_DOC_HISTORY.get_template_version` |
| Autorización solo por transacción | §10 (`S_TCODE`) |
| Paquete único Z | §14 |
| Nomenclatura LATAM | §1, §3, §4 |

---

## 17. Supuestos, dependencias y riesgos

### 17.1 Supuestos por defecto (provisionales hasta respuestas en `03`)
1. Motor PDF: Smart Forms + OTF→PDF *(P-1)*.
2. Almacenamiento: binario en `ZHHR_CP_PDF` *(P-2)*.
3. Placeholder sin dato: en blanco + aviso *(P-14)*.
4. Plantillas solo en español *(P-5)*.
5. `DOC_ID` por rango de números *(P-8)*.
6. Correlativo 775/776/777 *(P-11)*.

### 17.2 Dependencias
- Disponibilidad de ADS (solo si se elige Adobe Forms).
- Disponibilidad de ArchiveLink/Content Server (solo si se elige esa vía de almacenamiento).
- Catálogo de placeholders / infotipos a usar.
- Definición del paquete y de la orden de transporte.
- **Regla `estandares-abap.mdc` ausente** en `.cursor/rules/`: cargarla antes de codificar *(P-16)*.

### 17.3 Riesgos
| Riesgo | Impacto | Mitigación |
|--------|---------|------------|
| Crecimiento de `ZHHR_CP_PDF` con alto volumen | Rendimiento/espacio | Migrar a ArchiveLink si el volumen lo exige (§8) |
| Cambios de infotipo no reflejados en docs antiguos | Trazabilidad | Se almacena el PDF generado tal cual (RN-3.2) |
| ADS no disponible | Replanteo del motor | Diseño aislado en `ZCL_CP_PDF_BUILDER`; Smart Forms por defecto |
| Imagen de firma de formato/tamaño no soportado | Render incorrecto | Validación de MIME/tamaño en `ZCL_CP_FIRMA` |

---

> **Fin del SDD.** No se generará código ABAP hasta que se indique explícitamente `CODIFICAR`. Cualquier decisión pendiente está en `03-preguntas-abiertas.md`.