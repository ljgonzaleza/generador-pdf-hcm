*&---------------------------------------------------------------------*
*& Include ZHHRR_777_CLA : clase local de control
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS run.

  PRIVATE SECTION.
    DATA:
      mo_hist TYPE REF TO zcl_cp_doc_history,
      mt_rows TYPE zcl_cp_doc_history=>tt_rows,
      mo_alv  TYPE REF TO cl_salv_table.

    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING !row !column.

    METHODS show_pdf
      IMPORTING !iv_doc_id TYPE zde_cp_doc_id.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD run.
    mo_hist = NEW zcl_cp_doc_history( ).

    mt_rows = mo_hist->search(
      it_pernr = s_pernr[]
      it_tplid = s_tplid[]
      it_fecha = s_fegen[]
      it_user  = s_usuar[] ).

    IF mt_rows IS INITIAL.
      MESSAGE s013(zhhr_cp_msg) DISPLAY LIKE 'I'.
      RETURN.
    ENDIF.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = mo_alv
          CHANGING  t_table      = mt_rows ).
      CATCH cx_salv_msg INTO DATA(lo_msg).
        MESSAGE lo_msg->get_text( ) TYPE 'I'.
        RETURN.
    ENDTRY.

    mo_alv->get_functions( )->set_all( ).
    mo_alv->get_columns( )->set_optimize( abap_true ).

    SET HANDLER on_double_click FOR mo_alv->get_event( ).

    mo_alv->display( ).
  ENDMETHOD.


  METHOD on_double_click.
    READ TABLE mt_rows INTO DATA(ls_row) INDEX row.
    IF sy-subrc = 0.
      show_pdf( ls_row-doc_id ).
    ENDIF.
  ENDMETHOD.


  METHOD show_pdf.
    TRY.
        mo_hist->get_pdf(
          EXPORTING iv_doc_id   = iv_doc_id
          IMPORTING ev_pdf      = DATA(lv_pdf)
                    ev_filename = DATA(lv_fn) ).

        zcl_cp_pdf_view=>display(
          iv_pdf      = lv_pdf
          iv_filename = CONV string( lv_fn ) ).

      CATCH zcx_cp_error INTO DATA(lo_err).
        MESSAGE lo_err->get_text( ) TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

DATA go_app TYPE REF TO lcl_app.
