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
    u.name AS Creador,
    s.name AS Estado,
    pr.name AS Prioridad,
    p.end_date_estimated AS Fecha_Fin_Estimada
FROM projects p
JOIN users u ON p.created_by = u.id
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

USE TanoSQL_Vigilancia24;
GO

-- 1. Asegurar que exista el estado 'Cancelado' para la lógica visual roja
IF NOT EXISTS (SELECT * FROM statuses WHERE name = 'Cancelado')
BEGIN
    INSERT INTO statuses (name) VALUES ('Cancelado');
END
GO

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
JOIN users u ON p.created_by = u.id;
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

