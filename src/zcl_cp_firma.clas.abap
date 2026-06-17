*&---------------------------------------------------------------------*
*& Clase ZCL_CP_FIRMA
*&---------------------------------------------------------------------*
*& Descripción : Gestión de firmantes e imagen de firma (tabla
*&               ZHHR_CP_FIRM). Datos de aplicación editables en PRD.
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
CLASS zcl_cp_firma DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES tt_firm TYPE STANDARD TABLE OF zhhr_cp_firm WITH DEFAULT KEY.

    "! Catálogo de firmantes (sin imagen) para ayuda de búsqueda.
    METHODS get_list
      RETURNING
        VALUE(rt_firms) TYPE tt_firm.

    "! Lee un firmante completo (incluida la imagen). Si no existe,
    "! devuelve estructura inicial (la firma es opcional).
    METHODS read
      IMPORTING
        !iv_firm_id    TYPE zde_cp_firm_id
      RETURNING
        VALUE(rs_firm) TYPE zhhr_cp_firm.

    "! Alta o modificación de un firmante. Valida el tipo MIME.
    METHODS save
      IMPORTING
        !is_firm TYPE zhhr_cp_firm
      RAISING
        zcx_cp_error.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_cp_firma IMPLEMENTATION.

  METHOD get_list.
    SELECT firm_id, nombre, cargo, mimetype
      FROM zhhr_cp_firm
      INTO CORRESPONDING FIELDS OF TABLE @rt_firms
      ORDER BY firm_id.
    IF sy-subrc <> 0.
      CLEAR rt_firms.
    ENDIF.
  ENDMETHOD.


  METHOD read.
    IF iv_firm_id IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE firm_id, nombre, cargo, mimetype, img
      FROM zhhr_cp_firm
      INTO CORRESPONDING FIELDS OF @rs_firm
      WHERE firm_id = @iv_firm_id.
    IF sy-subrc <> 0.
      CLEAR rs_firm.
    ENDIF.
  ENDMETHOD.


  METHOD save.
    DATA ls_firm TYPE zhhr_cp_firm.

    IF is_firm-firm_id IS INITIAL.
      MESSAGE e008 WITH 'FIRM_ID' INTO DATA(lv_msg).
      RAISE EXCEPTION TYPE zcx_cp_error EXPORTING iv_text = lv_msg.
    ENDIF.

    IF is_firm-mimetype IS NOT INITIAL
       AND is_firm-mimetype <> 'image/png'
       AND is_firm-mimetype <> 'image/jpeg'.
      MESSAGE e009 WITH is_firm-mimetype INTO lv_msg.
      RAISE EXCEPTION TYPE zcx_cp_error EXPORTING iv_text = lv_msg.
    ENDIF.

    ls_firm = is_firm.

    SELECT SINGLE @abap_true FROM zhhr_cp_firm
      INTO @DATA(lv_exists)
      WHERE firm_id = @ls_firm-firm_id.
    IF lv_exists = abap_true.
      ls_firm-aenam = sy-uname.
      ls_firm-aedat = sy-datum.
    ELSE.
      ls_firm-ernam = sy-uname.
      ls_firm-erdat = sy-datum.
    ENDIF.

    MODIFY zhhr_cp_firm FROM @ls_firm.
    IF sy-subrc <> 0.
      MESSAGE e005 INTO lv_msg.
      RAISE EXCEPTION TYPE zcx_cp_error EXPORTING iv_text = lv_msg.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
