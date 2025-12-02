USE TanoSQL_Vigilancia24;
GO

-- =============================================
-- 1. ELIMINAR TAREA (Simple)
-- =============================================
CREATE OR ALTER PROCEDURE sp_DeleteTask
    @TaskID INT,
    @UserID INT,      -- Usuario que ejecuta (para auditoría)
    @Confirm BIT = 0  -- 0: Verificar Estado / 1: Forzar Borrado
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 0. Contexto de Auditoría
    EXEC sp_set_session_context 'UserID', @UserID;

    DECLARE @TaskStatus NVARCHAR(50);
    DECLARE @TaskTitle NVARCHAR(200);
    DECLARE @ErrorMsg NVARCHAR(200);

    -- 1. Validaciones (Solo si @Confirm = 0)
    IF @Confirm = 0
    BEGIN
        -- Obtenemos estado y título de la tarea
        SELECT @TaskStatus = s.name, @TaskTitle = t.title
        FROM subtasks t
        JOIN statuses s ON t.status_id = s.id
        WHERE t.id = @TaskID;

        -- Si no existe la tarea, salimos
        IF @TaskStatus IS NULL
        BEGIN;
            THROW 51004, 'Error: La tarea especificada no existe.', 1;
        END

        -- Validar si está activa (No Finalizada ni Cancelada)
        IF @TaskStatus NOT IN ('Finalizado', 'Cancelado')
        BEGIN
            SET @ErrorMsg = CONCAT('ADVERTENCIA: La tarea "', @TaskTitle, '" se encuentra en estado ', @TaskStatus, 
                                   '. Ejecute con @Confirm=1 para proceder.');
            THROW 51000, @ErrorMsg, 1;
        END
    END

    -- 2. Ejecución
    BEGIN TRANSACTION;
    BEGIN TRY
        -- A. Eliminar asignaciones (Tabla intermedia)
        DELETE FROM subtask_assignments WHERE subtask_id = @TaskID;

        -- B. Eliminar la tarea (Dispara Trigger trg_Audit_Subtasks)
        DELETE FROM subtasks WHERE id = @TaskID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- =============================================
-- 2. ELIMINAR PROYECTO (Con Lógica de Advertencia)
-- =============================================
CREATE OR ALTER PROCEDURE sp_DeleteProject
    @ProjectID INT,
    @UserID INT,
    @Confirm BIT = 0 -- 0: Chequear Advertencias, 1: Borrar Forzado
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_set_session_context 'UserID', @UserID;

    DECLARE @ActiveTasksCount INT;
    DECLARE @ProjectStatus NVARCHAR(50);
    DECLARE @ErrorMsg NVARCHAR(200);

    -- 1. Validaciones previas (Solo si NO está confirmado)
    IF @Confirm = 0
    BEGIN
        -- Obtener estado del proyecto
        SELECT @ProjectStatus = s.name 
        FROM projects p JOIN statuses s ON p.status_id = s.id 
        WHERE p.id = @ProjectID;

        -- Contar tareas no finalizadas/canceladas
        SELECT @ActiveTasksCount = COUNT(*) 
        FROM subtasks t
        JOIN statuses s ON t.status_id = s.id
        WHERE t.project_id = @ProjectID 
          AND s.name NOT IN ('Finalizado', 'Cancelado');

        -- Lógica de Advertencia
        IF (@ProjectStatus NOT IN ('Finalizado', 'Cancelado')) OR (@ActiveTasksCount > 0)
        BEGIN
            SET @ErrorMsg = CONCAT('ADVERTENCIA: El proyecto está en estado ', @ProjectStatus, 
                                   ' y tiene ', @ActiveTasksCount, ' tareas activas.');
            
            -- Lanzamos un error controlado (Código 51000 es custom)
            THROW 51000, @ErrorMsg, 1;
        END
    END
    -- 2. Ejecución del Borrado (Si llegamos acá es porque pasó el check o @Confirm = 1)
    BEGIN TRANSACTION;
    BEGIN TRY
        -- A. Borrar asignaciones de Miembros del Proyecto
        DELETE FROM project_members WHERE project_id = @ProjectID;

        -- B. Borrar Asignaciones de Tareas relacionadas
        DELETE FROM subtask_assignments 
        WHERE subtask_id IN (SELECT id FROM subtasks WHERE project_id = @ProjectID);

        -- C. Borrar Tareas del Proyecto
        -- Esto disparará n veces el trigger de subtasks (o uno por lote)
        DELETE FROM subtasks WHERE project_id = @ProjectID;

        -- D. Borrar el Proyecto
        -- Esto disparará trg_Audit_Projects
        DELETE FROM projects WHERE id = @ProjectID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- =============================================
