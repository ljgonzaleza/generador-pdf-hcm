# Prompt para Cursor — Generador de documentos PDF HCM en ABAP S/4HANA (versión simple)

Actúa como un desarrollador ABAP senior, especializado en S/4HANA y SAP HCM. Vamos a diseñar un programa a medida, simple y pragmático. **En esta primera fase NO escribas código**: tu entregable son las especificaciones y el diseño técnico. Solo generarás código cuando yo lo solicite explícitamente.

## Contexto

- Sistema: SAP S/4HANA **versión 2023** (on-premise / Private Cloud), módulo HCM activo con infotipos PA clásicos (tablas PAnnnn). Todo el diseño y las construcciones de lenguaje deben ser compatibles con el release ABAP de S/4HANA 2023 (ABAP Platform 2023 / 7.58): se puede usar sintaxis ABAP moderna (expresiones inline, VALUE, COND, string templates), pero NO funcionalidades exclusivas de BTP/Steampunk ni de releases posteriores.
- Usuarios finales: personal de RRHH sin perfil técnico.
- País: Perú (agrupación de país / MOLGA PE).
- UI: SAP GUI clásico (Dynpro / ALV). **NO usar Fiori, RAP, CDS de UI ni OData.** Mantenerlo simple.

## Objetivo

Un programa que permita generar documentos PDF para empleados (certificados, cartas, constancias) a partir de plantillas mantenibles **directamente en productivo** por usuarios funcionales, sin transportes por cada documento nuevo.

## Funcionalidades (solo estas tres, no agregar más)

1. **Gestión de plantillas**
   - Crear, editar, copiar y desactivar plantillas desde el sistema productivo.
   - Las plantillas se almacenan como datos de aplicación (tablas Z tipo dato maestro, no customizing), editables en PRD sin orden de transporte.
   - Texto con placeholders de datos, p. ej. `{{NOMBRE}}`, `{{APELLIDO}}`.
   - Mapeo configurable de placeholders a campos de infotipos, mantenible por el usuario: ej. `NOMBRE = PA0002-VORNA`, `APELLIDO = PA0002-NACHN`. Lectura del registro vigente a la fecha. Formateo básico de fechas e importes.
   - Inserción de imagen de firma (firmante configurable por plantilla).
   - Versionamiento simple de plantillas: cada cambio genera nueva versión, estados Borrador / Activa / Obsoleta, registro de usuario y fecha de modificación.

2. **Generación de documentos por persona**
   - Selección de un empleado (PERNR), selección de plantilla activa, vista previa y generación del PDF (visualizar, imprimir, descargar).
   - Proponer el motor de PDF más simple disponible: evaluar Adobe Forms (si hay ADS) vs. Smart Forms / OTF como alternativa. Justificar brevemente.
   - Guardar registro de cada documento generado.

3. **Consulta de históricos**
   - Listado ALV de documentos generados: empleado, plantilla y versión usada, fecha, usuario.
   - Posibilidad de volver a visualizar/descargar el PDF generado.
   - Consulta de versiones anteriores de plantillas.

## Requisitos no funcionales

