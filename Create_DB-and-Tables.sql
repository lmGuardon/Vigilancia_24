-- =============================================
-- 1. CREACIÓN DE LA BASE DE DATOS Y TABLAS
-- =============================================
CREATE DATABASE TanoSQL_Vigilancia24;
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
    password_hash NVARCHAR(255) NOT NULL, -- Simulación de seguridad
    profile_id INT NOT NULL,
    created_at DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_users_profiles FOREIGN KEY (profile_id) REFERENCES user_profiles(id)
);


-- Tablas Paramétricas (Lookups)
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
    created_by INT NOT NULL, -- Quién creó el proyecto
    status_id INT NOT NULL,
    priority_id INT NOT NULL,
    CONSTRAINT FK_projects_users FOREIGN KEY (created_by) REFERENCES users(id),
    CONSTRAINT FK_projects_status FOREIGN KEY (status_id) REFERENCES statuses(id),
    CONSTRAINT FK_projects_priority FOREIGN KEY (priority_id) REFERENCES priorities(id)
);


-- Tabla Intermedia: Asignación de Usuarios a Proyectos (N:M)
-- Permite que un proyecto tenga múltiples colaboradores
CREATE TABLE project_members (
    project_id INT NOT NULL,
    user_id INT NOT NULL,
    assigned_at DATETIME DEFAULT GETDATE(),
    PRIMARY KEY (project_id, user_id),
    CONSTRAINT FK_members_project FOREIGN KEY (project_id) REFERENCES projects(id),
    CONSTRAINT FK_members_user FOREIGN KEY (user_id) REFERENCES users(id)
);


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


-- Tabla Intermedia: Asignación de Usuarios a Tareas (N:M)
-- Permite que una tarea sea realizada por varias personas (pair programming, etc.)
CREATE TABLE subtask_assignments (
    subtask_id INT NOT NULL,
    user_id INT NOT NULL,
    PRIMARY KEY (subtask_id, user_id),
    CONSTRAINT FK_assign_subtask FOREIGN KEY (subtask_id) REFERENCES subtasks(id),
    CONSTRAINT FK_assign_user FOREIGN KEY (user_id) REFERENCES users(id)
);
GO

