*&---------------------------------------------------------------------*
*& Include ZHHRR_775_CLA : clase local de control
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS run.

  PRIVATE SECTION.
    DATA:
      mo_tpl  TYPE REF TO zcl_cp_tpl_manager,
      mt_list TYPE zcl_cp_tpl_manager=>tt_tplh.

    METHODS show_list.
    METHODS edit_template   IMPORTING !iv_tpl_id TYPE zde_cp_tpl_id.
    METHODS copy_template.
    METHODS deactivate_template.

    METHODS ask_tpl_id
      EXPORTING !ev_tpl_id TYPE zde_cp_tpl_id
                !ev_ok     TYPE abap_bool.

    METHODS ask_header
      EXPORTING !ev_ok     TYPE abap_bool
      CHANGING  !cv_descr  TYPE zde_cp_tpl_txt
                !cv_titulo TYPE zde_cp_tpl_txt
                !cv_firm   TYPE zde_cp_firm_id.

    METHODS edit_body
      EXPORTING !ev_ok    TYPE abap_bool
      CHANGING  !ct_tline TYPE zcl_cp_tpl_manager=>tt_tline.

    METHODS edit_map
      IMPORTING !it_tline TYPE zcl_cp_tpl_manager=>tt_tline
      CHANGING  !ct_map   TYPE zcl_cp_tpl_manager=>tt_map.

    METHODS parse_placeholders
      IMPORTING !it_tline    TYPE zcl_cp_tpl_manager=>tt_tline
      RETURNING VALUE(rt_ph) TYPE string_table.

    METHODS popup_confirm
      IMPORTING !iv_q        TYPE string
      RETURNING VALUE(rv_ok) TYPE abap_bool.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD run.
    mo_tpl = NEW zcl_cp_tpl_manager( ).

    CASE abap_true.
      WHEN r_new.   edit_template( '' ).
      WHEN r_edit.  edit_template( p_tpl ).
      WHEN r_copy.  copy_template( ).
      WHEN r_deact. deactivate_template( ).
      WHEN OTHERS.  show_list( ).
    ENDCASE.
  ENDMETHOD.


  METHOD show_list.
    mt_list = mo_tpl->get_list( ).
    IF mt_list IS INITIAL.
      MESSAGE s022(zhhr_cp_msg) DISPLAY LIKE 'I'.
      RETURN.
    ENDIF.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = DATA(lo_alv)
          CHANGING  t_table      = mt_list ).
        lo_alv->get_functions( )->set_all( ).
        lo_alv->get_columns( )->set_optimize( abap_true ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lo_msg).
        MESSAGE lo_msg->get_text( ) TYPE 'I'.
    ENDTRY.
  ENDMETHOD.


  METHOD edit_template.
    DATA: lv_tpl   TYPE zde_cp_tpl_id,
          lv_descr TYPE zde_cp_tpl_txt,
          lv_tit   TYPE zde_cp_tpl_txt,
          lv_firm  TYPE zde_cp_firm_id,
          lv_ok    TYPE abap_bool,
          lt_tline TYPE zcl_cp_tpl_manager=>tt_tline,
          lt_map   TYPE zcl_cp_tpl_manager=>tt_map,
          ls_ver   TYPE zhhr_cp_tplv,
          lt_lines TYPE zcl_cp_tpl_manager=>tt_tplt.

    lv_tpl = iv_tpl_id.

    TRY.
        IF lv_tpl IS NOT INITIAL.
          DATA(lt_vers) = mo_tpl->get_versions( lv_tpl ).
          IF lt_vers IS INITIAL.
            MESSAGE e001(zhhr_cp_msg) WITH lv_tpl.
          ENDIF.
          DATA(lv_lastver) = lt_vers[ lines( lt_vers ) ]-version.
          mo_tpl->read_version(
            EXPORTING iv_tpl_id  = lv_tpl
                      iv_version = lv_lastver
            IMPORTING es_version = ls_ver
                      et_lines   = lt_lines
                      et_map     = lt_map ).
          lv_tit  = ls_ver-titulo.
          lv_firm = ls_ver-firm_id.
          LOOP AT lt_lines INTO DATA(ls_l).
            APPEND VALUE #( tdformat = ls_l-tdformat
                            tdline   = ls_l-tdline ) TO lt_tline.
          ENDLOOP.
          mt_list = mo_tpl->get_list( ).
          READ TABLE mt_list INTO DATA(ls_h) WITH KEY tpl_id = lv_tpl.
          IF sy-subrc = 0.
            lv_descr = ls_h-descr.
          ENDIF.
        ELSE.
          ask_tpl_id( IMPORTING ev_tpl_id = lv_tpl ev_ok = lv_ok ).
          IF lv_ok = abap_false.
            RETURN.
          ENDIF.
        ENDIF.

        ask_header( IMPORTING ev_ok     = lv_ok
                    CHANGING  cv_descr  = lv_descr
                              cv_titulo = lv_tit
                              cv_firm   = lv_firm ).
        IF lv_ok = abap_false.
          MESSAGE s016(zhhr_cp_msg) DISPLAY LIKE 'I'.
          RETURN.
        ENDIF.

        edit_body( IMPORTING ev_ok = lv_ok CHANGING ct_tline = lt_tline ).
        IF lv_ok = abap_false.
          RETURN.
        ENDIF.

        edit_map( EXPORTING it_tline = lt_tline CHANGING ct_map = lt_map ).

        DATA(lv_newver) = mo_tpl->save_draft(
          iv_tpl_id  = lv_tpl
          iv_descr   = lv_descr
          iv_titulo  = lv_tit
          iv_firm_id = lv_firm
          it_tline   = lt_tline
          it_map     = lt_map ).

        IF popup_confirm( |¿Activar la versión { lv_newver } de { lv_tpl }?| ) = abap_true.
          mo_tpl->activate( iv_tpl_id = lv_tpl iv_version = lv_newver ).
          MESSAGE s020(zhhr_cp_msg) WITH lv_tpl lv_newver.
        ELSE.
          MESSAGE s019(zhhr_cp_msg) WITH lv_tpl lv_newver.
        ENDIF.

      CATCH zcx_cp_error INTO DATA(lo_err).
        MESSAGE lo_err->get_text( ) TYPE 'I'.
    ENDTRY.
  ENDMETHOD.


  METHOD copy_template.
    DATA: lv_dest TYPE zde_cp_tpl_id,
          lv_ok   TYPE abap_bool.

    IF p_tpl IS INITIAL.
      MESSAGE s008(zhhr_cp_msg) WITH 'P_TPL' DISPLAY LIKE 'I'.
      RETURN.
    ENDIF.

    ask_tpl_id( IMPORTING ev_tpl_id = lv_dest ev_ok = lv_ok ).
    IF lv_ok = abap_false.
      RETURN.
    ENDIF.

    TRY.
        mo_tpl->copy( iv_src = p_tpl iv_dest = lv_dest ).
        MESSAGE s019(zhhr_cp_msg) WITH lv_dest '0001'.
      CATCH zcx_cp_error INTO DATA(lo_err).
        MESSAGE lo_err->get_text( ) TYPE 'I'.
    ENDTRY.
  ENDMETHOD.


  METHOD deactivate_template.
    IF p_tpl IS INITIAL.
      MESSAGE s008(zhhr_cp_msg) WITH 'P_TPL' DISPLAY LIKE 'I'.
      RETURN.
    ENDIF.

    IF popup_confirm( |¿Desactivar la plantilla { p_tpl }?| ) = abap_false.
      RETURN.
    ENDIF.

    TRY.
        mo_tpl->deactivate( p_tpl ).
        MESSAGE s021(zhhr_cp_msg) WITH p_tpl.
      CATCH zcx_cp_error INTO DATA(lo_err).
        MESSAGE lo_err->get_text( ) TYPE 'I'.
    ENDTRY.
  ENDMETHOD.


  METHOD ask_tpl_id.
    DATA: lt_fields TYPE TABLE OF sval,
          lv_rc     TYPE c LENGTH 1.

    APPEND VALUE #( tabname   = 'ZHHR_CP_TPLH'
                    fieldname = 'TPL_ID'
                    field_obl = 'X' ) TO lt_fields.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title = 'Identificador de plantilla'
      IMPORTING
        returncode  = lv_rc
      TABLES
        fields      = lt_fields
      EXCEPTIONS
        OTHERS      = 1.
    IF sy-subrc <> 0 OR lv_rc = 'A'.
      ev_ok = abap_false.
      RETURN.
    ENDIF.

    READ TABLE lt_fields INTO DATA(ls_f) INDEX 1.
    ev_tpl_id = ls_f-value.
    TRANSLATE ev_tpl_id TO UPPER CASE.
    ev_ok = boolc( ev_tpl_id IS NOT INITIAL ).
  ENDMETHOD.


  METHOD ask_header.
    DATA: lt_fields TYPE TABLE OF sval,
          lv_rc     TYPE c LENGTH 1.

    APPEND VALUE #( tabname = 'ZHHR_CP_TPLV' fieldname = 'TITULO'
                    value = cv_titulo field_obl = 'X' ) TO lt_fields.
    APPEND VALUE #( tabname = 'ZHHR_CP_TPLH' fieldname = 'DESCR'
                    value = cv_descr ) TO lt_fields.
    APPEND VALUE #( tabname = 'ZHHR_CP_TPLV' fieldname = 'FIRM_ID'
                    value = cv_firm ) TO lt_fields.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title = 'Datos de la plantilla'
      IMPORTING
        returncode  = lv_rc
      TABLES
        fields      = lt_fields
      EXCEPTIONS
        OTHERS      = 1.
    IF sy-subrc <> 0 OR lv_rc = 'A'.
      ev_ok = abap_false.
      RETURN.
    ENDIF.

    LOOP AT lt_fields INTO DATA(ls_f).
      CASE ls_f-fieldname.
        WHEN 'TITULO'.  cv_titulo = ls_f-value.
        WHEN 'DESCR'.   cv_descr  = ls_f-value.
        WHEN 'FIRM_ID'. cv_firm   = ls_f-value.
      ENDCASE.
    ENDLOOP.
    ev_ok = abap_true.
  ENDMETHOD.


  METHOD edit_body.
    DATA: ls_head  TYPE thead,
          lt_lines TYPE TABLE OF tline.

    lt_lines = ct_tline.
    ls_head-tdobject = 'TEXT'.
    ls_head-tdname   = 'ZHHR_CP_DOC'.
    ls_head-tdid     = 'ST'.
    ls_head-tdspras  = sy-langu.

    CALL FUNCTION 'EDIT_TEXT'
      EXPORTING
        header    = ls_head
        program   = sy-repid
      IMPORTING
        newheader = ls_head
      TABLES
        lines     = lt_lines
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      ev_ok = abap_false.
      RETURN.
    ENDIF.

    ct_tline = lt_lines.
    ev_ok = abap_true.
  ENDMETHOD.


  METHOD edit_map.
    DATA: lt_new_map TYPE zcl_cp_tpl_manager=>tt_map,
          ls_exist   TYPE zhhr_cp_map,
          lt_fields  TYPE TABLE OF sval,
          lv_rc      TYPE c LENGTH 1,
          ls_map     TYPE zhhr_cp_map.

    DATA(lt_ph) = parse_placeholders( it_tline ).

    LOOP AT lt_ph INTO DATA(lv_ph).
      READ TABLE ct_map INTO ls_exist WITH KEY placeholder = lv_ph.
      DATA(lv_found) = boolc( sy-subrc = 0 ).

      DATA(lv_infty) = COND infty(  WHEN lv_found = abap_true THEN ls_exist-infty     ELSE '0002' ).
      DATA(lv_field) = COND fdname( WHEN lv_found = abap_true THEN ls_exist-fieldname ELSE space ).
      DATA(lv_fmt)   = COND zde_cp_fmt( WHEN lv_found = abap_true THEN ls_exist-fmt   ELSE 'TEXTO' ).

      CLEAR lt_fields.
      APPEND VALUE #( tabname = 'ZHHR_CP_MAP' fieldname = 'INFTY'
                      value = lv_infty field_obl = 'X' ) TO lt_fields.
      APPEND VALUE #( tabname = 'ZHHR_CP_MAP' fieldname = 'FIELDNAME'
                      value = lv_field field_obl = 'X' ) TO lt_fields.
      APPEND VALUE #( tabname = 'ZHHR_CP_MAP' fieldname = 'FMT'
                      value = lv_fmt ) TO lt_fields.

      CALL FUNCTION 'POPUP_GET_VALUES'
        EXPORTING
          popup_title = |Mapeo de { lv_ph }|
        IMPORTING
          returncode  = lv_rc
        TABLES
          fields      = lt_fields
        EXCEPTIONS
          OTHERS      = 1.
      IF sy-subrc <> 0 OR lv_rc = 'A'.
        CONTINUE.
      ENDIF.

      CLEAR ls_map.
      ls_map-placeholder = lv_ph.
      LOOP AT lt_fields INTO DATA(ls_fld).
        CASE ls_fld-fieldname.
          WHEN 'INFTY'.     ls_map-infty     = ls_fld-value.
          WHEN 'FIELDNAME'. ls_map-fieldname = ls_fld-value.
          WHEN 'FMT'.       ls_map-fmt       = ls_fld-value.
        ENDCASE.
      ENDLOOP.
      TRANSLATE ls_map-fieldname TO UPPER CASE.
      APPEND ls_map TO lt_new_map.
    ENDLOOP.

    ct_map = lt_new_map.
  ENDMETHOD.


  METHOD parse_placeholders.
    DATA lv_text TYPE string.

    LOOP AT it_tline INTO DATA(ls_l).
      lv_text = |{ lv_text } { ls_l-tdline }|.
    ENDLOOP.

    FIND ALL OCCURRENCES OF REGEX `\{\{([^{}]+)\}\}`
      IN lv_text RESULTS DATA(lt_res).

    LOOP AT lt_res INTO DATA(ls_res).
      READ TABLE ls_res-submatches INTO DATA(ls_sm) INDEX 1.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_ph) = substring( val = lv_text
                               off = ls_sm-offset
                               len = ls_sm-length ).
      CONDENSE lv_ph.
      TRANSLATE lv_ph TO UPPER CASE.
      READ TABLE rt_ph TRANSPORTING NO FIELDS WITH KEY table_line = lv_ph.
      IF sy-subrc <> 0.
        APPEND lv_ph TO rt_ph.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD popup_confirm.
    DATA lv_ans TYPE c LENGTH 1.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar       = 'Confirmar'
        text_question  = iv_q
        default_button = '2'
      IMPORTING
        answer         = lv_ans
      EXCEPTIONS
        OTHERS         = 1.
    rv_ok = boolc( sy-subrc = 0 AND lv_ans = '1' ).
  ENDMETHOD.

ENDCLASS.

DATA go_app TYPE REF TO lcl_app.
