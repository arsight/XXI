-- справка по кредитам 800505-960034 - справка о задолженности по договору
--1- Дата и пользователь
select
 sysdate                                v01,
 UTIL.Date2Str(sysdate)                 v02,
 CD.get_LSdate                          v03,
 UTIL.Date2Str(CD.get_LSdate)           v04,
 DJ_DATE.Get_MonthRus(CD.get_LSdate)    v05,
 to_char(CD.get_LSdate,'YYYY')          v06,
 user                                   v07,
 USERS_UTILITIES.Get_Name_By_User(user) v08,
 cdrep_util.Get_USER_PHON(user)         v09,
 to_char(CD.get_LSdate,'DD.MM.RRRR')    v10,
 (select SHORT_NAME from USR
  where CUSRLOGNAME = user)             v11,
 to_char(CD.get_LSdate+1,'DD.MM.RRRR')  v12,
 to_char(CD.get_LSdate-1,'DD.MM.RRRR')  v13,
 rates.CUR_RATE_NEW('USD',CD.Get_LSDate) v14,
 rates.CUR_RATE_NEW('EUR',CD.Get_LSDate) v15,
 rates.CUR_RATE_NEW('USD',CD.Get_LSDate - 1) v16,
 rates.CUR_RATE_NEW('EUR',CD.Get_LSDate - 1) v17,
 (select cUSRposition from USR
  where CUSRLOGNAME = user)             v18,
 to_char(last_day(CD.get_LSdate)+1,'DD.MM.RRRR')  v19,
 :p1 v20,:p2 v21,:p3 v22,:p4 v23,:p5 v24,:p6 v25,:p7 v26,:p8 v27,:p9 v28,:p10 v29,
 CDSQLA.initValues,
 CDSQLA.initVarCharValues ---
from dual


--2--- CD Расчет договора
select CDFINE.RECALC_FINE_REP(:p1,'AI',1,0) from dual


--10----- CD Доп. сведения о клиенте
select cus_util.get_cus_name(iCdaClient), /* 1 */
cus_util.get_cus_address(iCdaClient,3),   /* 2 */
decline(cus_util.get_cus_name(iCdaClient), pcusattr.get_cli_atr(359,iCdaClient,cd.get_lsdate,0,0), 'Р'), /* 3 */
case when iCdaCes = 1  or cCdaUIndex='цс'  then
     'Настоящим ПАО "Выборг-банк" уведомляет о том, что между '||case when dCdaSignDate < to_date('01.11.2015','dd.mm.yyyy') then 'ОАО "Выборг-банк"' else 'ПАО "Выборг-банк"' end||' и '||case when instr(cCdaAgrmnt,'КПК')>0 then 'КПК "СБЕРКАССА № 1" ' else 'БАНКОМ ИТБ (АО) ' end || util.date2str(dCdaSignDate)||' был заключен Договор уступки прав требования (цессия).'
     else '' end, /* 4 */
to_char(dCdaSignDate,'dd.mm.yyyy'), /* 5 */
cCDaAgrmnt, /* 6 */
util.date2str(dCdaSignDate) /* 7 */
from cda where nCdaAgrId = :p1

--20 ----- CD сведения о задолженности по договору
select row_number() over (order by x.n), /* 1 */
x.n,     /* 2 */
x.mOst,  /* 3 */
case x.n
when 1 then '-задолженность по основному долгу'
when 2 then '-задолженность по процентам '
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
when 21 then '-штрафа за неисполнение или ненадлежащее исполнение обязательств по возврату потребительского кредита согласно п.12 Индивидуальных условий договора.'
end comments,   /* 4 */
to_char(trunc(x.mOst),'FM9999G999G999'),  /*5*/
to_char(100*(round(x.mOst - trunc(x.mOst),2) ),'FM00'), /*6*/
ko_ap.Get_Cur_Name(x.mOst, cdterms2.get_curISO(:p1), ''), /* 7 */
substr(num2str(x.mOst,cdterms2.get_curISO(:p1)),instr(num2str(x.mOst,cdterms2.get_curISO(:p1)),' ',-1)+1 ), /* 8 */
cdsqla.addvalues(1, x.mOst ) mSum         /* 9 */
from
(
select -- cdstate2.Get_Debit_Credit_TOD(:p1,cd.get_lsdate),cdstate.Get_Debit_Credit_TO(:p1,cd.get_lsdate),
      1 n, greatest(cdbalance.get_cursaldo(:p1,1)+cdbalance.get_cursaldo(:p1,701)+decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 701, cd.get_lsdate),0),0) mOst -- Osn
