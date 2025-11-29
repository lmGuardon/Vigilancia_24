-- =============================================
-- 2. MOCK DATA (DATOS DE PRUEBA)
-- =============================================
USE TanoSQL_Vigilancia24;
GO

-- Insertar Perfiles
INSERT INTO user_profiles (role_name, description) VALUES 
('Administrador', 'Acceso total al sistema'),
('Project Manager', 'Gestión de proyectos y reportes'),
('Desarrollador', 'Ejecución de tareas técnicas');


-- Insertar Prioridades
INSERT INTO priorities (name) VALUES ('Baja'), ('Media'), ('Alta'), ('Crítica');


-- Insertar Estados
INSERT INTO statuses (name) VALUES ('Pendiente'), ('En Progreso'), ('QA / Testing'), ('Finalizado'), ('Cancelado');


-- Insertar Usuarios (Basado en el PDF)
INSERT INTO users (name, email, password_hash, profile_id) VALUES 
('Maximiliano Juarez', 'mjuarez@vigilancia24.com', 'hash123', 1), -- Admin
('Lucas Guardon', 'lguardon@vigilancia24.com', 'hash456', 2), -- PM
('Dev Junior', 'dev1@vigilancia24.com', 'hash789', 3); -- Dev


-- Insertar Proyectos
INSERT INTO projects (name, description, start_date, end_date_estimated, created_by, status_id, priority_id) VALUES 
('Migración SQL Server 2025', 'Actualización del motor de base de datos central.', '2025-10-01', '2025-12-01', 1, 2, 4),
('App Gestión de Horarios', 'Nueva app interna para RRHH.', '2025-11-15', '2026-02-20', 2, 1, 3),
('Limpieza DB Soft', 'Mantenimiento trimestral de la DB del Soft de monitoreo.', '2025-11-25', '2025-11-26', 1, 1, 3),
('Telefonia IP', 'Actualización de servidores para telefonia IP.', '2025-11-15', '2026-01-15', 2, 1, 2);


-- Asignar miembros al proyecto de Migración
INSERT INTO project_members (project_id, user_id) VALUES (1, 1), (1, 3),(2,2),(2,1),(3,1),(3,2),(3,3);


-- Insertar Tareas (Subtasks)
INSERT INTO subtasks (project_id, title, description, start_date, due_date, priority_id, status_id) VALUES 
(1, 'Backup Full Inicial', 'Realizar backup completo antes de migrar.', '2025-10-02', '2025-10-03', 4, 4), -- Finalizada
(1, 'Instalación Instancia', 'Instalar nueva instancia en server paralelo.', '2025-10-05', '2025-10-10', 3, 2), -- En Progreso
(2, 'Diseño de Mockups', 'Diseñar pantallas de login.', '2025-11-20', '2025-11-25', 2, 1), -- Pendiente
(3, 'Simulacro limpieza', 'Relizar un simulacro de la limpieza agendandos tiempos de cada paso.', '2025-11-25', '2025-11-25', 1, 2), -- En Progreso
(4, 'Compra de servidores', 'Relizar pedido de los servers con sus correspondientes partes.', '2025-10-01', '2025-11-01', 2, 4); -- Finalizado


-- Asignar tareas
INSERT INTO subtask_assignments (subtask_id, user_id) VALUES (1, 1), (2, 3),(5,3),(4,2);
GO


