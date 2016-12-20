-- список для рассылки
select
  CCDAAGRMNT,
  DCDASIGNDATE,
  ccusname, 
  CUS_UTIL.GET_CUS_ADDRESS (icusnum,adrnum)  adr,
  CUS_UTIL.GET_CUS_ADDRESS_INDEX (icusnum,adrnum) ind,
  adrnum,
  translate ((SELECT  ''||';'||POST_INDEX||';'||UPPER(REG_NAME)||';'||UPPER(AREA)||';'||  UPPER(CITY)||';;'||  CUS_UTIL.GET_CUS_NAME(ICDACLIENT)||';0.016;0;0;0;0;0;1;;'||PUNCT_TYPE||' '||PUNCT_NAME||';'
              ||INFR_NAME||' '||INFR_TYPE||';'||DOM||';'||''||';'||''||';'||KORP ||';'||STROY ||';'||''         ||';'||KV||';'||''  from   CUS_ADDR where CUS_ADDR.ICUSNUM=ICDACLIENT AND ADDR_TYPE=adrnum-1) /**/
            ,chr(9),' ') 
   "addr_post",
   xxi.TEXT_CDDOLG(ncdaagrid, TO_DATE('15.11.2016','dd.mm.yyyy'))  dolg
   ,
   adr_1,adr_2
   ,ncdaagrid
--       
from       
(
select
  (case when  CUS_UTIL.GET_CUS_ADDRESS (icusnum,2) is not null
        then 2 
  else 
  case  when CUS_UTIL.GET_CUS_ADDRESS (icusnum,3) is not null
        then 3
  else 
  case when CUS_UTIL.GET_CUS_ADDRESS (icusnum,1) is not null
       then 1
  else null
  end
  end
  end) as  adrnum,
  rownum n1,
  icusnum,
    CCDAAGRMNT,
  ICDACLIENT,
  ccusname,
  DCDASIGNDATE ,
  cda.DCDASTARTED,
  ncdaagrid,
  CUS_UTIL.GET_CUS_ADDRESS (icusnum,2) adr_2,
  CUS_UTIL.GET_CUS_ADDRESS (icusnum,1) adr_1
  from cda,cus, vb_tmp_list1 
  where 
        vb_tmp_list1.listurnom=cda.ccdaagrmnt
    and vb_tmp_list1.listfio = cus.ccusname  
    and cda.ICDACLIENT=cus.icusnum 
    -- order by ccusname
----   
  --and  (cda.ccdaagrmnt = '0/00117/ПД/2013/25461'  or   cda.ccdaagrmnt = '3009КФ/16'  or  cda.ncdaagrid in (3944) )
  --and icusnum=41595
)  
  order by UPPER(ccusname)





-- анализ пустых адресов
select * from 
(
select
  CCDAAGRMNT,
  DCDASIGNDATE,
  ccusname, 
  CUS_UTIL.GET_CUS_ADDRESS (icusnum,adrnum)  adr,
  CUS_UTIL.GET_CUS_ADDRESS_INDEX (icusnum,adrnum) ind,
  adrnum,
  translate ((SELECT  ''||';'||POST_INDEX||';'||UPPER(REG_NAME)||';'||UPPER(AREA)||';'||  UPPER(CITY)||';;'||  CUS_UTIL.GET_CUS_NAME(ICDACLIENT)||';0.016;0;0;0;0;0;1;;'||PUNCT_TYPE||' '||PUNCT_NAME||';'
              ||INFR_NAME||' '||INFR_TYPE||';'||DOM||';'||''||';'||''||';'||KORP ||';'||STROY ||';'||''         ||';'||KV||';'||''  from   CUS_ADDR where CUS_ADDR.ICUSNUM=ICDACLIENT AND ADDR_TYPE=adrnum-1) /**/
            ,chr(9),' ') 
   "addr_post",
   xxi.TEXT_CDDOLG(ncdaagrid, TO_DATE('15.11.2016','dd.mm.yyyy'))  dolg
   ,
   adr_1,adr_2
   ,ncdaagrid
   ,
     translate ((SELECT  PUNCT_TYPE||PUNCT_NAME||INFR_NAME||INFR_TYPE||DOM  from   CUS_ADDR where CUS_ADDR.ICUSNUM=ICDACLIENT AND ADDR_TYPE=adrnum-1) /**/
            ,chr(9),' ')
    t1         
--       
from       
(
select
  (case when  CUS_UTIL.GET_CUS_ADDRESS (icusnum,2) is not null
        then 2 
  else 
  case  when CUS_UTIL.GET_CUS_ADDRESS (icusnum,3) is not null
        then 3
  else 
  case when CUS_UTIL.GET_CUS_ADDRESS (icusnum,1) is not null
       then 1
  else null
  end
  end
  end) as  adrnum,
  rownum n1,
  icusnum,
    CCDAAGRMNT,
  ICDACLIENT,
  ccusname,
  DCDASIGNDATE ,
  cda.DCDASTARTED,
  ncdaagrid,
  CUS_UTIL.GET_CUS_ADDRESS (icusnum,2) adr_2,
  CUS_UTIL.GET_CUS_ADDRESS (icusnum,1) adr_1
  from cda,cus, vb_tmp_list1 
  where 
        vb_tmp_list1.listurnom=cda.ccdaagrmnt
    and vb_tmp_list1.listfio = cus.ccusname  
    and cda.ICDACLIENT=cus.icusnum 
    -- order by ccusname
----   
  --and  (cda.ccdaagrmnt = '0/00117/ПД/2013/25461'  or   cda.ccdaagrmnt = '3009КФ/16'  or  cda.ncdaagrid in (3944) )
  --and icusnum=41595
)  
) where t1 is null
  order by UPPER(ccusname)

  
 
