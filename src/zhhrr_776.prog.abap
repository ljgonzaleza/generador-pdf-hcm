*&---------------------------------------------------------------------*
*& Report ZHHRR_776
*&---------------------------------------------------------------------*
*& Descripción : Generación de documentos PDF HCM por persona. Lee la
*&               plantilla activa, resuelve placeholders, previsualiza
*&               y/o registra el documento generado.
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*& Transacción : ZHHRT_776
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
REPORT zhhrr_776.

INCLUDE zhhrr_776_top.
INCLUDE zhhrr_776_sel.
INCLUDE zhhrr_776_cla.

START-OF-SELECTION.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
  IF sy-subrc <> 0.
    MESSAGE e014(zhhr_cp_msg) WITH gc_tcode.
  ENDIF.

  go_app = NEW lcl_app( ).
  go_app->run( ).
