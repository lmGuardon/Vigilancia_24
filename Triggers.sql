-- Trigger para auditar cambios en la tabla 'projects'
-- Justificaci�n: Permite rastrear cambios importantes para auditor�a y seguridad.
CREATE TRIGGER trg_Audit_Projects
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
-- Justificaci�n: Permite rastrear cambios importantes para auditor�a y seguridad.
CREATE TRIGGER trg_Audit_Subtasks
ON subtasks
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @RealUserID INT;
    -- Leemos la variable de sesión que enviaremos desde Python
    SET @RealUserID = CAST(SESSION_CONTEXT(N'UserID') AS INT);

    -- Si no viene usuario (ej. correcciones manuales por DB Admin), ponemos NULL o 0
    IF @RealUserID IS NULL SET @RealUserID = 0; 

    DECLARE @ChangeLog NVARCHAR(MAX) = '';

    -- Comparar columnas clave (Ejemplo: Status y Prioridad)
    -- Si el Status cambió...
    IF UPDATE(status_id)
    BEGIN
        SELECT @ChangeLog = @ChangeLog + 
               CONCAT('Status: ', d.status_id, ' -> ', i.status_id, '. ')
        FROM inserted i JOIN deleted d ON i.id = d.id
        WHERE i.status_id <> d.status_id;
    END

    -- Si la Prioridad cambió...
    IF UPDATE(priority_id)
    BEGIN
        SELECT @ChangeLog = @ChangeLog + 
               CONCAT('Prioridad: ', d.priority_id, ' -> ', i.priority_id, '. ')
        FROM inserted i JOIN deleted d ON i.id = d.id
        WHERE i.priority_id <> d.priority_id;
    END

    -- Solo insertamos si hubo cambios relevantes
    IF LEN(@ChangeLog) > 0
    BEGIN
        INSERT INTO audit_logs (table_name, action_type, record_id, real_user_id, changes_summary)
        SELECT 'subtasks', 'UPDATE', i.id, @RealUserID, @ChangeLog
        FROM inserted i;
    END
END;
GO

-- Trigger para auditar cambios en la tabla 'users'
-- Justificaci�n: Crucial para seguridad, especialmente cambios de perfil y contraseñas.
CREATE TRIGGER trg_Audit_Users
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