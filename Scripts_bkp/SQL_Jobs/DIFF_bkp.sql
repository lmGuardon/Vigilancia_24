DECLARE @NombreBase NVARCHAR(50) = DB_NAME()
DECLARE @RutaBase NVARCHAR(256) = 'C:\Data\BKP\' -- <--- VERIFICA ESTA RUTA
DECLARE @NombreArchivo NVARCHAR(256)
DECLARE @Fecha NVARCHAR(20) = FORMAT(GETDATE(), 'yyyyMMdd_HHmm')

SET @NombreArchivo = @RutaBase + @NombreBase + '_DIFF_' + @Fecha + '.bak'

BACKUP DATABASE @NombreBase 
TO DISK = @NombreArchivo 
WITH DIFFERENTIAL, COMPRESSION, STATS = 10, NAME = 'Backup Diferencial';