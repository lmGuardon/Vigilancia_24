-- =============================================
-- 1. CREACI�N DE LA BASE DE DATOS Y TABLAS
-- =============================================
IF DB_ID('TanoSQL_Vigilancia24') IS NULL
    BEGIN
        CREATE DATABASE TanoSQL_Vigilancia24;
        PRINT 'Base de datos creada exitosamente.';
    END
ELSE
    BEGIN
        PRINT 'La base de datos ya existe.';
    END
GO

USE TanoSQL_Vigilancia24;
GO


-- Tabla de Perfiles (Roles: Admin, PM, Dev)
CREATE TABLE user_profiles (
    id INT IDENTITY(1,1) PRIMARY KEY,
    role_name NVARCHAR(50) NOT NULL,
    description NVARCHAR(200)
);


-- Tabla de Usuarios
CREATE TABLE users (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) NOT NULL UNIQUE,
    password_hash NVARCHAR(255) NOT NULL, -- Simulaci�n de seguridad
    profile_id INT NOT NULL,
    created_at DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_users_profiles FOREIGN KEY (profile_id) REFERENCES user_profiles(id)
);


-- Tablas Param�tricas (Lookups)
CREATE TABLE priorities (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(50) NOT NULL -- Alta, Media, Baja
);


CREATE TABLE statuses (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(50) NOT NULL -- Nuevo, En Progreso, Finalizado
);


-- Tabla de Proyectos
CREATE TABLE projects (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(200) NOT NULL,
    description NVARCHAR(MAX),
    start_date DATE,
    end_date_estimated DATE,
    created_by INT NOT NULL, -- Qui�n cre� el proyecto
    status_id INT NOT NULL,
    priority_id INT NOT NULL,
    CONSTRAINT FK_projects_users FOREIGN KEY (created_by) REFERENCES users(id),
    CONSTRAINT FK_projects_status FOREIGN KEY (status_id) REFERENCES statuses(id),
    CONSTRAINT FK_projects_priority FOREIGN KEY (priority_id) REFERENCES priorities(id)
);


-- Tabla Intermedia: Asignaci�n de Usuarios a Proyectos (N:M)
-- Permite que un proyecto tenga m�ltiples colaboradores
CREATE TABLE project_members (
    project_id INT NOT NULL,
    user_id INT NOT NULL,        -- Usuario Miembro (Asignado)
    assigned_id INT NOT NULL,    -- Usuario que Asigna (Tu corrección)
    assignment_date DATETIME DEFAULT GETDATE(), -- Fecha de asignación (Nuevo)
    
    PRIMARY KEY (project_id, user_id),
    CONSTRAINT FK_members_project FOREIGN KEY (project_id) REFERENCES projects(id),
    CONSTRAINT FK_members_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT FK_members_assigner FOREIGN KEY (assigned_id) REFERENCES users(id) -- FK al usuario asignador
);
GO


-- Tabla de Subtareas / Tickets
CREATE TABLE subtasks (
    id INT IDENTITY(1,1) PRIMARY KEY,
    project_id INT NOT NULL,
    title NVARCHAR(200) NOT NULL,
    description NVARCHAR(MAX),
    start_date DATE,
    due_date DATE,
    priority_id INT NOT NULL,
    status_id INT NOT NULL,
    CONSTRAINT FK_subtasks_project FOREIGN KEY (project_id) REFERENCES projects(id),
    CONSTRAINT FK_subtasks_priority FOREIGN KEY (priority_id) REFERENCES priorities(id),
    CONSTRAINT FK_subtasks_status FOREIGN KEY (status_id) REFERENCES statuses(id)
);


-- Tabla Intermedia: Asignaci�n de Usuarios a Tareas (N:M)
-- Permite que una tarea sea realizada por varias personas (pair programming, etc.)
CREATE TABLE subtask_assignments (
    subtask_id INT NOT NULL,
    user_id INT NOT NULL,
    assigned_id INT NOT NULL,    -- Usuario que asigna
    assignment_date DATETIME DEFAULT GETDATE(),
    
    PRIMARY KEY (subtask_id, user_id),
    CONSTRAINT FK_assign_subtask FOREIGN KEY (subtask_id) REFERENCES subtasks(id),
    CONSTRAINT FK_assign_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT FK_assign_assigner FOREIGN KEY (assigned_id) REFERENCES users(id)
);
GO

-- Tabla de Auditor�a
-- Registra cambios importantes en proyectos y tareas
CREATE TABLE audit_logs (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    table_name NVARCHAR(50),
    action_type NVARCHAR(20),
    record_id INT,
    real_user_id INT, -- Aquí guardaremos el ID del usuario de la App (Vigilancia24)
    change_date DATETIME DEFAULT GETDATE(),
    changes_summary NVARCHAR(MAX) -- Ej: "Prioridad: Alta -> Baja"
);
GO

