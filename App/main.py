import reflex as rx
import pyodbc

# Configuración DB
CONN_STR = "DRIVER={ODBC Driver 17 for SQL Server};SERVER=LOCALHOST;DATABASE=TanoSQL_Vigilancia24;Trusted_Connection=yes;"

class State(rx.State):
    user_id: int = 0
    user_name: str = ""
    logged_in: bool = False
    
    # Variables para formularios
    email_input: str = ""
    pass_input: str = ""
    new_name: str = ""
    new_email: str = ""
    new_pass: str = ""
    new_profile: str = "Desarrollador" # Default

    def login(self):
        """Valida usuario contra la tabla users"""
        with pyodbc.connect(CONN_STR) as conn:
            cursor = conn.cursor()
            # NOTA: En producción usar hashing real. Aquí comparamos texto plano por simplicidad académica.
            query = "SELECT id, name FROM users WHERE email = ? AND password_hash = ?"
            cursor.execute(query, (self.email_input, self.pass_input))
            row = cursor.fetchone()
            
            if row:
                self.user_id = row[0]
                self.user_name = row[1]
                self.logged_in = True
                return rx.redirect("/dashboard")
            else:
                return rx.window_alert("Credenciales incorrectas")

    def register_user(self):
        """Crea usuario usando el Stored Procedure sp_CreateUser"""
        try:
            with pyodbc.connect(CONN_STR) as conn:
                cursor = conn.cursor()
                # Llamamos al SP que definiste en Stored_procedures.sql
                sql = "{CALL sp_CreateUser (?, ?, ?, ?)}"
                params = (self.new_name, self.new_email, self.new_pass, self.new_profile)
                cursor.execute(sql, params)
                conn.commit()
                return rx.window_alert("Usuario creado. Ahora puedes loguearte.")
        except Exception as e:
            return rx.window_alert(f"Error al crear usuario: {e}")

    def update_task_status(self, task_id, new_status_id):
        """Ejemplo de cómo guardar datos pasando el ID para la auditoría"""
        with pyodbc.connect(CONN_STR) as conn:
            cursor = conn.cursor()
            
            # 1. INYECTAR EL ID DEL USUARIO EN LA SESIÓN (Crucial para el Trigger)
            cursor.execute("EXEC sp_set_session_context 'UserID', ?", (self.user_id,))
            
            # 2. Ejecutar la acción normal
            cursor.execute("UPDATE subtasks SET status_id = ? WHERE id = ?", (new_status_id, task_id))
            conn.commit()

# --- VISTAS ---

def login_page():
    return rx.center(
        rx.vstack(
            rx.heading("Iniciar Sesión"),
            rx.input(placeholder="Email", on_change=State.set_email_input),
            rx.input(type="password", placeholder="Contraseña", on_change=State.set_pass_input),
            rx.button("Ingresar", on_click=State.login),
            rx.link("¿No tienes cuenta? Regístrate aquí", href="/register"),
            spacing="4"
        )
    )

def register_page():
    return rx.center(
        rx.vstack(
            rx.heading("Registro de Nuevo Usuario"),
            rx.input(placeholder="Nombre Completo", on_change=State.set_new_name),
            rx.input(placeholder="Email", on_change=State.set_new_email),
            rx.input(type="password", placeholder="Contraseña", on_change=State.set_new_pass),
            rx.select(["Administrador", "Project Manager", "Desarrollador"], on_change=State.set_new_profile),
            rx.button("Crear Cuenta", on_click=State.register_user),
            spacing="4"
        )
    )

# Configuración de Rutas
app = rx.App()
app.add_page(login_page, route="/")
app.add_page(register_page, route="/register")
# app.add_page(dashboard, route="/dashboard") # Tu dashboard iría aquí