-- Trigger para auditar cambios en la tabla 'projects'
-- Justificaci�n: Permite rastrear cambios importantes para auditor�a y seguridad.
USE TanoSQL_Vigilancia24;
GO

CREATE or ALTER TRIGGER trg_Audit_Projects
ON projects
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @RealUserID INT;
    DECLARE @ChangeLog NVARCHAR(MAX) = '';
    DECLARE @ActionType NVARCHAR(20);
    DECLARE @RecordID INT;

    -- 1. Obtener el usuario real (si es NULL, ponemos 0 o un ID de sistema)
    SET @RealUserID = ISNULL(CAST(SESSION_CONTEXT(N'UserID') AS INT), 0);

    -- 2. Identificar el tipo de acción
    IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @ActionType = 'UPDATE';
        
        -- Lógica específica para UPDATE (Comparar columnas)
        -- Estado
        SELECT @ChangeLog = @ChangeLog + 
               CONCAT('Status ID: ', d.status_id, ' -> ', i.status_id, '. ')
        FROM inserted i JOIN deleted d ON i.id = d.id
        WHERE i.status_id <> d.status_id;

        -- Prioridad
        SELECT @ChangeLog = @ChangeLog + 
               CONCAT('Prioridad ID: ', d.priority_id, ' -> ', i.priority_id, '. ')
        FROM inserted i JOIN deleted d ON i.id = d.id
        WHERE i.priority_id <> d.priority_id;

        -- Fecha Estimada (Opcional, pero útil en proyectos)
        SELECT @ChangeLog = @ChangeLog + 
               CONCAT('Fin Estimado: ', d.end_date_estimated, ' -> ', i.end_date_estimated, '. ')
        FROM inserted i JOIN deleted d ON i.id = d.id
        WHERE i.end_date_estimated <> d.end_date_estimated;

        -- ID para el log
        SELECT TOP 1 @RecordID = id FROM inserted;
    END
    ELSE IF EXISTS (SELECT * FROM inserted)
    BEGIN
        SET @ActionType = 'INSERT';
        SELECT TOP 1 @RecordID = id FROM inserted;
        SELECT TOP 1 @ChangeLog = CONCAT('Proyecto creado: ', name) FROM inserted;
    END
    ELSE IF EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @ActionType = 'DELETE';
        SELECT TOP 1 @RecordID = id FROM deleted;
        SELECT TOP 1 @ChangeLog = CONCAT('Proyecto eliminado: ', name) FROM deleted;
    END
    ELSE
    BEGIN
        RETURN; -- No debería pasar, pero por seguridad.
    END

    -- 3. Insertar en Auditoría (Solo si hay algo que reportar)
    IF LEN(@ChangeLog) > 0 OR @ActionType IN ('INSERT', 'DELETE')
    BEGIN
        INSERT INTO audit_logs (table_name, action_type, record_id, real_user_id, changes_summary)
        VALUES ('projects', @ActionType, @RecordID, @RealUserID, @ChangeLog);
    END
END;
GO

