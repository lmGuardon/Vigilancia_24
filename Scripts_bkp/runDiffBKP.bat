@ECHO OFF
:: Script para ejecutar backups en SQL Express

:: Configura aquí tu servidor (lo saqué de tu imagen)
SET SERVER=DESKTOP-FT9QSL0\SQLEXPRESS

:: Si quieres correr el DIFF, usa este comando (descomenta quitando los ::)
sqlcmd -S %SERVER% -E -i "C:\Data\Scripts\DiffBKP.sql"