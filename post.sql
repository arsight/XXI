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
   ,xxi.TEXT_CDDOLG(ncdaagrid, TO_DATE('15.11.2016','dd.mm.yyyy'))  dolg
   ,adr_1, adr_2
   ,ncdaagrid
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
)  
  order by  UPPER(ccusname)



CREATE OR REPLACE FUNCTION XXI.text_cddolg(a_id number, a_date DATE) 
  return varchar2
  as
  text1 VARCHAR2(2000);
  rtmp NUMBER;
begin
IF cdenv.Change_LSDate(a_date) != a_date then   RETURN '(!2)'; END IF;
IF CDFINE.RECALC_FINE_REP(A_id,'AI',1,0) != 1 THEN RETURN '(!)'; END IF;
rtmp  := CDSQLA.initValues;
rtmp  := CDSQLA.initVarCharValues;
select
LISTAGG(comments||' '||CHR(9)||mOst_txt,' '||CHR(10)) within group (order by n) 
/* итоги - доработать, т.к. подсчет идет с разным знаком см. договор Алексеева, например
|| decode( max(mSum), null,'', chr(10)||chr(9)||chr(10)||'всего:'||max(mSum) ||' '||decode(cdterms2.get_curISO(a_id),'RUR','руб.',cdterms2.get_curISO(a_id)))
|| chr(10) 
|| case when cdsqla.getValueI(1) <> 0 then '( '||num2str(cdsqla.getValueI(1), cdterms2.get_curISO(a_id) )||' ):' else '' end
|| chr(10) 
||case when cdsqla.getValueI(1) <> 0 then to_char(cdsqla.getValueI(1),'FM999G999G999D00') else '' end
*/
into text1
  from
(
select row_number() over (order by x.n), /* 1 */
x.n,     /* 2 */
x.mOst,  /* 3 */
case x.n
when 1 then '-задолженность по основному долгу'
when 2 then '-задолженность по процентам'
when 3 then '-задолженность по комиссиям'
when 4 then '-задолженность по приобретенному требованию на проценты'
when 5 then '-задолженность по приобретенному требованию на пени'
when 6 then '-задолженность по приобретенному требованию на комиссии'
when 11 then '-задолженность по просроченному основному долгу'
when 12 then '-задолженность по просроченным процентам '
when 13 then '-задолженность по просроченным комиссиям'
when 14 then '-задолженность по просроченному приобретенному требованию на проценты'
when 15 then '-задолженность по просроченному приобретенному требованию на пени'
when 16 then '-задолженность по просроченному приобретенному требованию на комиссии'
when 21 then '-штраф за неисполнение или ненадлежащее исполнение обязательств по возврату кредита'
end comments,   /* 4 */
trim( to_char(ABS(x.mOst),'999G999G990D00')||' '||substr(ko_ap.Get_Cur_Name(x.mOst, cdterms2.get_curISO(a_id), ''),1,3)||'.') mOst_txt,
to_char(trunc(x.mOst),'FM9999G999G999'),  /*5*/
to_char(100*(round(x.mOst - trunc(x.mOst),2) ),'FM00'), /*6*/
ko_ap.Get_Cur_Name(x.mOst, cdterms2.get_curISO(a_id), ''), /* 7 */
substr(num2str(x.mOst,cdterms2.get_curISO(a_id)),instr(num2str(x.mOst,cdterms2.get_curISO(a_id)),' ',-1)+1 ), /* 8 */
cdsqla.addvalues(1, x.mOst ) mSum         /* 9 */
from
(
select -- cdstate2.Get_Debit_Credit_TOD(a_id,a_date),cdstate.Get_Debit_Credit_TO(a_id,a_date),
      1 n, 
      greatest(  cdbalance.get_cursaldo(a_id,1)+
           cdbalance.get_cursaldo(a_id,701)+
           decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)  *  nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 701, a_date),0)
        ,0)
      mOst -- Osn