from dual
union all
select 2 n, nvl(sum(mCdiAccrued),0) - nvl(sum(mCdiPayed),0) mOst --mProc
from v_cdi where cCdiRT in ('O','R') and nCdiAgrId = :p1
and dCdiPmtDue >= cd.get_lsdate and dCdiPmtDue <= ( select min(dCdiPmtDue) from v_cdi where cCdiRT in ('O','R')  and dCdiPmtDue >= cd.get_lsdate and nCdiAgrId = :p1 )
union all
select 3 n, nvl(sum(mCdkTotal),0) - nvl(sum(mCdkPayed),0) mOst -- mCom
from v_cdk,v_cdz
where nCdkAgrId = :p1
and nCdkAgrId = nCdzAgrId
and iCdkComId = iCdzComId
and cCdkRT in ('R')
and iCmfType = 0  -- не штраф.ком.
and dCdkPmtDue >= cd.get_lsdate and dCdkPmtDue <= ( select min(dCdkPmtDue) from v_cdk k where k.cCdkRT in ('R')  and k.dCdkPmtDue >= cd.get_lsdate and k.nCdkAgrId = :p1 and k.iCdkComId = iCdzComId )
union all
select 4 n, greatest(cdbalance.get_cursaldo(:p1,705)+decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 705, cd.get_lsdate),0)+
       cdbalance.get_cursaldo(:p1,735)+decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 735, cd.get_lsdate),0) ,0)  mOst --ProcTreb
from dual
union all
select 5 n,greatest(cdbalance.get_cursaldo(:p1,771)+decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 771, cd.get_lsdate),0) +
       cdbalance.get_cursaldo(:p1,775)+decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 775, cd.get_lsdate),0) ,0)    mOst -- TrebFine
from dual
union all
select 6 n,greatest(cdbalance.get_cursaldo(:p1,781)+decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 781, cd.get_lsdate),0),0)    mOst -- TrebCom
from dual
union all
select 11 n,greatest(cdbalance.get_cursaldo(:p1,5)+cdbalance.get_cursaldo(:p1,711)+decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 711, cd.get_lsdate),0),0) mOst --Prosr
from dual
union all
select 12 n, nvl(sum(mCdiTotal),0) - nvl(sum(mCdiPayed),0) mOst--mProsrPr
from v_cdi where cCdiRT in ('O','R') and dCdiPmtDue < cd.get_lsdate and nCdiAgrId = :p1
union all
select 13 n, nvl(sum(mCdkTotal),0) - nvl(sum(mCdkPayed),0) mOst -- mComPr
from v_cdk,v_cdz
where nCdkAgrId = :p1
and nCdkAgrId = nCdzAgrId
and iCdkComId = iCdzComId
and cCdkRT in ('R')
and dCdkPmtDue < cd.get_lsdate
and iCmfType = 0  -- не штраф.ком.
union all
select 14 n,greatest(cdbalance.get_cursaldo(:p1,715)++decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 715, cd.get_lsdate),0)+
       cdbalance.get_cursaldo(:p1,755)+decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 755, cd.get_lsdate),0),0)   mOst -- ProsrTrebPr
from dual
union all
select 15 n,greatest(cdbalance.get_cursaldo(:p1,772)+decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 772, cd.get_lsdate),0) ,0)    mOst -- TrebFinePr
from dual
union all
select 16 n,greatest(cdbalance.get_cursaldo(:p1,785)+decode(vbg_cdrep.Get_TypeDiscont(:p1),1,+1,2,-1,0)*nvl(vbg_cdrep.Get_OstPremDiscont(:p1, 785, cd.get_lsdate),0) ,0)    mOst -- TrebComPr
from dual
union all
select 21 n,sum (mOst)
    from (
    select nvl(sum(mCdkTotal),0) - nvl(sum(mCdkPayed),0) mOst -- mComShtraf
    from v_cdk,v_cdz
    where nCdkAgrId = :p1
    and nCdkAgrId = nCdzAgrId
    and iCdkComId = iCdzComId
    and cCdkRT in ('R')
    and dCdkPmtDue < cd.get_lsdate
    and iCmfType = 1  -- штраф.ком.
    union all
    select nvl(sum(mCdfUnPayed),0) mOst  -- пени
    from v_cdf where nCdfAgrId = :p1
    )
) x
where mOst != 0
order by 1



