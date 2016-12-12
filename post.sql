--post_rassilka
select
  CCDAAGRMNT,
  DCDASIGNDATE,
  ccusname, 
  CUS_UTIL.GET_CUS_ADDRESS (icusnum,adrnum)  adr,
  CUS_UTIL.GET_CUS_ADDRESS_INDEX (icusnum,adrnum) ind,
  adrnum,
  (SELECT  ' '||';'||POST_INDEX||';'||UPPER(REG_NAME)||';'||UPPER(AREA)||';'||  UPPER(CITY)||';;'||  CUS_UTIL.GET_CUS_NAME(ICDACLIENT)||';0.016;0;0;0;0;0;1;;'||';'
            ||INFR_NAME||';'||DOM||';'||''||';'||''||';'||KORP ||';'||STROY ||';'||''         ||';'||KV||';'||''  from   CUS_ADDR where CUS_ADDR.ICUSNUM=ICDACLIENT AND ADDR_TYPE=adrnum) 
   "addr_post"
--       
from       
(
select
  CDFINE.RECALC_FINE_REP(cda.ncdaagrid,'AI',1,0) recalc,
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
  cda.DCDASTARTED
  from cda,cus, vb_tmp_list1 
  where 
        vb_tmp_list1.listurnom=cda.ccdaagrmnt
    and vb_tmp_list1.listfio = cus.ccusname  
    and cda.ICDACLIENT=cus.icusnum 
    -- order by ccusname
----   
    and
  (cda.ccdaagrmnt = '0/00117/ПД/2013/25461'
  or 
  cda.ccdaagrmnt = '3009КФ/16'
  )
)  
  order by ccusname