from dual
union all
select 2 n, nvl(sum(mCdiAccrued),0) - nvl(sum(mCdiPayed),0) mOst --mProc
from v_cdi where cCdiRT in ('O','R') and nCdiAgrId = a_id
and dCdiPmtDue >= a_date and dCdiPmtDue <= ( select min(dCdiPmtDue) from v_cdi where cCdiRT in ('O','R')  and dCdiPmtDue >= a_date and nCdiAgrId = a_id )
union all
select 3 n, nvl(sum(mCdkTotal),0) - nvl(sum(mCdkPayed),0) mOst -- mCom
from v_cdk,v_cdz
where nCdkAgrId = a_id
and nCdkAgrId = nCdzAgrId
and iCdkComId = iCdzComId
and cCdkRT in ('R')
and iCmfType = 0  -- не штраф.ком.
and dCdkPmtDue >= a_date and dCdkPmtDue <= ( select min(dCdkPmtDue) from v_cdk k where k.cCdkRT in ('R')  and k.dCdkPmtDue >= a_date and k.nCdkAgrId = a_id and k.iCdkComId = iCdzComId )
union all
select 4 n, greatest(cdbalance.get_cursaldo(a_id,705)+decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 705, a_date),0)+
       cdbalance.get_cursaldo(a_id,735)+decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 735, a_date),0) ,0)  mOst --ProcTreb
from dual
union all
select 5 n,greatest(cdbalance.get_cursaldo(a_id,771)+decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 771, a_date),0) +
       cdbalance.get_cursaldo(a_id,775)+decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 775, a_date),0) ,0)    mOst -- TrebFine
from dual
union all
select 6 n,greatest(cdbalance.get_cursaldo(a_id,781)+decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 781, a_date),0),0)    mOst -- TrebCom
from dual
union all
select 11 n,greatest(cdbalance.get_cursaldo(a_id,5)+cdbalance.get_cursaldo(a_id,711)+decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 711, a_date),0),0) mOst --Prosr
from dual
union all
select 12 n, nvl(sum(mCdiTotal),0) - nvl(sum(mCdiPayed),0) mOst--mProsrPr
from v_cdi where cCdiRT in ('O','R') and dCdiPmtDue < a_date and nCdiAgrId = a_id
union all
select 13 n, nvl(sum(mCdkTotal),0) - nvl(sum(mCdkPayed),0) mOst -- mComPr
from v_cdk,v_cdz
where nCdkAgrId = a_id
and nCdkAgrId = nCdzAgrId
and iCdkComId = iCdzComId
and cCdkRT in ('R')
and dCdkPmtDue < a_date
and iCmfType = 0  -- не штраф.ком.
union all
select 14 n,greatest(cdbalance.get_cursaldo(a_id,715)++decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 715, a_date),0)+
       cdbalance.get_cursaldo(a_id,755)+decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 755, a_date),0),0)   mOst -- ProsrTrebPr
from dual
union all
select 15 n,greatest(cdbalance.get_cursaldo(a_id,772)+decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 772, a_date),0) ,0)    mOst -- TrebFinePr
from dual
union all
select 16 n,greatest(cdbalance.get_cursaldo(a_id,785)+decode(vbg_cdrep.Get_TypeDiscont(a_id),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(a_id, 785, a_date),0) ,0)    mOst -- TrebComPr
from dual
union all
select 21 n,sum (mOst)
    from (
    select nvl(sum(mCdkTotal),0) - nvl(sum(mCdkPayed),0) mOst -- mComShtraf
    from v_cdk,v_cdz
    where nCdkAgrId = a_id
    and nCdkAgrId = nCdzAgrId
    and iCdkComId = iCdzComId
    and cCdkRT in ('R')
    and dCdkPmtDue < a_date
    and iCmfType = 1  -- штраф.ком.
    union all
    select nvl(sum(mCdfUnPayed),0) mOst  -- пени
    from v_cdf where nCdfAgrId = a_id
    )
) x
where mOst != 0 
  order by 1
);
RETURN text1;
END;
/

 select xxi.TEXT_CDDOLG(29661, TO_DATE('15.11.2016','dd.mm.yyyy'))  dolg from dual
 
 
