# 04 — Objetos manuales, supuestos y pasos de activación

Este documento acompaña al código generado en `/src` (formato abapGit). Recoge las decisiones tomadas al codificar, los objetos que deben crearse/ajustarse manualmente y el orden de activación recomendado.

> El código se generó tras la indicación `CODIFICAR`, aplicando las convenciones del estándar LATAM resumidas en `requisitos.md`. **Recordatorio:** el archivo de regla `.cursor/rules/estandares-abap.mdc` aún no existe (solo el `_LEER.md`); conviene cargarlo para validar el detalle fino del estándar.

---

## 1. Supuestos aplicados (valores por defecto de `03-preguntas-abiertas.md`)

| # | Decisión | Valor aplicado | Pregunta |
|---|----------|----------------|----------|
| 1 | Motor PDF | Smart Forms + `CONVERT_OTF` → PDF | P-1 |
| 2 | Almacenamiento PDF | Binario en tabla `ZHHR_CP_PDF` | P-2 |
| 3 | Placeholder sin dato | Se deja en blanco (sin abortar) | P-14 |
| 4 | Idioma de plantillas | Español | P-5 |
| 5 | `DOC_ID` | Correlativo `MAX(doc_id)+1` con reintento ante colisión (en lugar de objeto de rango de números) | P-8 |
| 6 | Correlativo programas/transacciones | 775 / 776 / 777 | P-11 |
| 7 | Paquete | Se asume `ZHHR_CP` (ajustar al asignar en abapGit) | P-7 |
| 8 | Formato fecha / fecha larga / importe | `dd.mm.aaaa` / "17 de junio de 2026" / formato de usuario | P-4 |
| 9 | Infotipo por defecto en el mapeo | `0002` (sugerido en el popup de mapeo) | P-3 |

Si alguno de estos valores cambia, hay que ajustar el código correspondiente antes del pase.

---

## 2. Objeto a crear manualmente: Smart Form `ZHHR_CP_SF_DOC`

El motor PDF (`ZCL_CP_PDF_BUILDER`) invoca **dinámicamente** un Smart Form genérico. Los formularios de layout se construyen en el Form Builder (transacción `SMARTFORMS`) y su serialización abapGit es muy extensa/sensible, por lo que **no se incluye** en `/src`: debe crearse una sola vez en el sistema.

**Nombre:** `ZHHR_CP_SF_DOC`

**Interfaz de importación (form interface → Import):**

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `IV_TITULO` | `ZDE_CP_TPL_TXT` | Título / encabezado del documento |
| `IV_FIRMANTE` | `ZDE_CP_TPL_TXT` | Nombre del firmante |
| `IV_CARGO` | `ZDE_CP_TPL_TXT` | Cargo del firmante |
| `IV_FIRMA_IMG` | `XSTRING` | Imagen de la firma (binario) |

**Tablas (form interface → Tables):**

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `IT_LINEAS` | `TDLINE` (tabla) | Líneas del cuerpo ya resueltas (placeholders sustituidos) |

**Layout mínimo sugerido:**
- Ventana principal con un nodo de texto que recorra `IT_LINEAS` (un `LOOP` sobre la tabla mostrando `IT_LINEAS-tdline`).
- Texto de cabecera con `IV_TITULO`.
- Bloque de firma al pie con `IV_FIRMANTE` y `IV_CARGO`.
- Para la imagen `IV_FIRMA_IMG`: en Smart Forms la inserción directa de un `XSTRING` no es nativa. Opciones:
  1. Cargar la firma como gráfico en `SE78` (BDS) y referenciarla por nombre (requiere transporte del gráfico), o
  2. Usar un nodo de imagen dinámica vía la clase de ayuda estándar de Smart Forms.
  - **Pendiente de confirmar** el enfoque preferido (relacionado con P-6).

Mientras el Smart Form no exista, la previsualización/generación devolverá el error "Error al generar el documento PDF" (mensaje `ZHHR_CP_MSG` 005), controlado por excepción.

