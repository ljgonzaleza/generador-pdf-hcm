*&---------------------------------------------------------------------*
*& Include ZHHRR_776_SEL : pantalla de selección
*&---------------------------------------------------------------------*
PARAMETERS:
  p_pernr TYPE pernr_d        OBLIGATORY,
  p_tplid TYPE zde_cp_tpl_id  OBLIGATORY,
  p_feref TYPE datum          DEFAULT sy-datum,
  p_gen   AS CHECKBOX.
