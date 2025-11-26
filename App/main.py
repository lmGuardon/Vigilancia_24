import reflex as rx
import pandas as pd
import pyodbc

# --- 1. CONFIGURACIÓN DB ---
CONN_STR = "DRIVER={ODBC Driver 17 for SQL Server};SERVER=LOCALHOST;DATABASE=TanoSQL_Vigilancia24;Trusted_Connection=yes;"

# --- 2. ESTADO (LÓGICA) ---
class State(rx.State):
    """Estado único que maneja Login y Tablero"""
    
    # --- Variables de Sesión ---
    user_id: int = 0
    user_name: str = ""
    logged_in: bool = False
    
    # --- Variables de Login/Registro ---
    email_input: str = ""
    pass_input: str = ""
    new_name: str = ""
    new_email: str = ""
    new_pass: str = ""
    new_profile: str = "Desarrollador" 

    # --- Variables del Tablero Kanban ---
    tasks: list[dict] = []
    columns: list[dict] = [
        {"id": 1, "name": "Pendiente", "color": "gray"},
        {"id": 2, "name": "En Progreso", "color": "blue"},
        {"id": 3, "name": "QA / Testing", "color": "orange"},
        {"id": 4, "name": "Finalizado", "color": "green"},
    ]

    # --- SETTERS (Para evitar el DeprecationWarning) ---
    def set_email_input(self, val): self.email_input = val
    def set_pass_input(self, val): self.pass_input = val
    def set_new_name(self, val): self.new_name = val
    def set_new_email(self, val): self.new_email = val
    def set_new_pass(self, val): self.new_pass = val
    def set_new_profile(self, val): self.new_profile = val

    # --- FUNCIONES DE LOGIN ---
    def login(self):
        with pyodbc.connect(CONN_STR) as conn:
            cursor = conn.cursor()
            # Validación simple para el parcial
            query = "SELECT id, name FROM users WHERE email = ? AND password_hash = ?"
            cursor.execute(query, (self.email_input, self.pass_input))
            row = cursor.fetchone()
            
            if row:
                self.user_id = row[0]
                self.user_name = row[1]
                self.logged_in = True
                # Redireccionar al Dashboard al tener éxito
                return rx.redirect("/dashboard")
            else:
                return rx.window_alert("Credenciales incorrectas")

    def register_user(self):
        try:
            with pyodbc.connect(CONN_STR) as conn:
                cursor = conn.cursor()
                # Usamos el SP que definiste
                sql = "{CALL sp_CreateUser (?, ?, ?, ?)}"
                params = (self.new_name, self.new_email, self.new_pass, self.new_profile)
                cursor.execute(sql, params)
                conn.commit()
                return rx.window_alert("Usuario creado. Ahora puedes loguearte.")
        except Exception as e:
            return rx.window_alert(f"Error al crear usuario: {e}")

    # --- FUNCIONES DEL TABLERO ---
    def load_board(self):
        """Carga la vista vw_Kanban_Board"""
        try:
            with pyodbc.connect(CONN_STR) as conn:
                query = "SELECT * FROM vw_Kanban_Board"
                df = pd.read_sql(query, conn)
                df = df.fillna("") 
                self.tasks = df.to_dict('records')
        except Exception as e:
            print(f"Error cargando tablero: {e}")

    def move_card(self, task_id: int, new_status_id: int):
        try:
            with pyodbc.connect(CONN_STR) as conn:
                cursor = conn.cursor()
                # 1. Auditoría: Usamos el ID del usuario logueado (self.user_id)
                # Si es 0 (ej. pruebas sin login), mandamos 1 por defecto
                uid_to_send = self.user_id if self.user_id != 0 else 1
                cursor.execute("EXEC sp_set_session_context 'UserID', ?", (uid_to_send,))
                
                # 2. Mover tarea (SP creado anteriormente)
                cursor.execute("EXEC sp_MoveTask ?, ?", (task_id, new_status_id))
                conn.commit()
            
            self.load_board()
        except Exception as e:
            return rx.window_alert(f"Error moviendo tarjeta: {e}")

# --- 3. COMPONENTES UI (DISEÑO) ---

def badge_priority(priority: str):
    color_map = {"Alta": "red", "Media": "yellow", "Baja": "blue", "Crítica": "crimson"}
    return rx.badge(priority, color_scheme=color_map.get(priority, "gray"), variant="solid")

