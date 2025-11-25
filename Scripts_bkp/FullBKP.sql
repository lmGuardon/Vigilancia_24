DECLARE @NombreBase NVARCHAR(50) = 'TanoSQL_Vigilancia24' -- <--- CAMBIA ESTO
DECLARE @RutaBase NVARCHAR(256) = 'C:\Data\BKP\'
DECLARE @NombreArchivo NVARCHAR(256)
DECLARE @Fecha NVARCHAR(20)

-- Obtenemos la fecha formato AñoMesDia_HoraMinuto (ej: 20231125_1830)
SET @Fecha = FORMAT(GETDATE(), 'yyyyMMdd_HHmm')

-- Armamos el nombre: C:\Data\BKP\MiBase_FULL_20231125_1830.bak
SET @NombreArchivo = @RutaBase + @NombreBase + '_FULL_' + @Fecha + '.bak'

-- Ejecutamos el Backup
BACKUP DATABASE @NombreBase 
TO DISK = @NombreArchivo 
WITH INIT, COMPRESSION, STATS = 10, NAME = 'Backup Completo';