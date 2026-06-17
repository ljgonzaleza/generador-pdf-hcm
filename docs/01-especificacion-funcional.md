# 01 — Especificación Funcional

**Proyecto:** Generador de documentos PDF HCM
**Sistema:** SAP S/4HANA 2023 (ABAP Platform 7.58) · módulo HCM (infotipos PA clásicos) · MOLGA PE (Perú)
**UI:** SAP GUI clásico (Dynpro / ALV OO). Sin Fiori, RAP, CDS de UI ni OData.
**Alcance:** únicamente las tres funcionalidades descritas. Sin generación masiva, sin multilenguaje de documentos, sin firma digital, sin workflows.

> Este documento describe el **qué** (flujos, pantallas y reglas de negocio). El **cómo** (objetos, tablas, clases) está en `02-diseno-tecnico.md`. Las dudas pendientes están en `03-preguntas-abiertas.md`.

---

## 1. Visión general

La solución es un conjunto de **tres programas ejecutables** (reportes tipo 1) con su transacción Z asociada, pensados para personal de RRHH sin perfil técnico:

| # | Funcionalidad | Para qué sirve |
|---|---------------|----------------|
| 1 | **Gestión de plantillas** | Crear/editar/copiar/desactivar las plantillas de documentos directamente en productivo, sin transporte por cada documento nuevo. |
| 2 | **Generación de documentos por persona** | Elegir un empleado y una plantilla activa, previsualizar y generar el PDF. |
| 3 | **Consulta de históricos** | Listar los documentos generados, volver a verlos/descargarlos y consultar versiones anteriores de plantillas. |

**Idea central del diseño:** la *plantilla* (texto + placeholders + mapeo + firma) se guarda como **dato de aplicación en tablas Z** (editable en PRD sin orden de transporte). El *motor PDF* es una "cáscara" genérica única que recibe el texto ya resuelto y lo renderiza; esa cáscara sí viaja por transporte, pero **no hay que transportar nada cuando se crea o modifica una plantilla**.

---

## 2. Funcionalidad 1 — Gestión de plantillas

### 2.1 Objetivo
Permitir que un usuario funcional cree y mantenga plantillas de documentos (certificados, cartas, constancias) en PRD, con placeholders que luego se rellenan con datos del empleado.

### 2.2 Conceptos
- **Plantilla:** entidad lógica con un identificador y una descripción (p. ej. `CERT_TRAB` = "Constancia de trabajo").
- **Versión:** cada cambio relevante genera una nueva versión. Una plantilla tiene N versiones; **a lo sumo una versión Activa** a la vez.
- **Estados de versión:**
  - **Borrador (B):** en edición; no se puede usar para generar.
  - **Activa (A):** vigente; es la única que se ofrece al generar documentos.
  - **Obsoleta (O):** versión anterior, conservada solo para histórico/consulta.
- **Placeholder:** marcador de texto `{{NOMBRE}}`, `{{APELLIDO}}`, `{{FECHA_INGRESO}}`, etc.
- **Mapeo:** relación placeholder → campo de infotipo (p. ej. `NOMBRE = PA0002-VORNA`) + tipo de formato.
- **Firmante:** datos de la persona que firma (nombre, cargo) e imagen de firma; configurable por plantilla.

### 2.3 Pantallas propuestas (descripción textual)

**P1.1 — Lista de plantillas (pantalla inicial, ALV OO)**
- Columnas: Id plantilla, Descripción, Versión activa, Estado de la versión activa, Modificado por, Modificado el.
- Barra de botones: **Crear**, **Editar**, **Copiar**, **Desactivar**, **Ver versiones**, **Refrescar**.
- Selección de una fila para aplicar la acción.

