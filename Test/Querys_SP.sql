--- Stored Procedures para crear usuarios ---
EXEC sp_CreateUser
    @Name = 'Ana Lopez',
    @Email = 'ana@vigilancia24.com.ar',
    @Password = 'hashAna123',
    @Profile = 'Desarrollador';
GO

--- Stored Procedures para completar una subtarea de un proyecto ---
EXEC sp_CompleteTask
    @TaskID = 2;
GO

--- Stored Procedures para crear un nuevo proyecto ---
EXEC sp_CreateProyect
    @Title = 'Sistema de Reportes Avanzados',
    @Description = 'Desarrollo de un sistema de reportes avanzados para analisis de datos.',
    @PriorityID = 3, -- Alta
    @CreateBy = 2, -- Lucas Guardon
    @StatusID = 1, -- Pendiente
    @EndDateEstimated = '2026-03-31';
GO

--- Stored Procedures para crear una nueva subtarea para un proyecto ---
EXEC sp_CreateTask
    @ProjectID = 2, -- App Gesti�n de Horarios
    @Title = 'Implementar Autenticaci�n',
    @Description = 'Desarrollar el m�dulo de autenticaci�n de usuarios con OAuth2.',
    @PriorityID = 3, -- Alta
    @StartDate = '2025-12-01',
    @DueDate = '2025-12-10',
    @StatusID = 1; -- Pendiente
GO

