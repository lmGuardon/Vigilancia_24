# **🛡️ Vigilancia 24 \- Sistema de Gestión de Proyectos**

Este repositorio contiene el desarrollo de un sistema de gestión de proyectos y tareas (estilo ClickUp simplificado) para la empresa de consultoría IT **Vigilancia 24**.

El proyecto incluye el diseño y creación de una base de datos relacional robusta en **SQL Server** y un aplicativo web frontend desarrollado en **Python (Reflex)**.

## **🚀 Tecnologías Utilizadas**

* **Base de Datos:** Microsoft SQL Server (T-SQL)  
* **Backend/Frontend:** Python \+ Reflex Framework  
* **Conectividad:** PyODBC  
* **Análisis de Datos:** Pandas

## **📋 Requisitos Previos**

Para ejecutar este proyecto localmente necesitas tener instalado:

1. **Python 3.8+**: [Descargar aquí](https://www.python.org/downloads/)  
2. **SQL Server** (Express o Developer): [Descargar aquí](https://www.microsoft.com/es-es/sql-server/sql-server-downloads)  
3. **ODBC Driver 17 for SQL Server**: Necesario para que Python conecte con la DB. [Descargar aquí](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)

## **🛠️ Instalación y Configuración**

### **1\. Configuración de la Base de Datos**

Navega a la carpeta Database (o donde tengas los scripts) y ejecútalos en tu SQL Server Management Studio (SSMS) en el siguiente **orden estricto** para evitar errores de dependencias:

1. Create\_DB-and-Tables.sql \- Crea la DB y la estructura de tablas.  
2. Fix\_Vigilancia\_Final.sql \- **IMPORTANTE**: Aplica correcciones de estructura y claves foráneas.  
3. Triggers.sql \- Instala el sistema de auditoría.  
4. Stored\_procedures.sql \- Crea los procedimientos de creación (Altas).  
5. Stored\_procedures\_Deletes.sql \- Crea los procedimientos de eliminación lógica (Bajas).  
6. Update\_Tasks\_Audit.sql \- Actualiza la lógica de seguridad para tareas.  
7. Views.sql \- Crea las vistas para los reportes y el tablero Kanban.  
8. Mock\_data.sql \- (Opcional) Carga datos de prueba iniciales.

### **2\. Configuración del Aplicativo Web (Reflex)**

Abre tu terminal (PowerShell o CMD) en la carpeta App (donde está el archivo vigilancia\_app.py).

1. **Crear un entorno virtual (recomendado):**  
   python \-m venv .venv  
   .\\.venv\\Scripts\\activate

2. **Instalar dependencias:**  
   pip install reflex pyodbc pandas

3. **Inicializar Reflex (solo la primera vez):**  
   reflex init

4. **Ejecutar la aplicación:**  
   reflex run

   La aplicación debería abrirse automáticamente en http://localhost:3000.

## **🖥️ Uso del Sistema**

### **Credenciales de Prueba (si cargaste el Mock Data)**

Puedes iniciar sesión con cualquiera de estos usuarios para probar los diferentes roles:

| Rol | Email | Contraseña (Mock) |
| :---- | :---- | :---- |
| **Administrador** | mjuarez@vigilancia24.com | hash123 |
| **Project Manager** | lguardon@vigilancia24.com | hash456 |
| **Desarrollador** | dev1@vigilancia24.com | hash789 |

**Nota:** El sistema permite registrar nuevos usuarios desde la pantalla de Login.

### **Funcionalidades Clave**

* **Tablero Kanban:** Visualización de proyectos por estado (Pendiente, En Progreso, etc.).  
* **Gestión de Proyectos/Tareas:** Creación, asignación y movimiento de tarjetas.  
* **Auditoría en Tiempo Real:** Todos los cambios críticos (Borrado, Cambios de estado) quedan registrados en la tabla audit\_logs con el usuario responsable.  
* **Seguridad:** Alertas preventivas al intentar borrar usuarios o proyectos con tareas activas.

## **📂 Estructura del Repositorio**

/  
├── Database/               \# Scripts SQL  
│   ├── Create\_DB...sql  
│   ├── Stored\_procedures...sql  
│   └── ...  
├── App/                    \# Código Fuente Python  
│   ├── vigilancia\_app.py   \# Archivo principal de Reflex  
│   ├── rxconfig.py         \# Configuración de Reflex  
│   └── assets/             \# Imágenes y recursos estáticos  
└── README.md               \# Este archivo

## **🎓 Contexto Académico**

Materia: Administración de Bases de Datos  
Año: 2025  
Desarrollado por: Lucas Guardon