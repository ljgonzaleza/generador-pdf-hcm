*&---------------------------------------------------------------------*
*& Include ZHHRR_777_TOP : declaraciones globales
*&---------------------------------------------------------------------*
CONSTANTS gc_tcode TYPE sy-tcode VALUE 'ZHHRT_777'.

DATA: gv_pernr TYPE pernr_d,
      gv_tplid TYPE zde_cp_tpl_id,
      gv_fecha TYPE datum,
      gv_user  TYPE xubname.
