*&---------------------------------------------------------------------*
*& Include ZHHRR_776_CLA : clase local de control
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS run.
  PRIVATE SECTION.
    DATA mo_svc TYPE REF TO zcl_cp_doc_service.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD run.
    DATA: lv_pdf TYPE xstring,
          lv_id  TYPE zde_cp_doc_id.

    mo_svc = NEW zcl_cp_doc_service( ).

    TRY.
        IF p_gen = abap_true.
          mo_svc->generate_and_log(
            EXPORTING iv_pernr  = p_pernr
                      iv_tpl_id = p_tplid
                      iv_date   = p_feref
            IMPORTING ev_doc_id = lv_id
                      ev_pdf    = lv_pdf ).
          MESSAGE s012(zhhr_cp_msg) WITH lv_id.
        ELSE.
          mo_svc->preview(
            EXPORTING iv_pernr   = p_pernr
                      iv_tpl_id  = p_tplid
                      iv_date    = p_feref
            IMPORTING ev_pdf     = lv_pdf
                      ev_version = DATA(lv_ver) ).
        ENDIF.

        zcl_cp_pdf_view=>display( iv_pdf = lv_pdf ).

      CATCH zcx_cp_error INTO DATA(lo_err).
        MESSAGE lo_err->get_text( ) TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

DATA go_app TYPE REF TO lcl_app.
