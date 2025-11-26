-- =============================================
-- 4. PROCEDIMIENTOS ALMACENADOS (STORED PROCEDURES)
-- =============================================
USE TanoSQL_Vigilancia24;
GO

-- SP 1: Crear una nueva tarea y asignarla autom�ticamente
-- Justificaci�n: Encapsula la l�gica de negocio (crear + asignar) en una sola transacci�n.
CREATE OR ALTER PROCEDURE sp_CreateTaskAndAssign
    @ProjectID INT,
    @Title NVARCHAR(200),
    @PriorityID INT,
    @AssignedUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NewTaskID INT;


    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1. Insertar la tarea
        INSERT INTO subtasks (project_id, title, start_date, priority_id, status_id)
        VALUES (@ProjectID, @Title, GETDATE(), @PriorityID, 1); -- 1 = Pendiente

        SET @NewTaskID = SCOPE_IDENTITY();


        -- 2. Asignar el usuario
        INSERT INTO subtask_assignments (subtask_id, user_id)
        VALUES (@NewTaskID, @AssignedUserID);


        COMMIT TRANSACTION;
        PRINT 'Tarea creada y asignada exitosamente.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error al crear la tarea.';
    END CATCH
END;
GO

-- SP 2: Crear un nuevo proyecto
-- Justificaci�n: Encapsula la l�gica de negocio (crear proyecto).
CREATE OR ALTER PROCEDURE sp_CreateProyect
    @Title NVARCHAR(200),
    @Description NVARCHAR(1000),
    @PriorityID INT,
    @CreateBy INT,
    @StatusID INT,
    @EndDateEstimated DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1. Insertar el proyecto
        INSERT INTO projects (name, description, created_by, priority_id, status_id, start_date, end_date_estimated)
        VALUES (@Title, @Description, @CreateBy, @PriorityID, @StatusID, GETDATE(), @EndDateEstimated);

        COMMIT TRANSACTION;
        PRINT 'Proyecto creada exitosamente.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error al crear proyecto.';
    END CATCH
END;
GO


-- SP 3: Completar Tarea
-- Justificaci�n: Simplifica el cierre de tareas actualizando estado.
CREATE OR ALTER PROCEDURE sp_CompleteTask
    @TaskID INT
AS
BEGIN
    UPDATE subtasks
    SET status_id = (SELECT id FROM statuses WHERE name = 'Finalizado')
    WHERE id = @TaskID;
END;
GO

-- SP 4: Crear un nuevo usuario
-- Justificaci�n: Encapsula la l�gica de negocio (crear usuarios).
CREATE OR ALTER PROCEDURE sp_CreateUser
    @Name NVARCHAR(100),
    @Email NVARCHAR(255),
    @Password NVARCHAR(255),
    @Profile NVARCHAR(50)

AS
BEGIN
    DECLARE @Profile_id INT;

    BEGIN TRANSACTION;
    BEGIN TRY
        
        -- 0. Obtener el profile_id seg�n el nombre del perfil
        SELECT @Profile_id = id FROM user_profiles WHERE role_name = @Profile;

        -- 1. Insertar el usuario
        INSERT INTO users (name, email, password_hash, profile_id, created_at)
        VALUES (@Name, @Email, @Password, @Profile_id, GETDATE());

        COMMIT TRANSACTION;
        PRINT 'Usuario creado exitosamente.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error al crear un Usuario.';
    END CATCH
END;
GO

-- SP 5: Mover Tarea a otro estado
-- Justificaci�n: Facilita la actualizaci�n del estado de una tarea.
CREATE OR ALTER PROCEDURE sp_MoveTask
    @TaskID INT,
    @NewStatusID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- El trigger trg_Audit_Subtasks se encargará de auditar
    -- usando el UserID que inyectaremos desde Python.
    
    UPDATE subtasks 
    SET status_id = @NewStatusID
    WHERE id = @TaskID;
END;
GO