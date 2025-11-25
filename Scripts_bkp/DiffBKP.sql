DECLARE @NombreBase NVARCHAR(50) = 'TanoSQL_Vigilancia24'
DECLARE @RutaBase NVARCHAR(256) = 'C:\Data\BKP\'
DECLARE @NombreArchivo NVARCHAR(256)
DECLARE @Fecha NVARCHAR(20)

SET @Fecha = FORMAT(GETDATE(), 'yyyyMMdd_HHmm')

-- Notar que el nombre dice DIFF
SET @NombreArchivo = @RutaBase + @NombreBase + '_DIFF_' + @Fecha + '.bak'

-- Ejecutamos el Backup con la opción DIFFERENTIAL
BACKUP DATABASE @NombreBase 
TO DISK = @NombreArchivo 
WITH DIFFERENTIAL, COMPRESSION, STATS = 10, NAME = 'Backup Diferencial';