-- =============================================
-- 3. VISTAS (VIEWS) PARA REPORTES
-- =============================================
USE TanoSQL_Vigilancia24;
GO

-- Vista 1: Estado general de Proyectos con Nombres legibles
-- Justificaci�n: Facilita la lectura para gerencia sin hacer JOINs repetitivos.
CREATE VIEW vw_Projects_Status AS
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
CREATE VIEW vw_Active_Tasks AS
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
CREATE VIEW vw_Completed_Tasks AS
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
CREATE VIEW vw_Users_Profiles AS
SELECT 
    u.name AS Usuario,
    u.email AS Email,
    up.name AS Perfil,
    u.created_at AS Fecha_Creacion
FROM users u
JOIN user_profiles up ON u.profile_id = up.id;
GO  

