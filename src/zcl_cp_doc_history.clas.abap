*&---------------------------------------------------------------------*
*& Clase ZCL_CP_DOC_HISTORY
*&---------------------------------------------------------------------*
*& Descripción : Consulta del histórico de documentos generados y
*&               recuperación del PDF almacenado para su reapertura.
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
CLASS zcl_cp_doc_history DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      tr_pernr TYPE RANGE OF pernr_d,
      tr_tplid TYPE RANGE OF zde_cp_tpl_id,
      tr_fecha TYPE RANGE OF datum,
      tr_user  TYPE RANGE OF xubname,
      tt_rows  TYPE STANDARD TABLE OF zhhr_cp_s_docrow WITH DEFAULT KEY.

    METHODS search
      IMPORTING
        !it_pernr      TYPE tr_pernr OPTIONAL
        !it_tplid      TYPE tr_tplid OPTIONAL
        !it_fecha      TYPE tr_fecha OPTIONAL
        !it_user       TYPE tr_user  OPTIONAL
      RETURNING
        VALUE(rt_rows) TYPE tt_rows.

    METHODS get_pdf
      IMPORTING
        !iv_doc_id    TYPE zde_cp_doc_id
      EXPORTING
        !ev_pdf       TYPE xstring
        !ev_filename  TYPE zde_cp_fname
      RAISING
        zcx_cp_error.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_cp_doc_history IMPLEMENTATION.

  METHOD search.
    DATA lt_dlog TYPE STANDARD TABLE OF zhhr_cp_dlog.

    SELECT doc_id, pernr, tpl_id, version, fecha_gen, hora_gen, usuario
      FROM zhhr_cp_dlog
      INTO CORRESPONDING FIELDS OF TABLE @lt_dlog
      WHERE pernr     IN @it_pernr
        AND tpl_id    IN @it_tplid
        AND fecha_gen IN @it_fecha
        AND usuario   IN @it_user
      ORDER BY doc_id DESCENDING.
    IF sy-subrc <> 0.
      CLEAR rt_rows.
      RETURN.
    ENDIF.

    LOOP AT lt_dlog INTO DATA(ls_dlog).
      DATA(ls_row) = CORRESPONDING zhhr_cp_s_docrow( ls_dlog ).

      SELECT SINGLE descr
        FROM zhhr_cp_tplh
        INTO @ls_row-descr
        WHERE tpl_id = @ls_dlog-tpl_id.

      " Nombre del empleado vigente hoy (informativo)
      SELECT SINGLE ename
        FROM pa0001
        INTO @ls_row-ename
        WHERE pernr =  @ls_dlog-pernr
          AND begda <= @sy-datum
          AND endda >= @sy-datum.

      APPEND ls_row TO rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_pdf.
    SELECT SINGLE pdf, filename
      FROM zhhr_cp_pdf
      INTO ( @ev_pdf, @ev_filename )
      WHERE doc_id = @iv_doc_id.
    IF sy-subrc <> 0.
      MESSAGE e006(zhhr_cp_msg) WITH iv_doc_id INTO DATA(lv_msg).
      RAISE EXCEPTION TYPE zcx_cp_error EXPORTING iv_text = lv_msg.
    ENDIF.
  ENDMETHOD.

ENDCLASS.