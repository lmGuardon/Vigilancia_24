DECLARE @NombreBase NVARCHAR(50) = DB_NAME() -- Toma el nombre de la base actual
DECLARE @RutaBase NVARCHAR(256) = 'C:\Data\Bkp\' -- <--- VERIFICA ESTA RUTA
DECLARE @NombreArchivo NVARCHAR(256)
DECLARE @Fecha NVARCHAR(20) = FORMAT(GETDATE(), 'yyyyMMdd_HHmm')

SET @NombreArchivo = @RutaBase + @NombreBase + '_FULL_' + @Fecha + '.bak'

BACKUP DATABASE @NombreBase 
TO DISK = @NombreArchivo 
WITH INIT, COMPRESSION, STATS = 10, NAME = 'Backup Completo';