-- 3. ELIMINAR USUARIO (Con Lógica de Advertencia y Reasignación)
-- =============================================
CREATE OR ALTER PROCEDURE sp_DeleteUser
    @TargetUserID INT,         -- Usuario a eliminar
    @AdminUserID INT,          -- Quien ejecuta (Auditoría)
    @Confirm BIT = 0,          -- 0: Solo chequear / 1: Ejecutar
    @HeirUserID INT = NULL     -- (Opcional) ID del usuario que heredará la carga
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 0. Contexto para Triggers existentes
    EXEC sp_set_session_context 'UserID', @AdminUserID;

    DECLARE @ActiveAssignmentsCount INT;
    DECLARE @ErrorMsg NVARCHAR(200);
    DECLARE @IsAdmin BIT;
    DECLARE @TargetUserName NVARCHAR(100);
    DECLARE @HeirUserName NVARCHAR(100);

    -- Obtener nombre del usuario a borrar para el log
    SELECT @TargetUserName = name FROM users WHERE id = @TargetUserID;
    
    -- 1. Seguridad: Verificar si quien ejecuta es Admin
    SELECT @IsAdmin = CASE WHEN up.role_name = 'Administrador' THEN 1 ELSE 0 END
    FROM users u
    JOIN user_profiles up ON u.profile_id = up.id
    WHERE u.id = @AdminUserID;
    
    IF @IsAdmin = 0 OR @IsAdmin IS NULL
        THROW 51001, 'Solo un Administrador puede borrar usuarios.', 1;

    -- 2. Definir Heredero (Prioridad: Parámetro -> Automático)
    IF @HeirUserID IS NULL
    BEGIN
        -- Buscar otro admin disponible automáticamente
        SELECT TOP 1 @HeirUserID = id FROM users WHERE profile_id = 1 AND id <> @TargetUserID;
    END

    -- Validar Heredero Final
    IF @HeirUserID IS NULL OR @HeirUserID = @TargetUserID
        THROW 51002, 'Error: Debe especificar un usuario heredero válido (diferente al usuario a eliminar).', 1;

    -- Obtener nombre del heredero para el log
    SELECT @HeirUserName = name FROM users WHERE id = @HeirUserID;

    -- 3. Advertencia (Preview)
    IF @Confirm = 0
    BEGIN
        SELECT @ActiveAssignmentsCount = 
            (SELECT COUNT(*) FROM subtask_assignments sa
             JOIN subtasks t ON sa.subtask_id = t.id
             JOIN statuses s ON t.status_id = s.id
             WHERE sa.user_id = @TargetUserID AND s.name NOT IN ('Finalizado', 'Cancelado')) 
            + 
            (SELECT COUNT(*) FROM project_members pm
             JOIN projects p ON pm.project_id = p.id
             JOIN statuses s ON p.status_id = s.id
             WHERE pm.user_id = @TargetUserID AND s.name NOT IN ('Finalizado', 'Cancelado'));

        IF @ActiveAssignmentsCount > 0
        BEGIN
            SET @ErrorMsg = CONCAT('ADVERTENCIA: El usuario tiene ', @ActiveAssignmentsCount, 
                                   ' asignaciones activas. Se reasignarán a: ', @HeirUserName, 
                                   ' (ID: ', @HeirUserID, '). Confirme para proceder.');
            THROW 51000, @ErrorMsg, 1;
        END
    END

    -- 4. Ejecución Transaccional
    BEGIN TRANSACTION;
    BEGIN TRY
        
        -- LOG DE INICIO DE TRASPASO
        INSERT INTO audit_logs (table_name, action_type, record_id, real_user_id, changes_summary)
        VALUES ('users', 'MIGRATION', @TargetUserID, @AdminUserID, 
                CONCAT('Iniciando traspaso de responsabilidades de ', @TargetUserName, ' hacia ', @HeirUserName));

        -- A. Reasignar PROYECTOS CREADOS (projects.created_by)
        UPDATE projects 
        SET created_by = @HeirUserID 
        WHERE created_by = @TargetUserID;

        -- B. Reasignar MIEMBROS DE PROYECTOS (project_members.user_id)
        -- Estrategia: Transferir si no existe, borrar si ya existe (Merge)
        UPDATE pm
        SET user_id = @HeirUserID
        FROM project_members pm
        WHERE pm.user_id = @TargetUserID
          AND NOT EXISTS (
              SELECT 1 FROM project_members check_pm 
              WHERE check_pm.project_id = pm.project_id AND check_pm.user_id = @HeirUserID
          );
        -- Borrar remanentes (donde el heredero ya estaba)
        DELETE FROM project_members WHERE user_id = @TargetUserID;

        -- C. Reasignar HISTORIAL DE ASIGNACIONES (assigned_id) en Proyectos
        UPDATE project_members 
        SET assigned_id = @HeirUserID 
        WHERE assigned_id = @TargetUserID;


        -- D. Reasignar MIEMBROS DE TAREAS (subtask_assignments.user_id)
        UPDATE sa
        SET user_id = @HeirUserID
        FROM subtask_assignments sa
        WHERE sa.user_id = @TargetUserID
          AND NOT EXISTS (
              SELECT 1 FROM subtask_assignments check_sa 
              WHERE check_sa.subtask_id = sa.subtask_id AND check_sa.user_id = @HeirUserID
          );
        DELETE FROM subtask_assignments WHERE user_id = @TargetUserID;

        -- E. Reasignar HISTORIAL DE ASIGNACIONES (assigned_id) en Tareas
        UPDATE subtask_assignments 
        SET assigned_id = @HeirUserID 
        WHERE assigned_id = @TargetUserID;


        -- F. Borrar Usuario
        -- Esto disparará el Trigger trg_Audit_Users automáticamente
        DELETE FROM users WHERE id = @TargetUserID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO