*&---------------------------------------------------------------------*
*& Clase ZCL_CP_TPL_MANAGER
*&---------------------------------------------------------------------*
*& Descripción : Gestión y versionado de plantillas de documentos.
*&               CRUD sobre ZHHR_CP_TPLH / TPLV / TPLT / MAP.
*&               Estados de versión: B Borrador / A Activa / O Obsoleta.
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
CLASS zcl_cp_tpl_manager DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      tt_tplh  TYPE STANDARD TABLE OF zhhr_cp_tplh WITH DEFAULT KEY,
      tt_tplv  TYPE STANDARD TABLE OF zhhr_cp_tplv WITH DEFAULT KEY,
      tt_tplt  TYPE STANDARD TABLE OF zhhr_cp_tplt WITH DEFAULT KEY,
      tt_map   TYPE STANDARD TABLE OF zhhr_cp_map  WITH DEFAULT KEY,
      tt_tline TYPE STANDARD TABLE OF tline        WITH DEFAULT KEY.

    CONSTANTS:
      gc_borrador TYPE zde_cp_tpl_st VALUE 'B',
      gc_activa   TYPE zde_cp_tpl_st VALUE 'A',
      gc_obsoleta TYPE zde_cp_tpl_st VALUE 'O'.

    METHODS get_list
      RETURNING VALUE(rt_list) TYPE tt_tplh.

    METHODS get_versions
      IMPORTING !iv_tpl_id     TYPE zde_cp_tpl_id
      RETURNING VALUE(rt_vers) TYPE tt_tplv.

    METHODS read_version
      IMPORTING !iv_tpl_id   TYPE zde_cp_tpl_id
                !iv_version  TYPE zde_cp_tpl_ver
      EXPORTING !es_version  TYPE zhhr_cp_tplv
                !et_lines    TYPE tt_tplt
                !et_map      TYPE tt_map
      RAISING   zcx_cp_error.

    METHODS get_active_version
      IMPORTING !iv_tpl_id        TYPE zde_cp_tpl_id
      RETURNING VALUE(rv_version) TYPE zde_cp_tpl_ver
      RAISING   zcx_cp_error.

    METHODS save_draft
      IMPORTING !iv_tpl_id        TYPE zde_cp_tpl_id
                !iv_descr         TYPE zde_cp_tpl_txt
                !iv_titulo        TYPE zde_cp_tpl_txt
                !iv_firm_id       TYPE zde_cp_firm_id
                !it_tline         TYPE tt_tline
                !it_map           TYPE tt_map
      RETURNING VALUE(rv_version) TYPE zde_cp_tpl_ver
      RAISING   zcx_cp_error.

    METHODS activate
      IMPORTING !iv_tpl_id  TYPE zde_cp_tpl_id
                !iv_version TYPE zde_cp_tpl_ver
      RAISING   zcx_cp_error.

    METHODS deactivate
      IMPORTING !iv_tpl_id TYPE zde_cp_tpl_id
      RAISING   zcx_cp_error.

    METHODS copy
      IMPORTING !iv_src  TYPE zde_cp_tpl_id
                !iv_dest TYPE zde_cp_tpl_id
      RAISING   zcx_cp_error.

    METHODS validate_placeholders
      IMPORTING !it_lines         TYPE tt_tplt
                !it_map           TYPE tt_map
      RETURNING VALUE(rv_missing) TYPE string.

  PRIVATE SECTION.
    METHODS extract_placeholders
      IMPORTING !it_lines     TYPE tt_tplt
      RETURNING VALUE(rt_ph)  TYPE string_table.

    METHODS raise_msg
      IMPORTING !iv_msg TYPE string
      RAISING   zcx_cp_error.
ENDCLASS.



CLASS zcl_cp_tpl_manager IMPLEMENTATION.

  METHOD raise_msg.
    RAISE EXCEPTION TYPE zcx_cp_error EXPORTING iv_text = iv_msg.
  ENDMETHOD.


  METHOD get_list.
    SELECT tpl_id, descr, active_ver, ernam, erdat, aenam, aedat
      FROM zhhr_cp_tplh
      INTO CORRESPONDING FIELDS OF TABLE @rt_list
      ORDER BY tpl_id.
    IF sy-subrc <> 0.
      CLEAR rt_list.
    ENDIF.
  ENDMETHOD.


  METHOD get_versions.
    SELECT tpl_id, version, status, titulo, firm_id, ernam, erdat, aenam, aedat
      FROM zhhr_cp_tplv
      INTO CORRESPONDING FIELDS OF TABLE @rt_vers
      WHERE tpl_id = @iv_tpl_id
      ORDER BY version.
    IF sy-subrc <> 0.
      CLEAR rt_vers.
    ENDIF.
  ENDMETHOD.


  METHOD read_version.
    CLEAR: es_version, et_lines, et_map.

    SELECT SINGLE tpl_id, version, status, titulo, firm_id,
                  ernam, erdat, aenam, aedat
      FROM zhhr_cp_tplv
      INTO CORRESPONDING FIELDS OF @es_version
      WHERE tpl_id  = @iv_tpl_id
        AND version = @iv_version.
    IF sy-subrc <> 0.
      MESSAGE e001 WITH iv_tpl_id INTO DATA(lv_msg).
      raise_msg( lv_msg ).
    ENDIF.

    SELECT tpl_id, version, line_no, tdformat, tdline
      FROM zhhr_cp_tplt
      INTO CORRESPONDING FIELDS OF TABLE @et_lines
      WHERE tpl_id  = @iv_tpl_id
        AND version = @iv_version
      ORDER BY line_no.

    SELECT tpl_id, version, placeholder, infty, fieldname, fmt
      FROM zhhr_cp_map
      INTO CORRESPONDING FIELDS OF TABLE @et_map
      WHERE tpl_id  = @iv_tpl_id
        AND version = @iv_version
      ORDER BY placeholder.
  ENDMETHOD.


  METHOD get_active_version.
    SELECT SINGLE active_ver
      FROM zhhr_cp_tplh
      INTO @rv_version
      WHERE tpl_id = @iv_tpl_id.
    IF sy-subrc <> 0.
      MESSAGE e001 WITH iv_tpl_id INTO DATA(lv_msg).
      raise_msg( lv_msg ).
    ENDIF.
    IF rv_version IS INITIAL.
      MESSAGE e002 WITH iv_tpl_id INTO lv_msg.
      raise_msg( lv_msg ).
    ENDIF.
  ENDMETHOD.


  METHOD save_draft.
    DATA: ls_hdr TYPE zhhr_cp_tplh,
          ls_ver TYPE zhhr_cp_tplv,
          lv_ver TYPE zde_cp_tpl_ver,
          lt_tplt TYPE tt_tplt,
          lt_map  TYPE tt_map.

    IF iv_tpl_id IS INITIAL.
      MESSAGE e008 WITH 'TPL_ID' INTO DATA(lv_msg).
      raise_msg( lv_msg ).
    ENDIF.

    SELECT SINGLE tpl_id, descr, active_ver, ernam, erdat, aenam, aedat
      FROM zhhr_cp_tplh
      INTO CORRESPONDING FIELDS OF @ls_hdr
      WHERE tpl_id = @iv_tpl_id.

    IF sy-subrc <> 0.
      " Nueva plantilla -> versión 1
      lv_ver            = 1.
      ls_hdr-tpl_id     = iv_tpl_id.
      ls_hdr-descr      = iv_descr.
      ls_hdr-active_ver = 0.
      ls_hdr-ernam      = sy-uname.
      ls_hdr-erdat      = sy-datum.
      INSERT zhhr_cp_tplh FROM @ls_hdr.
      IF sy-subrc <> 0.
        MESSAGE e015 WITH iv_tpl_id INTO lv_msg.
        raise_msg( lv_msg ).
      ENDIF.
    ELSE.
      " Reutiliza la versión Borrador si existe; si no, crea una nueva
      SELECT SINGLE version
        FROM zhhr_cp_tplv
        INTO @lv_ver
        WHERE tpl_id = @iv_tpl_id
          AND status = @gc_borrador.
      IF sy-subrc <> 0.
        SELECT MAX( version )
          FROM zhhr_cp_tplv
          INTO @lv_ver
          WHERE tpl_id = @iv_tpl_id.
        lv_ver = lv_ver + 1.
      ENDIF.

      UPDATE zhhr_cp_tplh
        SET descr = @iv_descr,
            aenam = @sy-uname,
            aedat = @sy-datum
        WHERE tpl_id = @iv_tpl_id.
      IF sy-subrc <> 0.
        MESSAGE e005 INTO lv_msg.
        raise_msg( lv_msg ).
      ENDIF.
    ENDIF.

    " Cabecera de versión (siempre Borrador)
    ls_ver-tpl_id  = iv_tpl_id.
    ls_ver-version = lv_ver.
    ls_ver-status  = gc_borrador.
    ls_ver-titulo  = iv_titulo.
    ls_ver-firm_id = iv_firm_id.
    ls_ver-ernam   = sy-uname.
    ls_ver-erdat   = sy-datum.
    ls_ver-aenam   = sy-uname.
    ls_ver-aedat   = sy-datum.
    MODIFY zhhr_cp_tplv FROM @ls_ver.
    IF sy-subrc <> 0.
      MESSAGE e005 INTO lv_msg.
      raise_msg( lv_msg ).
    ENDIF.

    " Reemplaza el cuerpo (líneas)
    DELETE FROM zhhr_cp_tplt
      WHERE tpl_id = @iv_tpl_id AND version = @lv_ver.
    LOOP AT it_tline INTO DATA(ls_tl).
      APPEND VALUE #( tpl_id   = iv_tpl_id
                      version  = lv_ver
                      line_no  = sy-tabix
                      tdformat = ls_tl-tdformat
                      tdline   = ls_tl-tdline ) TO lt_tplt.
    ENDLOOP.
    IF lt_tplt IS NOT INITIAL.
      INSERT zhhr_cp_tplt FROM TABLE @lt_tplt.
      IF sy-subrc <> 0.
        MESSAGE e005 INTO lv_msg.
        raise_msg( lv_msg ).
      ENDIF.
    ENDIF.

    " Reemplaza el mapeo
    DELETE FROM zhhr_cp_map
      WHERE tpl_id = @iv_tpl_id AND version = @lv_ver.
    lt_map = it_map.
    LOOP AT lt_map ASSIGNING FIELD-SYMBOL(<ls_m>).
      <ls_m>-tpl_id  = iv_tpl_id.
      <ls_m>-version = lv_ver.
      TRANSLATE <ls_m>-placeholder TO UPPER CASE.
    ENDLOOP.
    IF lt_map IS NOT INITIAL.
      INSERT zhhr_cp_map FROM TABLE @lt_map.
      IF sy-subrc <> 0.
        MESSAGE e005 INTO lv_msg.
        raise_msg( lv_msg ).
      ENDIF.
    ENDIF.

    rv_version = lv_ver.
  ENDMETHOD.


  METHOD activate.
    DATA: lt_lines  TYPE tt_tplt,
          lt_map    TYPE tt_map,
          lv_active TYPE zde_cp_tpl_ver.

    SELECT tpl_id, version, line_no, tdformat, tdline
      FROM zhhr_cp_tplt
      INTO CORRESPONDING FIELDS OF TABLE @lt_lines
      WHERE tpl_id = @iv_tpl_id AND version = @iv_version
      ORDER BY line_no.

    SELECT tpl_id, version, placeholder, infty, fieldname, fmt
      FROM zhhr_cp_map
      INTO CORRESPONDING FIELDS OF TABLE @lt_map
      WHERE tpl_id = @iv_tpl_id AND version = @iv_version
      ORDER BY placeholder.

    DATA(lv_missing) = validate_placeholders( it_lines = lt_lines
                                              it_map   = lt_map ).
    IF lv_missing IS NOT INITIAL.
      MESSAGE e003 WITH lv_missing INTO DATA(lv_msg).
      raise_msg( lv_msg ).
    ENDIF.

    SELECT SINGLE active_ver
      FROM zhhr_cp_tplh
      INTO @lv_active
      WHERE tpl_id = @iv_tpl_id.
    IF sy-subrc <> 0.
      MESSAGE e001 WITH iv_tpl_id INTO lv_msg.
      raise_msg( lv_msg ).
    ENDIF.

    IF lv_active IS NOT INITIAL AND lv_active <> iv_version.
      UPDATE zhhr_cp_tplv
        SET status = @gc_obsoleta
        WHERE tpl_id = @iv_tpl_id AND version = @lv_active.
    ENDIF.

    UPDATE zhhr_cp_tplv
      SET status = @gc_activa
      WHERE tpl_id = @iv_tpl_id AND version = @iv_version.
    IF sy-subrc <> 0.
      MESSAGE e005 INTO lv_msg.
      raise_msg( lv_msg ).
    ENDIF.

    UPDATE zhhr_cp_tplh
      SET active_ver = @iv_version,
          aenam      = @sy-uname,
          aedat      = @sy-datum
      WHERE tpl_id = @iv_tpl_id.
    IF sy-subrc <> 0.
      MESSAGE e005 INTO lv_msg.
      raise_msg( lv_msg ).
    ENDIF.
  ENDMETHOD.


  METHOD deactivate.
    DATA lv_active TYPE zde_cp_tpl_ver.

    SELECT SINGLE active_ver
      FROM zhhr_cp_tplh
      INTO @lv_active
      WHERE tpl_id = @iv_tpl_id.
    IF sy-subrc <> 0.
      MESSAGE e001 WITH iv_tpl_id INTO DATA(lv_msg).
      raise_msg( lv_msg ).
    ENDIF.

    IF lv_active IS INITIAL.
      RETURN.
    ENDIF.

    UPDATE zhhr_cp_tplv
      SET status = @gc_obsoleta
      WHERE tpl_id = @iv_tpl_id AND version = @lv_active.

    UPDATE zhhr_cp_tplh
      SET active_ver = '0000',
          aenam      = @sy-uname,
          aedat      = @sy-datum
      WHERE tpl_id = @iv_tpl_id.
    IF sy-subrc <> 0.
      MESSAGE e005 INTO lv_msg.
      raise_msg( lv_msg ).
    ENDIF.
  ENDMETHOD.


  METHOD copy.
    DATA: ls_src_ver TYPE zhhr_cp_tplv,
          lt_lines   TYPE tt_tplt,
          lt_map     TYPE tt_map,
          lt_tline   TYPE tt_tline,
          lv_srcver  TYPE zde_cp_tpl_ver,
          lv_descr   TYPE zde_cp_tpl_txt.

    SELECT SINGLE @abap_true
      FROM zhhr_cp_tplh
      INTO @DATA(lv_exists)
      WHERE tpl_id = @iv_dest.
    IF lv_exists = abap_true.
      MESSAGE e015 WITH iv_dest INTO DATA(lv_msg).
      raise_msg( lv_msg ).
    ENDIF.

    SELECT SINGLE descr, active_ver
      FROM zhhr_cp_tplh
      INTO ( @lv_descr, @lv_srcver )
      WHERE tpl_id = @iv_src.
    IF sy-subrc <> 0.
      MESSAGE e001 WITH iv_src INTO lv_msg.
      raise_msg( lv_msg ).
    ENDIF.

    IF lv_srcver IS INITIAL.
      SELECT MAX( version )
        FROM zhhr_cp_tplv
        INTO @lv_srcver
        WHERE tpl_id = @iv_src.
    ENDIF.
    IF lv_srcver IS INITIAL.
      MESSAGE e002 WITH iv_src INTO lv_msg.
      raise_msg( lv_msg ).
    ENDIF.

    read_version(
      EXPORTING iv_tpl_id  = iv_src
                iv_version = lv_srcver
      IMPORTING es_version = ls_src_ver
                et_lines   = lt_lines
                et_map     = lt_map ).

    LOOP AT lt_lines INTO DATA(ls_l).
      APPEND VALUE #( tdformat = ls_l-tdformat
                      tdline   = ls_l-tdline ) TO lt_tline.
    ENDLOOP.

    save_draft(
      iv_tpl_id  = iv_dest
      iv_descr   = lv_descr
      iv_titulo  = ls_src_ver-titulo
      iv_firm_id = ls_src_ver-firm_id
      it_tline   = lt_tline
      it_map     = lt_map ).
  ENDMETHOD.


  METHOD validate_placeholders.
    DATA(lt_ph) = extract_placeholders( it_lines ).

    LOOP AT lt_ph INTO DATA(lv_ph).
      READ TABLE it_map TRANSPORTING NO FIELDS
        WITH KEY placeholder = lv_ph.
      IF sy-subrc <> 0.
        IF rv_missing IS INITIAL.
          rv_missing = lv_ph.
        ELSE.
          rv_missing = |{ rv_missing }, { lv_ph }|.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD extract_placeholders.
    DATA lv_text TYPE string.

    LOOP AT it_lines INTO DATA(ls_l).
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
      READ TABLE rt_ph TRANSPORTING NO FIELDS
        WITH KEY table_line = lv_ph.
      IF sy-subrc <> 0.
        APPEND lv_ph TO rt_ph.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.