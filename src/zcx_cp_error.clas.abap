*&---------------------------------------------------------------------*
*& Clase de excepción ZCX_CP_ERROR
*&---------------------------------------------------------------------*
*& Descripción : Excepción de aplicación del generador de documentos
*&               PDF HCM. Transporta un texto de error legible.
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
CLASS zcx_cp_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        !textid   LIKE textid   OPTIONAL
        !previous LIKE previous OPTIONAL
        !iv_text  TYPE string   OPTIONAL.

    METHODS get_text     REDEFINITION.
    METHODS get_longtext REDEFINITION.

  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.



CLASS zcx_cp_error IMPLEMENTATION.

  METHOD constructor.
    super->constructor( textid   = textid
                        previous = previous ).
    mv_text = iv_text.
  ENDMETHOD.

  METHOD get_text.
    result = mv_text.
  ENDMETHOD.

  METHOD get_longtext.
    result = mv_text.
  ENDMETHOD.

ENDCLASS.
