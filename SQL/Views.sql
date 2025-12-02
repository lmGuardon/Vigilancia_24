-- =============================================
-- 3. VISTAS (VIEWS) PARA REPORTES
-- =============================================
USE TanoSQL_Vigilancia24;
GO

-- Vista 1: Estado general de Proyectos con Nombres legibles
-- Justificaci�n: Facilita la lectura para gerencia sin hacer JOINs repetitivos.
CREATE OR ALTER VIEW vw_Projects_Status AS
SELECT 
    p.name AS Proyecto,
    u_creator.name AS Creador,    
    u_assigned.name AS Lider,     
    s.name AS Estado,
    pr.name AS Prioridad,
    p.end_date_estimated AS Fecha_Fin_Estimada
FROM projects p
LEFT JOIN users u_creator ON p.created_by = u_creator.id
LEFT JOIN project_members pm ON p.id = pm.project_id
LEFT JOIN users u_assigned ON pm.user_id = u_assigned.id
JOIN statuses s ON p.status_id = s.id
JOIN priorities pr ON p.priority_id = pr.id;
GO


-- Vista 2: Tareas Pendientes o En Progreso
-- Justificaci�n: Panel operativo diario para los desarrolladores.
CREATE OR ALTER VIEW vw_Active_Tasks AS
SELECT 
    t.title AS Tarea,
    p.name AS Proyecto,
    s.name AS Estado,
    pr.name AS Prioridad,
    t.due_date AS Vencimiento
FROM subtasks t
JOIN projects p ON t.project_id = p.id
JOIN statuses s ON t.status_id = s.id
JOIN priorities pr ON t.priority_id = pr.id
WHERE s.name NOT IN ('Finalizado', 'Cancelado');
GO

-- Vista 3: Tareas Finalizadas
-- Justificaci�n: Panel operativo diario para los desarrolladores.
CREATE OR ALTER VIEW vw_Completed_Tasks AS
SELECT 
    t.title AS Tarea,
    p.name AS Proyecto,
    s.name AS Estado,
    pr.name AS Prioridad,
    t.due_date AS Vencimiento
FROM subtasks t
JOIN projects p ON t.project_id = p.id
JOIN statuses s ON t.status_id = s.id
JOIN priorities pr ON t.priority_id = pr.id
WHERE s.name IN ('Finalizado');
GO

-- Vista 4: Usuarios y sus Perfiles
-- Justificaci�n: Facilita la gesti�n de usuarios y roles.
CREATE OR ALTER VIEW vw_Users_Profiles AS
SELECT 
    u.name AS Usuario,
    u.email AS Email,
    up.role_name AS Perfil,
    u.created_at AS Fecha_Creacion
FROM users u
JOIN user_profiles up ON u.profile_id = up.id;
GO  

/*USE TanoSQL_Vigilancia24;
GO

-- 1. Asegurar que exista el estado 'Cancelado' para la lógica visual roja
IF NOT EXISTS (SELECT * FROM statuses WHERE name = 'Cancelado')
BEGIN
    INSERT INTO statuses (name) VALUES ('Cancelado');
END
GO*/

-- 5. VISTA PARA EL TABLERO (Proyectos)
-- Muestra la info del proyecto y un resumen de progreso calculado al vuelo
CREATE OR ALTER VIEW vw_Kanban_Projects AS
SELECT 
    p.id AS ProjectID,
    p.name AS Titulo,
    p.description AS Descripcion,
    p.status_id AS StatusID,
    s.name AS Estado,
    s.name AS StatusName, -- Para usar en filtros
    pr.name AS Prioridad,
    u.name AS Leader,
    -- Métricas simples para mostrar en la tarjeta
    (SELECT COUNT(*) FROM subtasks WHERE project_id = p.id) AS TotalTareas,
    (SELECT COUNT(*) FROM subtasks WHERE project_id = p.id AND status_id = (SELECT id FROM statuses WHERE name = 'Finalizado')) AS TareasCompletadas
FROM projects p
JOIN statuses s ON p.status_id = s.id
JOIN priorities pr ON p.priority_id = pr.id
JOIN project_members pm ON p.id = pm.project_id
JOIN users u ON pm.user_id = u.id;
GO

-- 6 VISTA PARA EL POPUP (Detalle de Tareas)
-- Lista simple filtrable por ProjectID
CREATE OR ALTER VIEW vw_Project_Tasks_Detail AS
SELECT 
    t.id AS TaskID,
    t.project_id AS ProjectID,
    t.title AS Titulo,
    s.name AS Estado,
    pr.name AS Prioridad,
    t.due_date AS Vencimiento
FROM subtasks t
JOIN statuses s ON t.status_id = s.id
JOIN priorities pr ON t.priority_id = pr.id;
GO

-- 7 VISTA DE LOGS DE AUDITORÍA LEGIBLES
-- Justificación: Facilita la revisión de auditoría por parte de administradores.
CREATE OR ALTER VIEW vw_Audit_Logs_Readable AS
SELECT 
    al.log_id,
    al.change_date AS Fecha,
    
    -- Traducir la tabla a nombre amigable
    CASE al.table_name
        WHEN 'users' THEN 'Usuarios'
        WHEN 'projects' THEN 'Proyectos'
        WHEN 'subtasks' THEN 'Tareas'
        ELSE al.table_name
    END AS Modulo,

    al.action_type AS Accion,
    
    -- Mostrar Nombre del usuario en lugar del ID
    -- Usamos ISNULL por si el usuario fue borrado físicamente (aunque no debería pasar con tu lógica actual)
    ISNULL(u.name, 'Usuario Sistema') AS Responsable,
    
    al.changes_summary AS Detalle,
    al.record_id AS ID_Registro_Afectado

FROM audit_logs al
LEFT JOIN users u ON al.real_user_id = u.id;
GO

