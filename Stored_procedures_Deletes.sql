USE TanoSQL_Vigilancia24;
GO

-- =============================================
-- 1. ELIMINAR TAREA (Simple)
-- =============================================
CREATE OR ALTER PROCEDURE sp_DeleteTask
    @TaskID INT,
    @UserID INT -- Para el Session Context (Auditoría)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 1. Inyectar UserID para el Trigger de Auditoría
    -- Si el trigger de 'subtasks' intenta leer SESSION_CONTEXT, lo encontrará.
    EXEC sp_set_session_context 'UserID', @UserID;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- A. Eliminar asignaciones (Tabla intermedia N:M)
        -- No requiere confirmación especial según requerimiento
        DELETE FROM subtask_assignments WHERE subtask_id = @TaskID;

        -- B. Eliminar la tarea
        -- Al ejecutar este DELETE, se disparará automáticamente el Trigger trg_Audit_Subtasks
        DELETE FROM subtasks WHERE id = @TaskID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW; -- Relanzar error para que Reflex se entere
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
    @TargetUserID INT, -- Usuario a borrar
    @AdminUserID INT,  -- Quien ejecuta la acción (para auditoría)
    @Confirm BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_set_session_context 'UserID', @AdminUserID;

    DECLARE @ActiveAssignmentsCount INT;
    DECLARE @ErrorMsg NVARCHAR(200);

    -- 1. Validaciones
    IF @Confirm = 0
    BEGIN
        -- Contar en cuántos proyectos o tareas ACTIVAS está el usuario
        -- (Sumamos tareas activas + proyectos activos donde sea miembro)
        SELECT @ActiveAssignmentsCount = 
            (
                SELECT COUNT(*) 
                FROM subtask_assignments sa
                JOIN subtasks t ON sa.subtask_id = t.id
                JOIN statuses s ON t.status_id = s.id
                WHERE sa.user_id = @TargetUserID AND s.name NOT IN ('Finalizado', 'Cancelado')
            ) + (
                SELECT COUNT(*)
                FROM project_members pm
                JOIN projects p ON pm.project_id = p.id
                JOIN statuses s ON p.status_id = s.id
                WHERE pm.user_id = @TargetUserID AND s.name NOT IN ('Finalizado', 'Cancelado')
            );

        IF @ActiveAssignmentsCount > 0
        BEGIN
            SET @ErrorMsg = CONCAT('ADVERTENCIA: El usuario tiene asignaciones en ', 
                                   @ActiveAssignmentsCount, ' items activos (Proyectos o Tareas).');
            THROW 51000, @ErrorMsg, 1;
        END
    END

    -- 2. Ejecución
    BEGIN TRANSACTION;
    BEGIN TRY
        -- A. Desasignar de Tareas (Dejar "sin personal asignado")
        DELETE FROM subtask_assignments WHERE user_id = @TargetUserID;

        -- B. Desasignar de Proyectos
        DELETE FROM project_members WHERE user_id = @TargetUserID;

        -- C. IMPORTANTE: Manejo de Foreign Key 'created_by' en Projects
        -- Si el usuario creó proyectos, no podemos borrarlo por la FK.
        -- Solución: Reasignar la autoría al Admin (ID 1) o al usuario que está borrando.
        -- Asumiremos reasignar al ID 1 (Admin default) para mantener integridad.
        UPDATE projects 
        SET created_by = 1 
        WHERE created_by = @TargetUserID;

        -- D. Borrar Usuario
        -- Dispara trg_Audit_Users
        DELETE FROM users WHERE id = @TargetUserID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO