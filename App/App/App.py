import reflex as rx
import pandas as pd
import pyodbc

# --- 1. CONFIGURACIÓN DB ---
CONN_STR = "DRIVER={ODBC Driver 17 for SQL Server};SERVER=LOCALHOST;DATABASE=TanoSQL_Vigilancia24;Trusted_Connection=yes;"

# --- 2. ESTADO (LÓGICA) ---
class State(rx.State):
    
    # --- Sesión ---
    user_id: int = 0
    user_name: str = ""
    logged_in: bool = False
    
    # --- Login/Registro Inputs ---
    email_input: str = ""
    pass_input: str = ""
    new_name: str = ""
    new_email: str = ""
    new_pass: str = ""
    new_profile: str = "Desarrollador" 

    # --- Tablero (Proyectos) ---
    projects: list[dict] = []
    
    # --- Popup / Detalle de Proyecto ---
    show_modal: bool = False
    current_project_title: str = ""
    project_tasks: list[dict] = [] # Lista de tareas del proyecto seleccionado

    # Columnas del Kanban (Estados de Proyecto)
    columns: list[dict] = [
        {"id": 1, "name": "Pendiente", "color": "gray"},
        {"id": 2, "name": "En Progreso", "color": "blue"},
        {"id": 3, "name": "QA / Testing", "color": "orange"},
        {"id": 4, "name": "Finalizado", "color": "green"},
    ]

    # --- SETTERS ---
    def set_email_input(self, val): self.email_input = val
    def set_pass_input(self, val): self.pass_input = val
    def set_new_name(self, val): self.new_name = val
    def set_new_email(self, val): self.new_email = val
    def set_new_pass(self, val): self.new_pass = val
    def set_new_profile(self, val): self.new_profile = val
    
    # Función para cerrar el modal
    def close_modal(self): self.show_modal = False

    # --- LÓGICA DE NEGOCIO ---
    def login(self):
        try:
            with pyodbc.connect(CONN_STR) as conn:
                cursor = conn.cursor()
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
        except Exception as e:
            return rx.window_alert(f"Error de conexión: {e}")

    def register_user(self):
        try:
            with pyodbc.connect(CONN_STR) as conn:
                cursor = conn.cursor()
                sql = "{CALL sp_CreateUser (?, ?, ?, ?)}"
                params = (self.new_name, self.new_email, self.new_pass, self.new_profile)
                cursor.execute(sql, params)
                conn.commit()
                return rx.window_alert("Usuario creado.")
        except Exception as e:
            return rx.window_alert(f"Error al crear usuario: {e}")

    def load_projects(self):
        """Carga los proyectos para el Kanban (Vista vw_Kanban_Projects)"""
        try:
            with pyodbc.connect(CONN_STR) as conn:
                # Ahora consultamos la vista de PROYECTOS
                query = "SELECT * FROM vw_Kanban_Projects"
                df = pd.read_sql(query, conn)
                df = df.fillna("") 
                self.projects = df.to_dict('records')
        except Exception as e:
            print(f"Error cargando proyectos: {e}")

    def open_project_detail(self, project: dict):
        """Abre el popup y carga las tareas de ese proyecto"""
        self.current_project_title = project["Titulo"]
        project_id = project["ProjectID"]
        
        try:
            with pyodbc.connect(CONN_STR) as conn:
                # Consultamos la vista de DETALLE filtrando por ID
                query = "SELECT * FROM vw_Project_Tasks_Detail WHERE ProjectID = ?"
                df = pd.read_sql(query, conn, params=[project_id])
                df = df.fillna("")
                self.project_tasks = df.to_dict('records')
                self.show_modal = True
        except Exception as e:
            print(f"Error cargando tareas: {e}")

    def move_project(self, project_id: int, new_status_id: int):
        """Mueve un PROYECTO de columna (usa sp_Audit y Update manual)"""
        try:
            with pyodbc.connect(CONN_STR) as conn:
                cursor = conn.cursor()
                # Auditoría
                uid_to_send = self.user_id if self.user_id != 0 else 1
                cursor.execute("EXEC sp_set_session_context 'UserID', ?", (uid_to_send,))
                
                # Actualizar Proyecto
                #cursor.execute("UPDATE projects SET status_id = ? WHERE id = ?", (new_status_id, project_id))
                #cursor.execute("EXEC sp_MoveProject 'ProjectID', 'NewStatusID', ?, ?", (project_id, new_status_id))
                sql = "{CALL sp_MoveProject (?, ?)}"
                params = (project_id, new_status_id)
                cursor.execute(sql, params)
                conn.commit()
            
            self.load_projects()
        except Exception as e:
            return rx.window_alert(f"Error moviendo proyecto: {e}")

# --- 3. COMPONENTES UI ---

def badge_priority(priority: str):
    color_map = {"Alta": "red", "Media": "yellow", "Baja": "blue", "Crítica": "crimson"}
    return rx.badge(priority, color_scheme=color_map.get(priority, "gray"), variant="solid")