**P1.2 — Editor de plantilla (Dynpro)**
- **Cabecera:** Id plantilla (solo lectura al editar), Descripción, Firmante (ayuda de búsqueda contra el catálogo de firmantes), Versión y Estado (informativos).
- **Cuerpo del documento:** editor de texto multilínea (control de edición de texto) donde se escribe el contenido con placeholders `{{...}}`.
- **Mapeo de placeholders (ALV editable / table control):** Placeholder, Infotipo (p. ej. `0002`), Campo (p. ej. `VORNA`), Tipo de formato (Texto / Fecha / Fecha larga / Importe).
- Barra de botones: **Guardar** (graba en estado Borrador), **Validar placeholders** (comprueba que todo `{{...}}` del cuerpo tenga su mapeo), **Activar**, **Cancelar**.

**P1.3 — Versiones de la plantilla (ALV OO)**
- Columnas: Versión, Estado, Creada por, Creada el, Modificada por, Modificada el.
- Acción: visualizar el contenido de una versión (solo lectura).

### 2.4 Flujos

**Crear plantilla**
1. En P1.1 → botón **Crear**.
2. Se abre P1.2 vacío; el usuario indica Id y Descripción, redacta el cuerpo, define el mapeo y elige firmante.
3. **Guardar** → se crea la plantilla con la **versión 1 en estado Borrador**.
4. **Activar** (opcional, tras validar placeholders) → la versión pasa a **Activa**.

**Editar plantilla**
1. En P1.1 → seleccionar plantilla → **Editar**.
2. Si la versión vigente está **Activa**, al guardar cambios se crea **una nueva versión en Borrador** (la Activa sigue vigente hasta que se active la nueva). Si ya estaba en Borrador, se actualiza esa misma versión.
3. **Activar** la nueva versión → la versión anteriormente Activa pasa a **Obsoleta** y la nueva queda **Activa**.

**Copiar plantilla**
1. En P1.1 → seleccionar → **Copiar**.
2. Se solicita un nuevo Id; se duplica el contenido, mapeo y firmante de la versión Activa (o la última) en una **nueva plantilla, versión 1, estado Borrador**.

**Desactivar plantilla**
1. En P1.1 → seleccionar → **Desactivar**.
2. La versión Activa pasa a **Obsoleta**; la plantilla queda sin versión activa (no se puede generar hasta activar alguna).

### 2.5 Reglas de negocio (Funcionalidad 1)
- RN-1.1 Solo puede existir **una versión Activa** por plantilla.
- RN-1.2 Activar una versión obsoletea automáticamente la que estaba Activa.
- RN-1.3 No se permite activar una versión con placeholders en el cuerpo que **no tengan mapeo** (validación obligatoria antes de activar).
- RN-1.4 Las versiones Obsoletas son de **solo lectura** (no editables ni reactivables; para "recuperarlas" se copia su contenido a una nueva versión).
- RN-1.5 Cada operación de grabación registra **usuario y fecha/hora** de creación y de última modificación.
- RN-1.6 Las plantillas, versiones, mapeos y firmantes son **datos de aplicación**: se crean/modifican en PRD **sin orden de transporte**.

---

## 3. Funcionalidad 2 — Generación de documentos por persona

### 3.1 Objetivo
Generar el PDF de un empleado a partir de una plantilla Activa, con vista previa y opciones de visualizar / imprimir / descargar, dejando registro de cada documento generado.

### 3.2 Pantallas propuestas

**P2.1 — Pantalla de selección**
- `P_PERNR` — Número de personal (parámetro, obligatorio, con ayuda de búsqueda estándar de empleado).
- `P_TPLID` — Plantilla (parámetro, ayuda de búsqueda que **solo lista plantillas con versión Activa**).
- `P_FEREF` — Fecha de referencia (parámetro, valor por defecto = fecha del día). Determina el registro de infotipo vigente.

> Nota: según los requisitos, el único control de acceso es a nivel de transacción (`S_TCODE`). **No hay** parámetros ni validaciones de autorización por PERNR, sociedad, área de personal ni unidad organizativa.