- **Autorizaciones**: el control de acceso será únicamente a nivel de transacción (AUTHORITY-CHECK del objeto S_TCODE al inicio del programa). **NO debe haber authority check por número de personal ni por datos HR**: sin P_PERNR, sin P_ORGIN, sin restricciones por sociedad, área de personal o unidad organizativa, ni objetos de autorización Z. Cualquier usuario con acceso a la transacción puede generar documentos para cualquier PERNR sin validación adicional.
- **Paquete único**: TODOS los objetos (tablas, clases, programas, transacciones, elementos de datos, dominios) deben guardarse en un único paquete de desarrollo Z. Sin subpaquetes ni objetos en $TMP.
- **Estándares LATAM**: aplicar obligatoriamente el documento "Estándar de Desarrollos SAP S/4 v1.0" de Grupo LATAM Airlines incluido en este proyecto como regla (`estandares-abap.mdc`). Convenciones clave que deben respetarse:
  - Variables: prefijos `g_`/`l_` (variables), `gt_`/`lt_` (tablas internas), `gwa_`/`lwa_` (work areas), `gc_`/`lc_` (constantes), `gr_`/`lr_` (rangos), `go_`/`lo_` (objetos); parámetros de pantalla de selección `P_` y select-options `S_`.
  - Includes con sufijos `_TOP`, `_SEL`, `_CLA`, `_F00`.
  - Elementos de datos `ZDE_*`, dominios `ZDO_*`.
  - Cabecera de documentación obligatoria en cada programa (descripción, fecha de creación, creador, empresa LATAM, histórico de modificaciones con marcas @001, @002...).
  - Idioma oficial de comentarios y documentación: español. Todos los textos (parámetros, títulos, columnas) deben tener traducción a inglés y portugués (requisito para pasar a productivo).
  - Sin textos hardcodeados, sin `SELECT *`, sin breakpoints.
  - **Tratamiento de errores (obligatorio en todos los programas)**: toda sentencia que modifique el valor del sistema SY-SUBRC debe tener una validación inmediata en caso de error, para evitar terminaciones no deseadas del programa. Usar TRY/CATCH (y las clases de excepción correspondientes, p. ej. CX_SY_FILE_* para archivos, CX_SY_ARITHMETIC_* en operaciones matemáticas) para evitar errores en tiempo de ejecución. Ningún SELECT, READ TABLE, CALL FUNCTION u operación crítica queda sin validar.
  - ALV con orientación a objetos: `CL_GUI_CUSTOM_CONTAINER` (y `CL_GUI_DOCKING_CONTAINER` si se ejecuta en fondo).
  - AUTHORITY-CHECK al inicio del programa con validación inmediata de SY-SUBRC y salida con LEAVE PROGRAM si falla (recordar: SOLO objeto S_TCODE, ningún chequeo por número de personal).
  - Mantenedores de tablas Z generados desde SE11 con grupo de autorización asignado.
  - Code Inspector (SCI) limpio para cada objeto.
- **Programas ejecutables y nomenclatura**: la solución debe implementarse como programas ejecutables (reportes tipo 1, ejecutables vía SE38/transacción Z) para S/4HANA. Según el estándar LATAM, la nomenclatura es `Z` + Frente Funcional (`H` = Recursos Humanos) + Módulo (`HR`) + Tipo + `_` + correlativo, donde el correlativo parte en **775** y avanza consecutivamente:
  - **Programas/reportes**: tipo `R` (Reportes) o `D` (Desarrollo) según corresponda → `ZHHRR_775`, `ZHHRR_776`, ... SIN identificador CP.
  - **Transacciones**: tipo `T` → `ZHHRT_775`, `ZHHRT_776`, ... (cada transacción asociada a su programa con el mismo correlativo).
  - **Includes**: nombre del programa + sufijo estándar → `ZHHRR_775_TOP`, `ZHHRR_775_SEL`, `ZHHRR_775_CLA`, `ZHHRR_775_F00`.
  - **Resto de objetos** (tablas, estructuras, clases, elementos de datos): incluir el identificador `CP` separado por guión bajo, patrón `Z..._CP_...`, manteniendo las convenciones del estándar LATAM para cada tipo de objeto.
  - Proponer en el diseño técnico la asignación completa: qué programa corresponde a cada funcionalidad (plantillas, generación, históricos), su transacción Z asociada y la lista de objetos con sus nombres definitivos para mi validación antes de codificar.
- **Estándares generales**: ABAP orientado a objetos donde aporte claridad, sin sobre-ingeniería. Compatible con abapGit.
- **Simplicidad**: priorizar la solución más simple que cumpla. No agregar funcionalidades no solicitadas (sin generación masiva, sin multilenguaje, sin firma digital, sin workflows).

## Entregables de esta fase (sin código)

1. **Especificación funcional breve**: flujos de las tres funcionalidades, pantallas propuestas (descripción textual), reglas de negocio.
2. **Diseño técnico**:
   - Modelo de datos: tablas Z con campos clave y relaciones (plantillas, versiones, mapeo de campos, firmas, log de documentos).
   - Objetos a crear: lista de programas ejecutables con su número asignado (ZHHRR_775 en adelante), transacciones Z asociadas (ZHHRT_775 en adelante), y demás objetos con nomenclatura `Z..._CP_...`, con las clases principales y sus responsabilidades.
   - Recomendación del motor de PDF y de almacenamiento de los PDFs generados, con justificación breve.
   - Qué viaja por transporte y qué se mantiene en PRD.
3. **Preguntas abiertas**: lo que necesites aclarar antes de codificar (disponibilidad de ADS, etc.). La versión del sistema ya está definida: S/4HANA 2023, no preguntar por ella.

## Reglas de trabajo

- No generes código ABAP hasta que yo escriba explícitamente "CODIFICAR".
- Si una decisión depende de información que no tienes, pregunta antes de asumir.
- En la fase de código, el proyecto se estructurará en formato abapGit.
- Responde en español.
