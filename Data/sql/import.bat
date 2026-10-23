@ECHO OFF
SETLOCAL
REM =============
REM IMPORT CONFIG
REM =============
REM NOTE: No spaces before or after the '='!!!

REM =============
REM mysql and mysqladmin from PATH; set full paths here if they aren't on it.
SET PATH_MYSQL=mysql
SET PATH_MYSQLADMIN=mysqladmin
SET PATH_SQL="%~dp0"

SET USER=root
SET PASSWORD=
SET DBADDRESS=localhost
SET DBPORT=3306
SET DBNAME=ffxiv_server
REM =============

IF DEFINED PASSWORD (SET PASSWORD=-p%PASSWORD%)

ECHO Deleteing old database
%PATH_MYSQLADMIN% -h %DBADDRESS% -u %USER% %PASSWORD% DROP %DBNAME%

ECHO Creating new database
%PATH_MYSQLADMIN% -h %DBADDRESS% -u %USER% %PASSWORD% CREATE %DBNAME%

ECHO Loading tables into the database
cd /d %PATH_SQL%
FOR %%X IN (*.sql) DO ECHO Importing %%X & %PATH_MYSQL% %DBNAME% -h %DBADDRESS% -u %USER% %PASSWORD% < %%X
ECHO Finished!

ENDLOCAL
@ECHO ON