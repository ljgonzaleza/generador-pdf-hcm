*&---------------------------------------------------------------------*
*& Include ZHHRR_775_SEL : pantalla de selección
*&---------------------------------------------------------------------*
PARAMETERS p_tpl TYPE zde_cp_tpl_id.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS:
  r_list  RADIOBUTTON GROUP acc DEFAULT 'X',
  r_new   RADIOBUTTON GROUP acc,
  r_edit  RADIOBUTTON GROUP acc,
  r_copy  RADIOBUTTON GROUP acc,
  r_deact RADIOBUTTON GROUP acc.
SELECTION-SCREEN END OF BLOCK b1.
