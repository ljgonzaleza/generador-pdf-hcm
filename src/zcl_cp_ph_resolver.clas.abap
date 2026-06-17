*&---------------------------------------------------------------------*
*& Clase ZCL_CP_PH_RESOLVER
*&---------------------------------------------------------------------*
*& Descripción : Resolución de placeholders. Lee los valores desde los
*&               infotipos, aplica el formato configurado y sustituye
*&               los marcadores {{...}} en el cuerpo de la plantilla.
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
CLASS zcl_cp_ph_resolver DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      tt_map    TYPE STANDARD TABLE OF zhhr_cp_map     WITH DEFAULT KEY,
      tt_phval  TYPE STANDARD TABLE OF zhhr_cp_s_phval WITH DEFAULT KEY,
      tt_tdline TYPE STANDARD TABLE OF tdline          WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING
        !io_reader TYPE REF TO zcl_cp_hr_reader OPTIONAL.

    "! Resuelve los placeholders del mapeo a sus valores formateados.
    METHODS resolve
      IMPORTING
        !iv_pernr        TYPE pernr_d
        !iv_date         TYPE datum
        !it_map          TYPE tt_map
      RETURNING
        VALUE(rt_values) TYPE tt_phval
      RAISING
        zcx_cp_error.

    "! Sustituye los placeholders en las líneas de texto.
    METHODS substitute
      IMPORTING
        !it_lines       TYPE tt_tdline
        !it_values      TYPE tt_phval
      RETURNING
        VALUE(rt_lines) TYPE tt_tdline.

    "! Aplica el formato indicado a un valor crudo.
    METHODS apply_format
      IMPORTING
        !iv_raw        TYPE string
        !iv_fmt        TYPE zde_cp_fmt
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
    DATA mo_reader TYPE REF TO zcl_cp_hr_reader.

    METHODS format_long_date
      IMPORTING
        !iv_date       TYPE datum
      RETURNING
        VALUE(rv_text) TYPE string.
ENDCLASS.



CLASS zcl_cp_ph_resolver IMPLEMENTATION.

  METHOD constructor.
    IF io_reader IS BOUND.
      mo_reader = io_reader.
    ELSE.
      mo_reader = NEW zcl_cp_hr_reader( ).
    ENDIF.
  ENDMETHOD.


  METHOD resolve.
    LOOP AT it_map INTO DATA(ls_map).
      DATA(lv_raw) = mo_reader->read_field(
        iv_pernr = iv_pernr
        iv_infty = ls_map-infty
        iv_field = ls_map-fieldname
        iv_date  = iv_date ).

      APPEND VALUE #(
        placeholder = ls_map-placeholder
        value       = apply_format( iv_raw = lv_raw
                                    iv_fmt = ls_map-fmt ) )
        TO rt_values.
    ENDLOOP.
  ENDMETHOD.


  METHOD substitute.
    rt_lines = it_lines.

    LOOP AT rt_lines ASSIGNING FIELD-SYMBOL(<lv_line>).
      LOOP AT it_values INTO DATA(ls_val).
        DATA(lv_ph) = CONV string( ls_val-placeholder ).
        CONDENSE lv_ph.
        DATA(lv_search) = `{{` && lv_ph && `}}`.
        REPLACE ALL OCCURRENCES OF lv_search
                IN <lv_line> WITH ls_val-value.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD apply_format.

    DATA: lv_date   TYPE d,
          lv_amount TYPE p LENGTH 15 DECIMALS 2.

    CASE iv_fmt.
      WHEN 'FECHA'.
        IF strlen( iv_raw ) = 8.
          lv_date = iv_raw.
          rv_text = |{ lv_date+6(2) }.{ lv_date+4(2) }.{ lv_date(4) }|.
        ELSE.
          rv_text = iv_raw.
        ENDIF.

      WHEN 'FECHA_LARGA'.
        IF strlen( iv_raw ) = 8.
          lv_date = iv_raw.
          rv_text = format_long_date( lv_date ).
        ELSE.
          rv_text = iv_raw.
        ENDIF.

      WHEN 'IMPORTE'.
        TRY.
            lv_amount = iv_raw.
            rv_text   = |{ lv_amount NUMBER = USER }|.
          CATCH cx_sy_conversion_no_number.
            rv_text = iv_raw.
        ENDTRY.

      WHEN OTHERS.
        rv_text = iv_raw.
    ENDCASE.

  ENDMETHOD.


  METHOD format_long_date.

    DATA(lt_months) = VALUE string_table(
      ( `enero` )   ( `febrero` )   ( `marzo` )      ( `abril` )
      ( `mayo` )    ( `junio` )     ( `julio` )      ( `agosto` )
      ( `septiembre` ) ( `octubre` ) ( `noviembre` ) ( `diciembre` ) ).

    DATA(lv_mm) = CONV i( iv_date+4(2) ).

    READ TABLE lt_months INTO DATA(lv_month) INDEX lv_mm.
    IF sy-subrc <> 0.
      rv_text = |{ iv_date+6(2) }.{ iv_date+4(2) }.{ iv_date(4) }|.
      RETURN.
    ENDIF.

    rv_text = |{ iv_date+6(2) } de { lv_month } de { iv_date(4) }|.

  ENDMETHOD.

ENDCLASS.