def task_list_item(task: dict):
    """Renderiza una tarea en la lista del popup con estilos condicionales"""
    return rx.box(
        rx.hstack(
            rx.vstack(
                rx.text(
                    task["Titulo"], 
                    font_size="14px", 
                    font_weight="500",
                    # Lógica de Color y Tachado
                    color=rx.cond(
                        task["Estado"] == "Finalizado", "green.400",
                        rx.cond(task["Estado"] == "Cancelado", "red.400", "white")
                    ),
                    text_decoration=rx.cond(
                        (task["Estado"] == "Finalizado") | (task["Estado"] == "Cancelado"), 
                        "line-through", 
                        "none"
                    )
                ),
                rx.text(f"Vence: {task['Vencimiento']}", font_size="11px", color="gray.500"),
                align_items="start",
                spacing="1"
            ),
            rx.spacer(),
            rx.badge(task["Estado"], variant="outline", size="1"),
            width="100%",
            align_items="center"
        ),
        padding="10px",
        border_bottom="1px solid #2D3748"
    )

def project_card(project: dict):
    """Tarjeta del Proyecto en el Kanban"""
    return rx.box(
        rx.vstack(
            rx.flex(
                rx.text(f"Lider: {project['Leader']}", font_size="10px", color="gray.400", weight="bold"),
                rx.spacer(),
                badge_priority(project["Prioridad"]),
                width="100%"
            ),
            # Al hacer clic en el título, abrimos el modal
            rx.link(
                rx.text(project["Titulo"], font_weight="bold", color="white", font_size="15px", _hover={"color": "#63B3ED", "cursor": "pointer"}),
                on_click=lambda: State.open_project_detail(project)
            ),
            rx.text(project["Descripcion"], font_size="12px", color="gray.400", no_of_lines=2),
            
            # Barra de progreso visual
            rx.hstack(
                rx.progress(value=project["TareasCompletadas"], max=project["TotalTareas"], width="100%", color_scheme="blue", height="6px"),
                rx.text(f"{project['TareasCompletadas']}/{project['TotalTareas']}", font_size="10px", color="gray.500"),
                width="100%",
                align_items="center"
            ),

            # Botones de mover proyecto
            rx.hstack(
                rx.cond(
                    project["StatusID"].to(int) > 1,
                    rx.button("←", on_click=lambda: State.move_project(project["ProjectID"], project["StatusID"].to(int) - 1), size="1", variant="surface"),
                ),
                rx.spacer(),
                rx.cond(
                    project["StatusID"].to(int) < 4,
                    rx.button("→", on_click=lambda: State.move_project(project["ProjectID"], project["StatusID"].to(int) + 1), size="1", variant="surface"),
                ),
                width="100%",
                padding_top="5px"
            ),
            align_items="start",
            spacing="3"
        ),
        padding="15px",
        border_radius="8px",
        bg="gray.800",
        border="1px solid #4A5568",
        width="100%",
        box_shadow="md",
        _hover={"border_color": "#63B3ED"} # Efecto hover
    )

def kanban_column(column: dict):
    return rx.vstack(
        rx.hstack(
            rx.badge(column["name"], color_scheme=column["color"], variant="surface", size="3"),
            width="100%",
            padding_bottom="10px"
        ),
        rx.foreach(
            State.projects,
            lambda proj: rx.cond(
                proj["StatusID"].to(int) == column["id"].to(int),
                project_card(proj),
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

# --- 4. PÁGINAS ---

def dashboard_page():
    return rx.box(
        rx.vstack(
            rx.hstack(
                rx.heading("Tablero de Proyectos", color="white", size="6"),
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
        
        # --- EL POPUP (DIALOG) ---
        rx.dialog.root(
            rx.dialog.content(
                rx.dialog.title(State.current_project_title, color="white"),
                rx.dialog.description("Lista de Tareas asociadas al proyecto.", color="gray.400"),
                
                # Lista de Tareas Scrollable
                rx.scroll_area(
                    rx.vstack(
                        rx.foreach(State.project_tasks, task_list_item),
                        spacing="2",
                        width="100%"
                    ),
                    type="always",
                    scrollbars="vertical",
                    style={"height": "300px", "padding": "10px"}
                ),

                rx.flex(
                    rx.dialog.close(
                        rx.button("Cerrar", on_click=State.close_modal, color_scheme="gray")
                    ),
                    justify="end",
                    padding_top="20px"
                ),
                bg="gray.900",
                max_width="500px",
            ),
            open=State.show_modal,
            on_open_change=State.close_modal, # Maneja el cierre al hacer clic afuera
        ),
        
        bg="#1A202C",
        min_height="100vh"
    )

def login_page():
    # (Misma lógica de Login anterior)
    return rx.center(
        rx.vstack(
            rx.heading("Vigilancia 24", size="8", color="blue.500"),
            rx.text("Gestión de Proyectos", color="gray.400"),
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
    # (Misma lógica de Registro anterior)
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

# --- 5. RUTAS ---
app = rx.App(theme=rx.theme(appearance="dark"))
app.add_page(login_page, route="/")
app.add_page(register_page, route="/register")
app.add_page(dashboard_page, route="/dashboard", on_load=State.load_projects)