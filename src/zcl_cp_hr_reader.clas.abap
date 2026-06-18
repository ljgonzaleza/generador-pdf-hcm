*&---------------------------------------------------------------------*
*& Clase ZCL_CP_HR_READER
*&---------------------------------------------------------------------*
*& Descripción : Lectura de campos de infotipos PA. Devuelve el valor
*&               del registro vigente a una fecha. NO realiza chequeo
*&               de autorización por número de personal (requisito).
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
CLASS zcl_cp_hr_reader DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Lee el valor de un campo del registro vigente de un infotipo.
    "! Si no hay registro vigente devuelve valor inicial.
    METHODS read_field
      IMPORTING
        !iv_pernr       TYPE pernr_d
        !iv_infty       TYPE infty
        !iv_field       TYPE fdname
        !iv_date        TYPE datum
      RETURNING
        VALUE(rv_value) TYPE string
      RAISING
        zcx_cp_error.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_cp_hr_reader IMPLEMENTATION.

  METHOD read_field.

    DATA: lv_tab   TYPE tabname,
          lv_value TYPE string.

    " Nombre físico de la tabla de infotipo: PA + nnnn (p.ej. PA0002)
    lv_tab = |PA{ iv_infty }|.

    TRY.
        " Lectura directa del campo solicitado (sin SELECT *), del
        " registro vigente a la fecha. Open SQL no aplica chequeo HR.
        SELECT SINGLE (iv_field)
          FROM (lv_tab)
          INTO @lv_value
          WHERE pernr =  @iv_pernr
            AND begda <= @iv_date
            AND endda >= @iv_date.

      CATCH cx_sy_dynamic_osql_semantics
            cx_sy_dynamic_osql_error INTO DATA(lo_err).
        MESSAGE e004(zhhr_cp_msg) WITH iv_infty iv_pernr INTO DATA(lv_msg).
        RAISE EXCEPTION TYPE zcx_cp_error
          EXPORTING
            iv_text  = lv_msg
            previous = lo_err.
    ENDTRY.

    IF sy-subrc <> 0.
      " Sin registro vigente: se devuelve vacío (regla RN-2.3).
      CLEAR rv_value.
      RETURN.
    ENDIF.

    rv_value = lv_value.

  ENDMETHOD.

ENDCLASS.