-- Trigger para auditar cambios en la tabla 'subtasks'
-- Justificaci�n: Crucial para rastrear cambios en tareas (estado, prioridad, etc.)
CREATE OR ALTER TRIGGER trg_Audit_Subtasks
ON subtasks
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @RealUserID INT;
    -- Leemos la variable de sesión (igual que antes)
    SET @RealUserID = ISNULL(CAST(SESSION_CONTEXT(N'UserID') AS INT), 0);
    
    DECLARE @ChangeLog NVARCHAR(MAX) = '';
    DECLARE @ActionType NVARCHAR(20) = '';
    DECLARE @RecordID INT;

    -- =============================================
    -- CASO 1: INSERT (Solo existe tabla inserted)
    -- =============================================
    IF EXISTS (SELECT * FROM inserted) AND NOT EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @ActionType = 'INSERT';
        SELECT TOP 1 @RecordID = id FROM inserted;
        SELECT TOP 1 @ChangeLog = CONCAT('Tarea creada: ', title, '. Estado inicial: ', status_id) 
        FROM inserted;
    END

    -- =============================================
    -- CASO 2: DELETE (Solo existe tabla deleted)
    -- =============================================
    ELSE IF EXISTS (SELECT * FROM deleted) AND NOT EXISTS (SELECT * FROM inserted)
    BEGIN
        SET @ActionType = 'DELETE';
        SELECT TOP 1 @RecordID = id FROM deleted;
        SELECT TOP 1 @ChangeLog = CONCAT('Tarea eliminada: ', title) 
        FROM deleted;
    END

    -- =============================================
    -- CASO 3: UPDATE (Existen ambas tablas)
    -- =============================================
    ELSE IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @ActionType = 'UPDATE';
        SELECT TOP 1 @RecordID = id FROM inserted;

        -- Tu lógica original de comparación
        -- Estado
        IF UPDATE(status_id)
        BEGIN
            SELECT @ChangeLog = @ChangeLog + 
                   CONCAT('Status: ', d.status_id, ' -> ', i.status_id, '. ')
            FROM inserted i JOIN deleted d ON i.id = d.id
            WHERE i.status_id <> d.status_id;
        END

        -- Prioridad
        IF UPDATE(priority_id)
        BEGIN
            SELECT @ChangeLog = @ChangeLog + 
                   CONCAT('Prioridad: ', d.priority_id, ' -> ', i.priority_id, '. ')
            FROM inserted i JOIN deleted d ON i.id = d.id
            WHERE i.priority_id <> d.priority_id;
        END
        
        -- Fecha Vencimiento (Agregado opcional útil)
        IF UPDATE(due_date)
        BEGIN
            SELECT @ChangeLog = @ChangeLog + 
                   CONCAT('Vencimiento: ', d.due_date, ' -> ', i.due_date, '. ')
            FROM inserted i JOIN deleted d ON i.id = d.id
            WHERE i.due_date <> d.due_date;
        END
    END

    -- =============================================
    -- GUARDADO FINAL EN LOG
    -- =============================================
    -- Insertamos si hay un log generado (Updates relevantes) O si es Insert/Delete
    IF LEN(@ChangeLog) > 0 OR @ActionType IN ('INSERT', 'DELETE')
    BEGIN
        INSERT INTO audit_logs (table_name, action_type, record_id, real_user_id, changes_summary)
        VALUES ('subtasks', @ActionType, @RecordID, @RealUserID, @ChangeLog);
    END
END;
GO

-- Trigger para auditar cambios en la tabla 'users'
-- Justificaci�n: Crucial para seguridad, especialmente cambios de perfil y contraseñas.
CREATE OR ALTER TRIGGER trg_Audit_Users
ON users
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RealUserID INT;
    DECLARE @ChangeLog NVARCHAR(MAX) = '';
    DECLARE @ActionType NVARCHAR(20);
    DECLARE @RecordID INT;

    -- 1. Obtener el usuario real (Admin o RRHH que hace la modificación)
    SET @RealUserID = ISNULL(CAST(SESSION_CONTEXT(N'UserID') AS INT), 0);

    -- 2. Identificar acción
    IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @ActionType = 'UPDATE';
        SELECT TOP 1 @RecordID = id FROM inserted;

        -- Auditoría de Cambios
        
        -- A. Cambio de Perfil (Muy importante: escalada de privilegios)
        IF UPDATE(profile_id)
        BEGIN
            SELECT @ChangeLog = @ChangeLog + 
                   CONCAT('Perfil (Rol) ID: ', d.profile_id, ' -> ', i.profile_id, '. ')
            FROM inserted i JOIN deleted d ON i.id = d.id
            WHERE i.profile_id <> d.profile_id;
        END

        -- B. Cambio de Contraseña (IMPORTANTE: No guardar el hash, solo el evento)
        IF UPDATE(password_hash)
        BEGIN
             SET @ChangeLog = @ChangeLog + 'Contraseña modificada. ';
        END

        -- C. Cambio de Email
        IF UPDATE(email)
        BEGIN
            SELECT @ChangeLog = @ChangeLog + 
                   CONCAT('Email: ', d.email, ' -> ', i.email, '. ')
            FROM inserted i JOIN deleted d ON i.id = d.id
            WHERE i.email <> d.email;
        END
    END
    ELSE IF EXISTS (SELECT * FROM inserted)
    BEGIN
        SET @ActionType = 'INSERT';
        SELECT TOP 1 @RecordID = id FROM inserted;
        SELECT TOP 1 @ChangeLog = CONCAT('Usuario creado: ', name, ' (', email, ')') FROM inserted;
    END
    ELSE IF EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @ActionType = 'DELETE';
        SELECT TOP 1 @RecordID = id FROM deleted;
        SELECT TOP 1 @ChangeLog = CONCAT('Usuario eliminado: ', name) FROM deleted;
    END
    ELSE
    BEGIN
        RETURN;
    END

    -- 3. Guardar en Log
    IF LEN(@ChangeLog) > 0 OR @ActionType IN ('INSERT', 'DELETE')
    BEGIN
        INSERT INTO audit_logs (table_name, action_type, record_id, real_user_id, changes_summary)
        VALUES ('users', @ActionType, @RecordID, @RealUserID, @ChangeLog);
    END
END;
GO