-- все исп. договоры
select * 
 from "cda" cda
 where 
     cda.ICDASTATUS =2             -- ( 0-черн.,1-усл., 2-исп., 3-зав.)

-- все договоры с данными клиента ФЛ и ИП
select 
   decode(cus.CCUSFLAG,'1','ФЛ','4','ИП') "ФЛ или ИП",
   ccdaagrmnt "Номер кредитного договора"
  ,dcdastarted "Дата кредитного договора"
  ,cus.ccusname "ФИО"
  , ccusdoctype "Тип документа"
  , ccuspassp_ser "Серия документа"
  , ccuspassp_num "Номер документа" 
  , to_char(dcuspassp,'DD.MM.RRRR') "Дата выдачи документа"
  , ccuspassp_place "Орган выдавший документ"
  , ccuspassp_subdiv "Код подразделения"
      , PCUSATTR.get_cli_atr( 209, cus.icusnum, to_date(:p2,'DD.MM.RRRR'), 1 ,0) "Место рождения"
      , UTIL_DM2.get_cus_address(cus.icusnum,1) "Адрес регистрации"
      , cus.CCUSSNILS "СНИЛС"
      , cus.CCUSNUMNAL "ИНН"
      , NVL(UTIL_DM2.get_cus_address(cus.icusnum,3) , UTIL_DM2.get_cus_address(cus.icusnum,2))"Адрес фактический"
      , decode(cusv.ccusphone1||cusv.ccusphone2||cusv.ccusphone3, null, ' ', 'Тел. '||RTRIM(LTRIM(cusv.ccusphone1||decode(cusv.ccusphone2,null,null,', '||cusv.ccusphone2)||
                  ', '||cusv.ccusphone3,' ,'),' ,')||' ' )||decode(cusv.ccusfax,null,' ','Факс '||ccusfax)    "Телефон"
 from "cda" cda, 
      "cus" cus, 
      cus cusv
 where 
     --cus.icusnum in  (26190,32615) and 
     cda.ICDASTATUS =2             -- ( 0-черн.,1-усл., 2-исп., 3-зав.)
     and cda.ICDACLIENT = cus.icusnum
     and cus.icusnum = cusv.icusnum
     and cus.CCUSFLAG in ('1','4')
order by 
 cus.ccusflag desc,
 cus.ccusname     
    
