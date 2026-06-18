*&---------------------------------------------------------------------*
*& Clase ZCL_CP_DOC_SERVICE
*&---------------------------------------------------------------------*
*& Descripción : Orquesta la generación de documentos por persona.
*&               Lee la versión activa, resuelve placeholders, genera
*&               el PDF y, al confirmar, registra el documento.
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
CLASS zcl_cp_doc_service DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.

    "! Genera el PDF para vista previa (no registra histórico).
    METHODS preview
      IMPORTING
        !iv_pernr   TYPE pernr_d
        !iv_tpl_id  TYPE zde_cp_tpl_id
        !iv_date    TYPE datum
      EXPORTING
        !ev_pdf     TYPE xstring
        !ev_version TYPE zde_cp_tpl_ver
      RAISING
        zcx_cp_error.

    "! Genera el PDF y registra el documento en el histórico.
    METHODS generate_and_log
      IMPORTING
        !iv_pernr  TYPE pernr_d
        !iv_tpl_id TYPE zde_cp_tpl_id
        !iv_date   TYPE datum
      EXPORTING
        !ev_doc_id TYPE zde_cp_doc_id
        !ev_pdf    TYPE xstring
      RAISING
        zcx_cp_error.

  PRIVATE SECTION.
    DATA:
      mo_tpl  TYPE REF TO zcl_cp_tpl_manager,
      mo_res  TYPE REF TO zcl_cp_ph_resolver,
      mo_firm TYPE REF TO zcl_cp_firma,
      mo_pdf  TYPE REF TO zcl_cp_pdf_builder.

    METHODS next_doc_id
      RETURNING VALUE(rv_doc_id) TYPE zde_cp_doc_id.
ENDCLASS.



CLASS zcl_cp_doc_service IMPLEMENTATION.

  METHOD constructor.
    mo_tpl  = NEW zcl_cp_tpl_manager( ).
    mo_res  = NEW zcl_cp_ph_resolver( ).
    mo_firm = NEW zcl_cp_firma( ).
    mo_pdf  = NEW zcl_cp_pdf_builder( ).
  ENDMETHOD.


  METHOD preview.
    DATA: ls_version TYPE zhhr_cp_tplv,
          lt_lines   TYPE zcl_cp_tpl_manager=>tt_tplt,
          lt_map     TYPE zcl_cp_tpl_manager=>tt_map,
          lt_text    TYPE zcl_cp_ph_resolver=>tt_tdline.

    DATA(lv_version) = mo_tpl->get_active_version( iv_tpl_id ).

    mo_tpl->read_version(
      EXPORTING iv_tpl_id  = iv_tpl_id
                iv_version = lv_version
      IMPORTING es_version = ls_version
                et_lines   = lt_lines
                et_map     = lt_map ).

    DATA(lt_values) = mo_res->resolve( iv_pernr = iv_pernr
                                       iv_date  = iv_date
                                       it_map   = lt_map ).

    LOOP AT lt_lines INTO DATA(ls_line).
      APPEND ls_line-tdline TO lt_text.
    ENDLOOP.

    DATA(lt_sub) = mo_res->substitute( it_lines  = lt_text
                                       it_values = lt_values ).

    DATA(ls_firm) = mo_firm->read( ls_version-firm_id ).

    ev_pdf = mo_pdf->build( iv_titulo = ls_version-titulo
                            it_lines  = lt_sub
                            is_firm   = ls_firm ).
    ev_version = lv_version.
  ENDMETHOD.


  METHOD generate_and_log.
    DATA: ls_dlog TYPE zhhr_cp_dlog,
          ls_pdf  TYPE zhhr_cp_pdf.

    preview(
      EXPORTING iv_pernr   = iv_pernr
                iv_tpl_id  = iv_tpl_id
                iv_date    = iv_date
      IMPORTING ev_pdf     = ev_pdf
                ev_version = DATA(lv_version) ).

    " Asignación de DOC_ID con reintento ante colisión de clave
    DO 5 TIMES.
      DATA(lv_id) = next_doc_id( ).

      ls_dlog = VALUE #( doc_id    = lv_id
                         pernr     = iv_pernr
                         tpl_id    = iv_tpl_id
                         version   = lv_version
                         fecha_ref = iv_date
                         fecha_gen = sy-datum
                         hora_gen  = sy-uzeit
                         usuario   = sy-uname ).
      INSERT zhhr_cp_dlog FROM @ls_dlog.
      IF sy-subrc = 0.
        ls_pdf = VALUE #( doc_id   = lv_id
                          filename = |DOC_{ lv_id }.pdf|
                          filesize = xstrlen( ev_pdf )
                          pdf      = ev_pdf ).
        INSERT zhhr_cp_pdf FROM @ls_pdf.
        IF sy-subrc <> 0.
          DELETE FROM zhhr_cp_dlog WHERE doc_id = @lv_id.
          MESSAGE e007(zhhr_cp_msg) INTO DATA(lv_msg).
          RAISE EXCEPTION TYPE zcx_cp_error EXPORTING iv_text = lv_msg.
        ENDIF.

        COMMIT WORK AND WAIT.
        ev_doc_id = lv_id.
        RETURN.
      ENDIF.
    ENDDO.

    MESSAGE e007(zhhr_cp_msg) INTO lv_msg.
    RAISE EXCEPTION TYPE zcx_cp_error EXPORTING iv_text = lv_msg.
  ENDMETHOD.


  METHOD next_doc_id.
    SELECT MAX( doc_id ) FROM zhhr_cp_dlog INTO @DATA(lv_max).
    rv_doc_id = lv_max + 1.
  ENDMETHOD.

ENDCLASS.