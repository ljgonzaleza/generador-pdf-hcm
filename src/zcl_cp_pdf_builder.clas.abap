*&---------------------------------------------------------------------*
*& Clase ZCL_CP_PDF_BUILDER
*&---------------------------------------------------------------------*
*& Descripción : Motor de generación PDF (envoltorio único). Renderiza
*&               el texto ya resuelto mediante el Smart Form genérico
*&               ZHHR_CP_SF_DOC y lo convierte a PDF (OTF -> PDF).
*&               Aísla la tecnología de impresión del resto del código.
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*&---------------------------------------------------------------------*
*& Interfaz esperada del Smart Form ZHHR_CP_SF_DOC (importing):
*&   IV_TITULO    TYPE ZDE_CP_TPL_TXT
*&   IV_FIRMANTE  TYPE ZDE_CP_TPL_TXT
*&   IV_CARGO     TYPE ZDE_CP_TPL_TXT
*&   IV_FIRMA_IMG TYPE XSTRING
*&   IT_LINEAS    TYPE TABLE OF TDLINE   (tables)
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
CLASS zcl_cp_pdf_builder DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES tt_tdline TYPE STANDARD TABLE OF tdline WITH DEFAULT KEY.

    CONSTANTS gc_formname TYPE tdsfname VALUE 'ZHHR_CP_SF_DOC'.

    "! Renderiza el documento a PDF.
    METHODS build
      IMPORTING
        !iv_titulo    TYPE zde_cp_tpl_txt
        !it_lines     TYPE tt_tdline
        !is_firm      TYPE zhhr_cp_firm OPTIONAL
      RETURNING
        VALUE(rv_pdf) TYPE xstring
      RAISING
        zcx_cp_error.

  PRIVATE SECTION.
    METHODS raise_error
      IMPORTING
        !io_previous TYPE REF TO cx_root OPTIONAL
      RAISING
        zcx_cp_error.
ENDCLASS.



CLASS zcl_cp_pdf_builder IMPLEMENTATION.

  METHOD build.

    DATA: lv_fm        TYPE rs38l_fnam,
          ls_control   TYPE ssfctrlop,
          ls_output    TYPE ssfcompop,
          ls_job_info  TYPE ssfcrescl,
          lt_otf       TYPE TABLE OF itcoo,
          lv_pdf_len   TYPE i,
          lt_pdf_lines TYPE TABLE OF tline.

    CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
      EXPORTING
        formname           = gc_formname
      IMPORTING
        fm_name            = lv_fm
      EXCEPTIONS
        no_form            = 1
        no_function_module = 2
        OTHERS             = 3.
    IF sy-subrc <> 0.
      raise_error( ).
    ENDIF.

    ls_control-no_dialog = abap_true.
    ls_control-getotf    = abap_true.
    ls_output-tdnoprev   = abap_true.

    TRY.
        CALL FUNCTION lv_fm
          EXPORTING
            control_parameters = ls_control
            output_options     = ls_output
            user_settings      = space
            iv_titulo          = iv_titulo
            iv_firmante        = is_firm-nombre
            iv_cargo           = is_firm-cargo
            iv_firma_img       = is_firm-img
          IMPORTING
            job_output_info    = ls_job_info
          TABLES
            it_lineas          = it_lines
          EXCEPTIONS
            formatting_error   = 1
            internal_error     = 2
            send_error         = 3
            user_canceled      = 4
            OTHERS             = 5.
      CATCH cx_sy_dyn_call_error INTO DATA(lo_dyn).
        raise_error( lo_dyn ).
    ENDTRY.
    IF sy-subrc <> 0.
      raise_error( ).
    ENDIF.

    lt_otf = ls_job_info-otfdata.

    CALL FUNCTION 'CONVERT_OTF'
      EXPORTING
        format                = 'PDF'
      IMPORTING
        bin_filesize          = lv_pdf_len
        bin_file              = rv_pdf
      TABLES
        otf                   = lt_otf
        lines                 = lt_pdf_lines
      EXCEPTIONS
        err_max_linewidth     = 1
        err_format            = 2
        err_conv_not_possible = 3
        err_bad_otf           = 4
        OTHERS                = 5.
    IF sy-subrc <> 0.
      raise_error( ).
    ENDIF.

  ENDMETHOD.


  METHOD raise_error.
    MESSAGE e005 INTO DATA(lv_msg).
    RAISE EXCEPTION TYPE zcx_cp_error
      EXPORTING
        iv_text  = lv_msg
        previous = io_previous.
  ENDMETHOD.

ENDCLASS.
