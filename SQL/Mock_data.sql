-- ==================================================================================
-- SCRIPT DE GENERACIÓN DE DATOS MOCK (MASIVO Y ROBUSTO)
-- ==================================================================================
-- NOTA: Este script borra los datos existentes para empezar limpio.

SET NOCOUNT ON;

PRINT '1. Limpiando datos existentes...';
-- Deshabilitar constraints temporalmente para limpieza rápida
EXEC sp_MSforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all";

DELETE FROM audit_logs;
DELETE FROM subtask_assignments;
DELETE FROM subtasks;
DELETE FROM project_members;
DELETE FROM projects;
DELETE FROM users;
DELETE FROM statuses;
DELETE FROM priorities;
DELETE FROM user_profiles;

-- Habilitar constraints nuevamente
EXEC sp_MSforeachtable "ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all";
DBCC CHECKIDENT ('audit_logs', RESEED, 0); -- Reiniciar contadores de ID
DBCC CHECKIDENT ('subtasks', RESEED, 0);
DBCC CHECKIDENT ('projects', RESEED, 0);
DBCC CHECKIDENT ('users', RESEED, 0);
DBCC CHECKIDENT ('statuses', RESEED, 0);
DBCC CHECKIDENT ('priorities', RESEED, 0);
DBCC CHECKIDENT ('user_profiles', RESEED, 0);
GO


PRINT '2. Insertando Datos Paramétricos...';
-- Perfiles
INSERT INTO user_profiles (role_name, description) VALUES 
('Administrador', 'Control total y auditoría'),
('Project Manager', 'Gestión de equipos y proyectos'),
('Desarrollador', 'Ejecución técnica');

-- Prioridades
INSERT INTO priorities (name) VALUES ('Baja'), ('Media'), ('Alta'), ('Crítica');

-- Estados (Incluye Cancelado como pediste)
INSERT INTO statuses (name) VALUES ('Pendiente'), ('En Progreso'), ('QA / Testing'), ('Finalizado'), ('Cancelado');


PRINT '3. Generando Usuarios...';
-- 3 Usuarios Base (Los que usas para Login)
INSERT INTO users (name, email, password_hash, profile_id) VALUES 
('Maximiliano Juarez', 'mjuarez@vigilancia24.com', 'hash123', 1), -- ID 1: Admin
('Lucas Guardon', 'lguardon@vigilancia24.com', 'hash456', 2),    -- ID 2: PM
('Dev Junior', 'dev1@vigilancia24.com', 'hash789', 3);          -- ID 3: Dev

-- 5 Usuarios Extra (Generados para tener equipo)
INSERT INTO users (name, email, password_hash, profile_id) VALUES 
('Ana Backend', 'ana@vigilancia24.com', 'hash_ana', 3),
('Carlos Frontend', 'carlos@vigilancia24.com', 'hash_carlos', 3),
('Sofia QA', 'sofia@vigilancia24.com', 'hash_sofia', 3),
('Pedro DevOps', 'pedro@vigilancia24.com', 'hash_pedro', 3),
('Laura TechLead', 'laura@vigilancia24.com', 'hash_laura', 2); -- Otro PM


PRINT '4. Generando 10 Proyectos...';
DECLARE @i INT = 1;
DECLARE @AdminID INT = 1; -- Maximiliano
DECLARE @PMID INT = 2;    -- Lucas

WHILE @i <= 10
BEGIN
    -- Alternar Creador entre Admin y PM
    DECLARE @CreatorID INT = CASE WHEN @i % 2 = 0 THEN @PMID ELSE @AdminID END;
    
    -- Insertar Proyecto
    INSERT INTO projects (name, description, start_date, end_date_estimated, created_by, status_id, priority_id)
    VALUES (
        CONCAT('Proyecto ', @i, ': Sistema ', CHAR(64+@i)), -- Nombres tipo "Sistema A, B..."
        'Proyecto generado automáticamente para pruebas de carga y dashboard.',
        GETDATE(),
        DATEADD(DAY, 30 + (@i*5), GETDATE()), -- Fecha fin variable
        @CreatorID, -- created_by (Requisito nuevo)
        CASE WHEN @i > 8 THEN 4 ELSE 2 END, -- Algunos finalizados (4), otros en progreso (2)
        (@i % 4) + 1 -- Prioridad rotativa
    );

    DECLARE @NewProjID INT = SCOPE_IDENTITY();

    -- Asignar Líder al Proyecto (En project_members)
    -- Asignamos al creador como miembro también
    INSERT INTO project_members (project_id, user_id, assigned_id, assignment_date)
    VALUES (@NewProjID, @CreatorID, @AdminID, GETDATE());

    -- Asignar un Dev aleatorio al proyecto (ID 3 a 8)
    DECLARE @RandomDev INT = 3 + (@i % 5); 
    INSERT INTO project_members (project_id, user_id, assigned_id, assignment_date)
    VALUES (@NewProjID, @RandomDev, @CreatorID, GETDATE());

    SET @i = @i + 1;
END;


PRINT '5. Generando 30 Tareas...';
SET @i = 1;
WHILE @i <= 30
BEGIN
    -- Seleccionar un proyecto al azar (IDs 1 a 10)
    -- Fórmula: FLOOR(RAND()*(Max-Min+1)+Min)
    DECLARE @RndProject INT = FLOOR(RAND()*(10-1+1)+1);
    
    -- Seleccionar Prioridad y Estado al azar
    DECLARE @RndPriority INT = FLOOR(RAND()*(4-1+1)+1);
    DECLARE @RndStatus INT = FLOOR(RAND()*(5-1+1)+1); -- 1 a 5 (incluye cancelado)

    INSERT INTO subtasks (project_id, title, description, start_date, due_date, priority_id, status_id)
    VALUES (
        @RndProject,
        CONCAT('Ticket #', @i, ' - Requerimiento funcional'),
        'Descripción genérica de la tarea para pruebas de volumen.',
        GETDATE(),
        DATEADD(DAY, @i, GETDATE()), -- Vencimiento escalonado
        @RndPriority,
        @RndStatus
    );

    DECLARE @NewTaskID INT = SCOPE_IDENTITY();

    -- Asignar la tarea a un usuario (Del 1 al 8)
    DECLARE @RndUser INT = FLOOR(RAND()*(8-1+1)+1);
    
    -- Insertar Asignación (Respetando assigned_id)
    INSERT INTO subtask_assignments (subtask_id, user_id, assigned_id, assignment_date)
    VALUES (
        @NewTaskID, 
        @RndUser, -- Usuario que hace la tarea
        1,        -- assigned_id (Digamos que el Admin asignó todo masivamente)
        GETDATE()
    );

    SET @i = @i + 1;
END;

PRINT '=======================================';
PRINT '   CARGA DE DATOS FINALIZADA EXITOSAMENTE';
PRINT '=======================================';
GO