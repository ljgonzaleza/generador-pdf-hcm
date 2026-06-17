# 03 — Preguntas Abiertas

Necesito aclarar estos puntos **antes de codificar**. Mientras no se confirmen, en `02-diseno-tecnico.md` figuran las **suposiciones por defecto** marcadas. No asumiré nada definitivo en estos puntos sin tu respuesta.

> La versión del sistema ya está fija (S/4HANA 2023) — no se pregunta por ella.

---

## A. Motor PDF y almacenamiento

**P-1. ¿Está ADS (Adobe Document Services) disponible y licenciado en este entorno?**
- Si **sí** → puedo usar **Adobe Forms** (mejor calidad de salida).
- Si **no** o no se sabe → uso **Smart Forms + OTF→PDF** (recomendación por defecto).

**P-2. Volumen y retención de PDFs generados.**
- ¿Cuántos documentos/año (aprox.) y cuánto tiempo deben conservarse?
- ¿Hay **ArchiveLink / Content Server** configurado y disponible?
- Esto decide entre almacenar el binario en tabla Z (por defecto) vs. ArchiveLink.

---

## B. Datos y formato

**P-3. Catálogo de placeholders inicial.**
- ¿Qué placeholders y campos concretos se usarán además del nombre/apellido de **PA0002**? (p. ej. fecha de ingreso PA0000/PA0001, posición, sueldo PA0008, documento de identidad, etc.)
- ¿Quieres que precargue un conjunto estándar de placeholders de ejemplo?

**P-4. Formato de fechas e importes (Perú).**
- Fechas: ¿`dd.mm.aaaa`, `dd/mm/aaaa`? ¿Y "fecha larga" tipo "17 de junio de 2026"?
- Importes: separador de miles/decimales y ¿símbolo de moneda (S/)?

**P-5. Idioma de las plantillas.**
- Confirmo que las **plantillas** son solo en **español** (los textos de *interfaz* de los programas sí llevan ES/EN/PT por estándar). ¿Correcto?

**P-14. Comportamiento ante placeholder sin dato.**
- Si el empleado no tiene el registro/campo a la fecha de referencia, ¿qué prefieres? (a) dejar en blanco y advertir [propuesta], (b) poner un guion "—", (c) impedir la generación.

---

## C. Firma e imagen

**P-6. Imagen de firma.**
- Formato (PNG/JPG), tamaño/resolución máximos.
- ¿Una sola firma por plantilla (modelo actual) o podría requerirse más de una?
- ¿Se requiere también **logo/membrete corporativo fijo** o **pie de página** en el PDF, además de la firma? (P-9)

---

## D. Objetos, paquete y transporte

**P-7. Paquete de desarrollo Z.**
- Nombre, descripción y **capa de software (software component)** del paquete único.
- Número/responsable de la **orden de transporte** a usar.

**P-8. Id de documento del histórico.**
- ¿Apruebas usar **rango de números** (`ZCP_DOCNR`, `DOC_ID` NUMC 12 correlativo)? ¿O prefieres GUID?

**P-10. Grupo de autorización de tablas (`S_TABU_DIS`).**
- ¿Qué valor de grupo de autorización asigno a las tablas Z en SE54?

**P-11. Códigos de transacción / correlativo.**
- ¿Confirmas que **775, 776 y 777** están libres y que el correlativo arranca en 775 para los tres programas, en este orden (plantillas / generación / históricos)?

**P-15. Menú de área (opcional).**
- ¿Quieres un **menú de área `ZHHR_CP_MENU`** que agrupe las tres transacciones para RRHH?

---

## E. Operación y segregación

**P-12. Mantenimiento técnico de respaldo.**
- Además del programa `ZHHRR_775`, ¿quieres **vistas de mantenimiento (SM30)** para firmantes/mapeo como respaldo técnico, o todo se mantiene solo desde el programa funcional?

**P-13. Vista previa del PDF.**
- ¿Es aceptable previsualizar el PDF en el **visor GUI estándar** (abrir el documento), o necesitas un **visor embebido** dentro de la pantalla del programa?

---

## F. Estándares / regla de Cursor

**P-16. Archivo de regla `estandares-abap.mdc` ausente.**
- En `.cursor/rules/` solo existe `_LEER.md`; **falta el archivo `estandares-abap.mdc`** con el estándar LATAM cargado como regla "Always".
- He trabajado con las convenciones resumidas en `requisitos.md`. Para la fase de código, ¿puedes **colocar el `estandares-abap.mdc`** (documento "Estándar de Desarrollos SAP S/4 v1.0") en esa carpeta? Así me aseguro de aplicar el detalle completo (no solo el resumen).

---

### Resumen de suposiciones por defecto (si no respondes)
1. Motor PDF: **Smart Forms + OTF→PDF**.
2. Almacenamiento PDF: **binario en tabla Z `ZHHR_CP_PDF`**.
3. Placeholder sin dato: **en blanco + aviso** antes de registrar.
4. Plantillas: **solo español**.
5. `DOC_ID`: **rango de números correlativo**.
6. Correlativo de programas/transacciones: **775 / 776 / 777**.

**No generaré código ABAP hasta que escribas explícitamente `CODIFICAR`.**