---

## 3. Pasos de activación en abapGit / SAP

1. **Crear el paquete** Z (p. ej. `ZHHR_CP`) y asociarlo al repositorio abapGit. Ajustar el nombre del archivo `package.devc.xml` si el paquete definitivo es otro.
2. **Importar (pull)** el repositorio. Activar en este orden si la activación masiva diera problemas de dependencias:
   1. Dominios (`ZDO_CP_*`).
   2. Elementos de datos (`ZDE_CP_*`).
   3. Estructuras y tablas (`ZHHR_CP_S_*`, `ZHHR_CP_*`).
   4. Clase de mensajes (`ZHHR_CP_MSG`).
   5. Clase de excepción (`ZCX_CP_ERROR`) y clases `ZCL_CP_*`.
   6. Programas e includes (`ZHHRR_775/776/777` + `_TOP/_SEL/_CLA`).
   7. Transacciones (`ZHHRT_775/776/777`).
3. **Crear el Smart Form** `ZHHR_CP_SF_DOC` (sección 2).
4. **Asignar grupo de autorización** a las tablas Z en `SE54` (pendiente el valor, P-10).
5. **Cargar firmantes** iniciales en `ZHHR_CP_FIRM` (desde el propio uso o un mantenimiento técnico).
6. **Traducciones EN/PT** de textos de interfaz y de la clase de mensajes (requisito de pase a PRD del estándar LATAM). El máster del repositorio es español (`MASTER_LANGUAGE=S`); las traducciones se añaden vía `SE63` o ficheros i18n de abapGit. **Pendiente.**

---

## 4. Desviaciones respecto al SDD (`02-diseno-tecnico.md`)

| Tema | SDD | Implementación | Motivo |
|------|-----|----------------|--------|
| `DOC_ID` | Objeto de rango de números `ZCP_DOCNR` | `MAX(doc_id)+1` con reintento | Evitar un objeto cuya serialización abapGit es frágil; mantiene la solución autocontenida. Se puede migrar a rango de números si se prefiere. |
| Cuerpo de plantilla | Campo `BODY` (STRING) en `TPLV` | Tabla de líneas `ZHHR_CP_TPLT` (`TDFORMAT`+`TDLINE`) | Permite editar el cuerpo con el editor estándar (`EDIT_TEXT`) sin pantallas Dynpro propias. |
| Edición en pantalla (775) | Dynpro con TextEdit + ALV editable | Flujo sin Dynpro: popups (`POPUP_GET_VALUES`), editor `EDIT_TEXT` y mapeo placeholder por placeholder | Garantiza que el proyecto active sin objetos de pantalla/CUA hechos a mano. La UI puede enriquecerse luego con un Dynpro dedicado. |
| Vista previa PDF | Visor embebido | Apertura en el visor por defecto del frontend (`ZCL_CP_PDF_VIEW`) | Simplicidad y portabilidad, sin contenedor/pantalla. |

Todas son simplificaciones pragmáticas; el diseño lógico (clases, tablas, flujos) se mantiene.

---

## 5. Objeto extra incluido

- `ZCL_CP_PDF_VIEW`: utilidad de frontend para **visualizar** (abrir en visor) y **descargar** el PDF. No estaba nominado en el SDD; se añadió para evitar duplicar lógica de frontend en los reportes 776 y 777.

---

## 6. Pendientes antes del pase a productivo

- Crear y maquetar el Smart Form `ZHHR_CP_SF_DOC` (incl. tratamiento de la imagen de firma).
- Confirmar y aplicar los valores de las preguntas abiertas (paquete, ADS vs Smart Forms, formato de importes, grupo de autorización, etc.).
- Traducir textos a inglés y portugués.
- Ejecutar **Code Inspector (SCI)** sobre cada objeto y corregir hallazgos.
- Cargar la regla `estandares-abap.mdc` y revisar el cumplimiento fino del estándar.
