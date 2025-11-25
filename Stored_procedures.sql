-- =============================================
-- 4. PROCEDIMIENTOS ALMACENADOS (STORED PROCEDURES)
-- =============================================
USE TanoSQL_Vigilancia24;
GO

-- SP 1: Crear una nueva tarea y asignarla autom�ticamente
-- Justificaci�n: Encapsula la l�gica de negocio (crear + asignar) en una sola transacci�n.
CREATE PROCEDURE sp_CreateTaskAndAssign
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
CREATE PROCEDURE sp_CreateProyect
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
CREATE PROCEDURE sp_CompleteTask
    @TaskID INT
AS
BEGIN
    UPDATE subtasks
    SET status_id = (SELECT id FROM statuses WHERE name = 'Finalizado')
    WHERE id = @TaskID;
END;
GO