-- 30 Вывод итога по 32905115
select case when cdsqla.getValueI(1) <> 0 then to_char(cdsqla.getValueI(1),'FM999G999G999D00') else '' end,
case when cdsqla.getValueI(1) <> 0 then
    case when  iCdaCes = 1  or cCdaUIndex='цс'  then
      'По состоянию на '||util.date2str(cd.get_lsdate)||' у клиента Банка '||decline(cus_util.get_cus_name(iCdaClient), pcusattr.get_cli_atr(359,iCdaClient,cd.get_lsdate,0,0), 'Р')
    else
      'Настоящим ПАО "Выборг-банк" уведомляет, что у '||decline(cus_util.get_cus_name(iCdaClient), pcusattr.get_cli_atr(359,iCdaClient,cd.get_lsdate,0,0), 'Р')||' на '||util.date2str(cd.get_lsdate)
    end||' имеется задолженность по договору '||case when  iCdaCes = 1  or cCdaUIndex='цс'  then 'с учетным номером ' else '' end || cCdaAgrmnt ||' от '|| util.date2str(dCdaSignDate)|| ' в размере '
else
    case when  iCdaCes = 1  or cCdaUIndex='цс'  then
      'По состоянию на '||util.date2str(cd.get_lsdate)||' клиент Банка '||cus_util.get_cus_name(iCdaClient)||' договор с учетным номером '||
      ' № '||cCdaAgrmnt ||' от '|| util.date2str(dCdaSignDate)||' , '||case when pcusattr.get_cli_atr(359,iCdaClient,cd.get_lsdate,0,0)='F' then 'исполнила ' else 'исполнил ' end ||'обязательства перед Банком полностью.'
    else
      'Настоящим ПАО "Выборг-банк" уведомляет, что на '||util.date2str(cd.get_lsdate)||' '||cus_util.get_cus_name(iCdaClient)||', договор потребительского кредита № '||cCdaAgrmnt ||' от '|| util.date2str(dCdaSignDate)||', '||
      case when pcusattr.get_cli_atr(359,iCdaClient,cd.get_lsdate,0,0)='F' then 'исполнила ' else 'исполнил ' end||'обязательства перед Банком полностью.'
    end
end,
case when cdsqla.getValueI(1) <> 0 then '( '||num2str(cdsqla.getValueI(1), cCdaCurISO )||' ):' else '' end
from cda where nCdaAgrId = :p1



--40 -  Подписант от Банка в отделении, Кредиты (:p10 )
SELECT o.CCDOFFCNAME1,       /*1*/
       o.CCDOFFCNAME2,       /*2*/
       o.CCDOFFCAPP1,       /*3*/
       o.CCDOFFCAPP2,       /*4*/
       o.CCDOFFCNDOC,       /*5*/
       to_char(o.DCDOFFCDDOC, 'DD.MM.RRRR')||'г.',       /*6*/
       o.CCDOFFCNOTE,       /*7*/
       o.CCDOFFCGROUND_G,       /*8*/
       SUBSTR(o.CCDOFFCNAME1, INSTR(o.CCDOFFCNAME1, ' ', 1, 1) + 1, 1)||'. '||
       SUBSTR(o.CCDOFFCNAME1, INSTR(o.CCDOFFCNAME1, ' ', 1, 2) + 1, 1)||'. ' ||
       SUBSTR(o.CCDOFFCNAME1, 1, INSTR(o.CCDOFFCNAME1,' ')),       /*9*/
       o.ICDOFFCOTD,       /*10*/
--
       DECODE(n.iotdnum,NULL,'г.Выборг',1,'г.Приморск',2,'г.Светогорск',4,'пос.Рощино',5,'г.Выборг',6,'г.Выборг',8,'г.Москва',14,'г.Ростов-на-Дону','г.Выборг'), /*11*/
       DECODE(n.iotdnum,NULL,' ',0,' ',n.COTDNAME),       /*12*/
       DECODE(n.iotdnum,NULL,'г.Выборг',n.COTDADDRESS)       /*13*/
FROM cdoffc o,  OTD n
WHERE o.nCdOffcId = substr(:p10,decode(instr(:p10,',',-1),0,1,instr(:p10,',',-1)+1)) and
      n.iotdnum=o.ICDOFFCOTD
      
      
-- 50 -Сохранение выбора подписанта
select vbg_rep.sav_defaultSign4cd_spr_zdlg1( substr(:p10,decode(instr(:p10,',',-1),0,1,instr(:p10,',',-1)+1)) )
from dual









