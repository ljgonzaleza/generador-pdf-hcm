*&---------------------------------------------------------------------*
*& Report ZHHRR_775
*&---------------------------------------------------------------------*
*& Descripción : Gestión de plantillas de documentos PDF HCM. Permite
*&               crear, editar, copiar y desactivar plantillas, con
*&               versionado (Borrador / Activa / Obsoleta), en PRD.
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*& Transacción : ZHHRT_775
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
REPORT zhhrr_775.

INCLUDE zhhrr_775_top.
INCLUDE zhhrr_775_sel.
INCLUDE zhhrr_775_cla.

START-OF-SELECTION.
  AUTHORITY-CHECK OBJECT 'S_TCODE' ID 'TCD' FIELD gc_tcode.
  IF sy-subrc <> 0.
    MESSAGE e014(zhhr_cp_msg) WITH gc_tcode.
  ENDIF.

  go_app = NEW lcl_app( ).
  go_app->run( ).
