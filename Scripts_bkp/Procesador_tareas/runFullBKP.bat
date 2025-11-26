@ECHO OFF
:: Script para ejecutar backups en SQL Express

:: Configura aquí tu servidor
SET SERVER=DESKTOP-FT9QSL0\SQLEXPRESS

:: Si quieres correr el FULL, usa este comando
sqlcmd -S %SERVER% -E -i "C:\Data\Scripts\FullBKP.sql"