def task_card(task: dict):
    return rx.box(
        rx.vstack(
            rx.flex(
                rx.text(task["Proyecto"], font_size="10px", color="gray.400", weight="bold"),
                rx.spacer(),
                badge_priority(task["Prioridad"]),
                width="100%"
            ),
            rx.text(task["Titulo"], font_weight="bold", color="white", font_size="14px"),
            rx.text(f"Resp: {task['Responsables']}", font_size="11px", color="gray.500"),
            rx.hstack(
                # AQUÍ ESTABA EL ERROR: Agregamos .to(int)
                rx.cond(
                    task["StatusID"].to(int) > 1,
                    rx.button("←", on_click=lambda: State.move_card(task["TaskID"], task["StatusID"] - 1), size="1", variant="surface"),
                ),
                rx.spacer(),
                # AQUÍ TAMBIÉN: Agregamos .to(int)
                rx.cond(
                    task["StatusID"].to(int) < 4,
                    rx.button("→", on_click=lambda: State.move_card(task["TaskID"], task["StatusID"] + 1), size="1", variant="surface"),
                ),
                width="100%",
                padding_top="5px"
            ),
            align_items="start",
            spacing="2"
        ),
        padding="15px",
        border_radius="8px",
        bg="gray.800",
        border="1px solid #4A5568",
        width="100%",
        box_shadow="md"
    )

def kanban_column(column: dict):
    return rx.vstack(
        rx.hstack(
            rx.badge(column["name"], color_scheme=column["color"], variant="surface", size="3"),
            width="100%",
            padding_bottom="10px"
        ),
        rx.foreach(
            State.tasks,
            lambda task: rx.cond(
                # AQUÍ TAMBIÉN: Aseguramos la comparación correcta
                task["StatusID"].to(int) == column["id"].to(int),
                task_card(task),
                rx.fragment()
            )
        ),
        bg="gray.900",
        padding="15px",
        border_radius="12px",
        min_width="280px",
        min_height="500px",
        height="100%",
        align_items="start"
    )

# --- 4. PAGINAS ---

def login_page():
    return rx.center(
        rx.vstack(
            rx.heading("Vigilancia 24", size="8", color="blue.500"),
            rx.text("Sistema de Gestión de Proyectos", color="gray.400"),
            rx.input(placeholder="Email", on_change=State.set_email_input, width="100%"),
            rx.input(type="password", placeholder="Contraseña", on_change=State.set_pass_input, width="100%"),
            rx.button("Iniciar Sesión", on_click=State.login, width="100%", size="3"),
            rx.link("¿No tienes cuenta? Regístrate aquí", href="/register", color="blue.400"),
            spacing="4",
            bg="gray.900",
            padding="40px",
            border_radius="15px",
            border="1px solid #4A5568",
            width="400px"
        ),
        height="100vh",
        bg="#111"
    )

def register_page():
    return rx.center(
        rx.vstack(
            rx.heading("Crear Cuenta", color="white"),
            rx.input(placeholder="Nombre Completo", on_change=State.set_new_name, width="100%"),
            rx.input(placeholder="Email", on_change=State.set_new_email, width="100%"),
            rx.input(type="password", placeholder="Contraseña", on_change=State.set_new_pass, width="100%"),
            rx.select(["Administrador", "Project Manager", "Desarrollador"], on_change=State.set_new_profile, default_value="Desarrollador"),
            rx.button("Registrarme", on_click=State.register_user, width="100%", color_scheme="green"),
            rx.link("Volver al Login", href="/", color="gray.500"),
            spacing="4",
            bg="gray.900",
            padding="40px",
            border_radius="15px",
            border="1px solid #4A5568",
            width="400px"
        ),
        height="100vh",
        bg="#111"
    )

def dashboard_page():
    return rx.box(
        rx.vstack(
            rx.hstack(
                rx.heading("Tablero de Tareas", color="white", size="6"),
                rx.spacer(),
                rx.text(f"Usuario: {State.user_name}", color="blue.300"),
                rx.button("Salir", on_click=rx.redirect("/"), variant="outline", size="1"),
                width="100%",
                padding_bottom="20px"
            ),
            rx.flex(
                rx.foreach(State.columns, kanban_column),
                spacing="4",
                flex_wrap="wrap",
                width="100%",
                justify="center"
            ),
            width="95%",
            padding="20px"
        ),
        bg="#1A202C",
        min_height="100vh"
    )

# --- 5. RUTAS ---
app = rx.App(theme=rx.theme(appearance="dark"))
app.add_page(login_page, route="/")
app.add_page(register_page, route="/register")
app.add_page(dashboard_page, route="/dashboard", on_load=State.load_board)