---------------------------------------
--91414  
-- поручительства
-- разбивка по счетам 
select 
 DOG_ID,NAME,DOG_NUM,DOG_DATE 
, acc1
, UTIL_DM2.Acc_Ostt(ismrfil, acc1, 'RUR',:P5)  ost1
, case 
    when substr(acc1,1,5) = '91312' 
    then VB_ARS_UTIL.OBESP_ATR_acc_short(acc1)
    when substr(acc1,1,5) = '91414'
    then 
      cus_util.get_cus_name(acc_util.get_acc_cusnum(acc1,'RUR',1))||chr(10)||
      cus_docum_util.get_cus_doc_info( cus_util.get_cus_main_doc_id (   acc_util.get_acc_cusnum(acc1,'RUR',1)   ) )
  end                  INFO_O1
--
, acc2
, UTIL_DM2.Acc_Ostt(ismrfil, acc2, 'RUR',:P5)  ost2
, case 
    when substr(acc2,1,5) = '91312' 
    then VB_ARS_UTIL.OBESP_ATR_acc_short(acc2)
    when substr(acc2,1,5) = '91414'
    then 
      cus_util.get_cus_name(acc_util.get_acc_cusnum(acc2,'RUR',1))||chr(10)||
      cus_docum_util.get_cus_doc_info( cus_util.get_cus_main_doc_id (   acc_util.get_acc_cusnum(acc2,'RUR',1)   ) )
  end                  INFO_O2
--
, acc3
, UTIL_DM2.Acc_Ostt(ismrfil, acc3, 'RUR',:P5)  ost3
, case 
    when substr(acc3,1,5) = '91312' 
    then VB_ARS_UTIL.OBESP_ATR_acc_short(acc3)
    when substr(acc3,1,5) = '91414'
    then 
      cus_util.get_cus_name(acc_util.get_acc_cusnum(acc3,'RUR',1))||chr(10)||
      cus_docum_util.get_cus_doc_info( cus_util.get_cus_main_doc_id (   acc_util.get_acc_cusnum(acc3,'RUR',1)   ) )
  end                  INFO_O3
--
, acc4
, UTIL_DM2.Acc_Ostt(ismrfil, acc4, 'RUR',:P5)  ost4
, case 
    when substr(acc4,1,5) = '91312' 
    then VB_ARS_UTIL.OBESP_ATR_acc_short(acc4)
    when substr(acc4,1,5) = '91414'
    then 
      cus_util.get_cus_name(acc_util.get_acc_cusnum(acc4,'RUR',1))||chr(10)||
      cus_docum_util.get_cus_doc_info( cus_util.get_cus_main_doc_id (   acc_util.get_acc_cusnum(acc4,'RUR',1)   ) )
  end                  INFO_O4
--
, acc5
, UTIL_DM2.Acc_Ostt(ismrfil, acc5, 'RUR',:P5)  ost5
, case 
    when substr(acc5,1,5) = '91312' 
    then VB_ARS_UTIL.OBESP_ATR_acc_short(acc5)
    when substr(acc5,1,5) = '91414'
    then 
      cus_util.get_cus_name(acc_util.get_acc_cusnum(acc5,'RUR',1))||chr(10)||
      cus_docum_util.get_cus_doc_info( cus_util.get_cus_main_doc_id (   acc_util.get_acc_cusnum(acc5,'RUR',1)   ) )
  end                  INFO_O5
FROM
(
select ismrfil,DOG_ID,NAME,DOG_NUM,DOG_DATE
,regexp_substr(CZOALLacc, '[^, ]+', 1, 1) acc1
, regexp_substr(CZOALLacc, '[^, ]+', 1, 2) acc2
, regexp_substr(CZOALLacc, '[^, ]+', 1, 3) acc3
, regexp_substr(CZOALLacc, '[^, ]+', 1, 4) acc4
, regexp_substr(CZOALLacc, '[^, ]+', 1, 5) acc5
, regexp_substr(CZOALLacc, '[^, ]+', 1, 6) acc6
, regexp_substr(CZOALLacc, '[^, ]+', 1, 7) acc7
, regexp_substr(CZOALLacc, '[^, ]+', 1, 8) acc8
, regexp_substr(CZOALLacc, '[^, ]+', 1, 9) acc9
, CZOALLacc
from 
(
SELECT 
  ismrfil
, cda.NCDAAGRID DOG_ID
, ccusname NAME
, cda.CCDAAGRMNT DOG_NUM
, cda.DCDASIGNDATE DOG_DATE
--, (select LISTAGG(czo.cczoschet, ',') within group (order by cczoschet) FROM czo where czo.NCZOAGRID = cda.NCDAAGRID and czo.cczoschet like '91312%' ) CZOALLid
, (select regexp_replace(regexp_replace(LISTAGG(czo.cczoschet,', ') within group (order by czo.cczoschet) || ', ', '([0-9]{1,20}, )\1{1,}','\1'), '..$', '') 
      FROM czo where czo.NCZOAGRID = cda.NCDAAGRID and 
       (
         czo.cczoschet like '91414%' 
       --  or czo.cczoschet like '91312%' 
       )
      and ((select caccprizn from acc where caccacc=czo.cczoschet) in ('О','Б','Ч','А'))    
  ) CZOALLacc 
  FROM "cus" cus,"cda" cda,"smr" smr
  WHERE
--      cda.NCDAAGRID in (9554,9485,9619,10666,10579) and
      cus.ccusflag in ('2','7','6') and 
     cda.icdaclient=cus.icusnum
   AND smr.idsmr=cda.idsmr
) where czoallacc is not null
)ORDER BY upper(name)
