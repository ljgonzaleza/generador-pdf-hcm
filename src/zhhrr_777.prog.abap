*&---------------------------------------------------------------------*
*& Report ZHHRR_777
*&---------------------------------------------------------------------*
*& Descripción : Consulta de históricos de documentos PDF HCM. Lista
*&               ALV de documentos generados con reapertura del PDF.
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*& Transacción : ZHHRT_777
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
REPORT zhhrr_777.

INCLUDE zhhrr_777_top.
INCLUDE zhhrr_777_sel.
INCLUDE zhhrr_777_cla.

START-OF-SELECTION.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
  IF sy-subrc <> 0.
    MESSAGE e014(zhhr_cp_msg) WITH gc_tcode.
  ENDIF.

  go_app = NEW lcl_app( ).
  go_app->run( ).