**P2.2 — Vista previa / acciones (Dynpro con visor)**
- Área de previsualización del PDF generado.
- Botones: **Visualizar**, **Imprimir**, **Descargar** (guardar archivo local), **Generar y registrar** (confirma y deja el documento en el histórico).

### 3.3 Flujo
1. El usuario informa PERNR, plantilla y fecha de referencia → ejecutar.
2. El sistema lee la **versión Activa** de la plantilla y su mapeo.
3. Para cada placeholder se lee el **registro de infotipo vigente a la fecha de referencia** (`BEGDA ≤ fecha ≤ ENDDA`) y se aplica el formato configurado.
4. Se sustituyen los placeholders en el cuerpo, se inserta la **imagen de firma** del firmante y se renderiza el **PDF** mediante el motor único.
5. Se muestra la **vista previa** (P2.2).
6. Al **Generar y registrar**, se guarda el registro en el histórico (empleado, plantilla, versión usada, fecha, usuario) y se almacena el PDF para reapertura posterior.

### 3.4 Reglas de negocio (Funcionalidad 2)
- RN-2.1 Solo se permiten plantillas con **versión Activa**; la versión usada queda fijada en el registro histórico.
- RN-2.2 La lectura de datos usa el **registro vigente a la fecha de referencia**; si no hay registro vigente para el infotipo requerido, ver RN-2.3.
- RN-2.3 **Placeholder sin dato** (empleado sin ese registro/campo): comportamiento a confirmar (ver `03-preguntas-abiertas.md`, P-14). Propuesta por defecto: dejar el placeholder en blanco y advertir al usuario antes de registrar.
- RN-2.4 **Placeholder sin mapeo**: no debería ocurrir si la plantilla se activó (RN-1.3); si ocurre, se trata igual que "sin dato" y se advierte.
- RN-2.5 Formateo: fechas e importes según el tipo de formato del mapeo (formato concreto a confirmar, P-4).
- RN-2.6 La vista previa **no** crea registro histórico; solo lo crea **Generar y registrar**.

---

## 4. Funcionalidad 3 — Consulta de históricos

### 4.1 Objetivo
Consultar los documentos ya generados, volver a visualizarlos/descargarlos y revisar versiones anteriores de plantillas.

### 4.2 Pantallas propuestas

**P3.1 — Pantalla de selección (filtros)**
- `S_PERNR` — Empleado (select-option).
- `S_TPLID` — Plantilla (select-option).
- `S_FEGEN` — Fecha de generación (select-option / rango).
- `S_USUAR` — Usuario que generó (select-option).

**P3.2 — Lista de documentos generados (ALV OO)**
- Columnas: Id documento, Empleado (PERNR y nombre), Plantilla, Versión usada, Fecha y hora de generación, Usuario.
- Acciones: **doble clic / Visualizar PDF** (reabre el PDF almacenado), **Descargar**, **Ver versión de plantilla usada** (abre el contenido de esa versión en solo lectura).

### 4.3 Reglas de negocio (Funcionalidad 3)
- RN-3.1 El histórico es de **solo consulta** (no se editan ni borran registros desde esta funcionalidad).
- RN-3.2 La reapertura muestra el **PDF tal como se generó** (no se regenera con datos actuales), para garantizar trazabilidad.
- RN-3.3 Se puede consultar cualquier versión de plantilla (Activa, Borrador u Obsoleta) en modo lectura.

---

## 5. Reglas transversales
- RT-1 **Autorización:** únicamente `AUTHORITY-CHECK` del objeto `S_TCODE` al inicio de cada programa; si falla, salida inmediata. **Sin** chequeos por PERNR ni datos HR.
- RT-2 **Idioma de documentos:** español (Perú). Los textos de la *interfaz* de los programas (parámetros, títulos, columnas) sí deben tener traducción ES/EN/PT por estándar LATAM.
- RT-3 **Simplicidad:** no se añaden funcionalidades fuera de estas tres.
- RT-4 **Trazabilidad:** toda creación/modificación de plantillas y toda generación de documento registra usuario y fecha/hora.
