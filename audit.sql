select * from dba_audit_session
  where TIMESTAMP>TO_DATE('07.09.2016','DD.MM.YYYY')
AND 
 TIMESTAMP<TO_DATE('08.09.2016','DD.MM.YYYY')
 AND ACTION_NAME='LOGON'
 AND USERNAME NOT IN ('IBANK','IBANK_MSK')
 and userhost not in ('WS061SPB','SPB\SRV17SPB','srv14gc','srv11gc')
