# ============================================================
# globals.4gl - Variables globales compartidas
# ============================================================

GLOBALS
    DEFINE gv_usuario VARCHAR(30) = USER
    DEFINE gv_modo VARCHAR(10) = "BUILD"
    DEFINE g_usuario_actual VARCHAR(30) = USER
    DEFINE g_log_dir VARCHAR(200) = "logs"
    DEFINE g_log_level VARCHAR(10) = "INFO"
    DEFINE g_log_enabled BOOLEAN = TRUE
END GLOBALS