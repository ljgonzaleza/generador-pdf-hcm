# Generador de documentos PDF HCM

Programa ABAP para S/4HANA 2023 que permite generar documentos PDF para empleados
a partir de plantillas mantenibles en productivo.

## Estructura
- `/docs` — Especificaciones funcionales y diseño técnico (SDD). NO viaja a SAP.
- `/src` — Código fuente ABAP en formato abapGit. Esto es lo que se importa a S/4.
- `/.cursor/rules` — Estándares de programación aplicados por Cursor. NO viaja a SAP.
- `.abapgit.xml` — Configuración de abapGit (paquete y carpeta de inicio).

## Nomenclatura
- Programas/reportes: ZHHRR_775+
- Transacciones: ZHHRT_775+
- Resto de objetos: Z..._CP_...
- Paquete único de desarrollo Z.
