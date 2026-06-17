*&---------------------------------------------------------------------*
*& Clase ZCL_CP_PDF_VIEW
*&---------------------------------------------------------------------*
*& Descripción : Utilidad de frontend para visualizar (abrir en el
*&               visor por defecto) y descargar un PDF (XSTRING).
*& Fecha creac.: 17.06.2026
*& Creado por  : Equipo de desarrollo
*& Empresa     : Grupo LATAM Airlines
*&---------------------------------------------------------------------*
*& Histórico de modificaciones
*&  @001 17.06.2026 - Creación inicial
*&---------------------------------------------------------------------*
CLASS zcl_cp_pdf_view DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Abre el PDF en el visor por defecto del frontend.
    CLASS-METHODS display
      IMPORTING
        !iv_pdf      TYPE xstring
        !iv_filename TYPE string OPTIONAL
      RAISING
        zcx_cp_error.

    "! Descarga el PDF a una ruta elegida por el usuario.
    CLASS-METHODS save_as
      IMPORTING
        !iv_pdf      TYPE xstring
        !iv_filename TYPE string OPTIONAL
      RAISING
        zcx_cp_error.

  PRIVATE SECTION.
    CLASS-METHODS to_binary
      IMPORTING
        !iv_pdf    TYPE xstring
      EXPORTING
        !et_bin    TYPE solix_tab
        !ev_length TYPE i.

    CLASS-METHODS raise_fe
      RAISING zcx_cp_error.
ENDCLASS.



CLASS zcl_cp_pdf_view IMPLEMENTATION.

  METHOD to_binary.
    et_bin    = cl_bcs_convert=>xstring_to_solix( iv_pdf ).
    ev_length = xstrlen( iv_pdf ).
  ENDMETHOD.


  METHOD raise_fe.
    MESSAGE e017 INTO DATA(lv_msg).
    RAISE EXCEPTION TYPE zcx_cp_error EXPORTING iv_text = lv_msg.
  ENDMETHOD.


  METHOD display.
    DATA: lt_bin  TYPE solix_tab,
          lv_len  TYPE i,
          lv_dir  TYPE string,
          lv_sep  TYPE c LENGTH 1,
          lv_name TYPE string,
          lv_path TYPE string.

    to_binary( EXPORTING iv_pdf = iv_pdf
               IMPORTING et_bin = lt_bin ev_length = lv_len ).

    cl_gui_frontend_services=>get_temp_directory(
      CHANGING  temp_dir = lv_dir
      EXCEPTIONS OTHERS  = 1 ).
    IF sy-subrc <> 0.
      raise_fe( ).
    ENDIF.

    cl_gui_frontend_services=>get_file_separator(
      CHANGING  file_separator = lv_sep
      EXCEPTIONS OTHERS        = 1 ).
    IF sy-subrc <> 0.
      raise_fe( ).
    ENDIF.

    lv_name = COND #( WHEN iv_filename IS NOT INITIAL THEN iv_filename
                      ELSE |documento_{ sy-datum }_{ sy-uzeit }.pdf| ).
    lv_path = |{ lv_dir }{ lv_sep }{ lv_name }|.

    cl_gui_frontend_services=>gui_download(
      EXPORTING bin_filesize = lv_len
                filename     = lv_path
                filetype     = 'BIN'
      CHANGING  data_tab     = lt_bin
      EXCEPTIONS OTHERS      = 1 ).
    IF sy-subrc <> 0.
      raise_fe( ).
    ENDIF.

    cl_gui_frontend_services=>execute(
      EXPORTING document = lv_path
      EXCEPTIONS OTHERS  = 1 ).
    IF sy-subrc <> 0.
      raise_fe( ).
    ENDIF.

    cl_gui_cfw=>flush( ).
  ENDMETHOD.


  METHOD save_as.
    DATA: lt_bin    TYPE solix_tab,
          lv_len    TYPE i,
          lv_name   TYPE string,
          lv_path   TYPE string,
          lv_full   TYPE string,
          lv_action TYPE i,
          lv_def    TYPE string.

    to_binary( EXPORTING iv_pdf = iv_pdf
               IMPORTING et_bin = lt_bin ev_length = lv_len ).

    lv_def = COND #( WHEN iv_filename IS NOT INITIAL THEN iv_filename
                     ELSE |documento.pdf| ).

    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING default_extension = 'pdf'
                default_file_name = lv_def
                file_filter       = 'PDF (*.pdf)|*.pdf'
      CHANGING  filename          = lv_name
                path              = lv_path
                fullpath          = lv_full
                user_action       = lv_action
      EXCEPTIONS OTHERS           = 1 ).
    IF sy-subrc <> 0.
      raise_fe( ).
    ENDIF.

    IF lv_action <> cl_gui_frontend_services=>action_ok.
      RETURN.
    ENDIF.

    cl_gui_frontend_services=>gui_download(
      EXPORTING bin_filesize = lv_len
                filename     = lv_full
                filetype     = 'BIN'
      CHANGING  data_tab     = lt_bin
      EXCEPTIONS OTHERS      = 1 ).
    IF sy-subrc <> 0.
      raise_fe( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.