--- Stored Procedures para crear usuarios ---
USE [TanoSQL_Vigilancia24]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[sp_CreateUser]
		@Name = N'Lucas Guardòn',
		@Email = N'lmguardon@vigilancia24.com',
		@Password = N'Clave$123',
		@Profile = N'Administrador'

SELECT	'Return Value' = @return_value

GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[sp_CreateUser]
		@Name = N'Maximiliano Juarez',
		@Email = N'mjuarez@vigilancia24.com',
		@Password = N'Clave$123',
		@Profile = N'Desarrollador'

SELECT	'Return Value' = @return_value

GO

--- Stored Procedures para completar una subtarea de un proyecto ---
EXEC sp_CompleteTask
    @TaskID = 2;
GO

--- Stored Procedures para crear un nuevo proyecto ---
--USE [TanoSQL_Vigilancia24]
--GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[sp_CreateProyect]
		@Title = N'Nuevo Projecto',
		@Description = N'Este es un nuevo projecto del "caminoo feliz"',
		@PriorityID = 2,
		@CreateBy = 1,
		@StatusID = 1,
		@EndDateEstimated = N'2025-12-08'

SELECT	'Return Value' = @return_value

GO

--- Stored Procedures para crear una nueva subtarea para un proyecto ---
DECLARE	@return_value int

EXEC	@return_value = [dbo].[sp_CreateTaskAndAssign]
		@ProjectID = 1,
		@Title = N'Nueva Task',
		@PriorityID = 3,
		@AssignedUserID = 2

SELECT	'Return Value' = @return_value

GO

