#!/usr/bin/env bash
# run.sh - Orquestador Principal para Sign Language Transformers (SLT)

# ==============================================================================
# CONFIGURACIÓN GENERAL
# ==============================================================================
ENV_NAME="slt_env"
PYTHON_VERSION="3.8"
CONFIG_FILE="configs/how2sign.yaml"

# ==============================================================================
# 1. GESTIÓN DEL ENTORNO CONDA
# ==============================================================================
echo -e "\n========================================"
echo -e "Verificando entorno Conda: ${CYAN}$ENV_NAME${NC}"
echo -e "========================================"

# 1. Configuración de seguridad y Shell de Conda
set -e # Detener el script si ocurre un error
CONDA_SHELL_PATH=$(conda info --base)/etc/profile.d/conda.sh

if [ -f "$CONDA_SHELL_PATH" ]; then
    source "$CONDA_SHELL_PATH"
else
    echo -e "${RED}ERROR: No se pudo localizar conda.sh para la activación.${NC}"
    exit 1
fi

# 2. Crear entorno si no existe
if ! conda info --envs | grep -q "^$ENV_NAME "; then
    echo -e "${YELLOW}Creando entorno '$ENV_NAME' (Python $PYTHON_VERSION)...${NC}"
    # Intentar usar mamba si está disponible para mayor velocidad
    if command -v mamba &> /dev/null; then
        mamba create -y -n "$ENV_NAME" python="$PYTHON_VERSION"
    else
        conda create -y -n "$ENV_NAME" python="$PYTHON_VERSION"
    fi
fi

# 3. Activar entorno
echo -e "Activando entorno: ${GREEN}$ENV_NAME${NC}"
conda activate "$ENV_NAME"

# 4. Sincronización inteligente de dependencias
if [ -f "requirements.txt" ]; then
    echo "Sincronizando dependencias..."
    # Usamos pip check o simplemente instalamos (pip es inteligente y no reinstala lo que ya está)
    if ! pip install -r requirements.txt; then
        echo -e "${RED}ERROR: Falló la instalación de dependencias.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}AVISO: requirements.txt no encontrado. Saltando instalación.${NC}"
fi

# Desactivar 'set -e' para el resto del script si prefieres manejo manual de errores
set +e

# ==============================================================================
# 2. GESTIÓN DE DATOS
# ==============================================================================

CONFIG_FILE="data/datasets.conf"
DOWNLOAD_SCRIPT="data/download.sh"

check_data_integrity() {
    local datasets_found=0
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='|' read -r id name code lang || [ -n "$id" ]; do
            [ -z "$id" ] && continue
            DATA_PATH="data/$code"
            # Cuenta archivos en subcarpetas estándar
            count=$(find "$DATA_PATH" -type f \( -path "*/train/*" -o -path "*/test/*" -o -path "*/val/*" -o -path "*/dev/*" \) 2>/dev/null | wc -l)
            if [ "$count" -gt 0 ]; then
                ((datasets_found++))
                echo -e "  [${GREEN}OK${NC}] $name ($lang): $count archivos detectados."
            else
                echo -e "  [${RED}!!${NC}] $name ($lang): Sin datos en train/test/val."
            fi
        done < "$CONFIG_FILE"
    fi
    return "$datasets_found"
}

while true; do
    echo -e "\n========================================"
    echo -e "       CONTROL DE DATASETS SLT"
    echo -e "========================================"
    echo "1) Abrir Gestor de Datasets (Descargar/Preparar)"
    echo "2) Comprobar integridad de datos actuales"
    echo "3) Continuar con el entrenamiento"
    echo -e "========================================\n"
    read -p "Selecciona una opción [1-3]: " opt_data

    case $opt_data in
        1)
            if [ -f "$DOWNLOAD_SCRIPT" ]; then
                chmod +x "$DOWNLOAD_SCRIPT"
                "$DOWNLOAD_SCRIPT"
            else
                echo -e "${RED}Error: No se encuentra $DOWNLOAD_SCRIPT${NC}"
            fi
            ;;
        2)
            echo -e "\nVerificando carpetas según $CONFIG_FILE..."
            check_data_integrity
            read -p "Presiona Enter para volver..."
            ;;
        3)
            echo -e "\nValidando requisitos para continuar..."
            check_data_integrity
            valid_count=$?
            
            if [ "$valid_count" -gt 0 ]; then
                echo -e "\n${GREEN}Validación exitosa. Continuando con el entrenamiento...${NC}"
                break # Sale del bucle y sigue con el resto del script principal
            else
                echo -e "\n${RED}ERROR CRÍTICO: No hay datos preparados.${NC}"
                echo -e "El entrenamiento no puede iniciar sin archivos en train/test/val."
                echo -e "Sugerencia: Ejecuta la opción (1) para descargar o preparar datasets."
                exit 1 # Detiene el script por completo
            fi
            ;;
        *)
            echo -e "${RED}Opción no válida.${NC}"
            sleep 1
            ;;
    esac
done

# ==============================================================================
# 3. LECTURA DE CONFIGURACIÓN
# ==============================================================================
echo -e "\n========================================"
echo "Configuración de Entrenamiento"
echo "========================================"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: No se encuentra el archivo de configuración: $CONFIG_FILE"
    exit 1
fi

# Extraer parámetros clave para validación en consola
BATCH_SIZE=$(grep "batch_size:" $CONFIG_FILE | head -n 1 | awk '{print $2}')
BATCH_MULTIPLIER=$(grep "batch_multiplier:" $CONFIG_FILE | head -n 1 | awk '{print $2}')
HIDDEN_SIZE=$(grep "hidden_size:" $CONFIG_FILE | head -n 1 | awk '{print $2}')
LEARNING_RATE=$(grep "learning_rate:" $CONFIG_FILE | head -n 1 | awk '{print $2}')

echo "Archivo objetivo: $CONFIG_FILE"
echo "  - Batch Size: $BATCH_SIZE"
echo "  - Batch Multiplier: $BATCH_MULTIPLIER"
echo "  - Hidden Size: $HIDDEN_SIZE"
echo "  - Learning Rate: $LEARNING_RATE"
echo "========================================"
echo "El entrenamiento iniciará en 3 segundos..."
sleep 3

# ==============================================================================
# 4. EJECUCIÓN DEL ENTRENAMIENTO
# ==============================================================================
echo -e "\n========================================"
echo "Iniciando Entrenamiento"
echo "========================================"
# El comando de entrenamiento del repositorio
python -m signjoey train $CONFIG_FILE

# Control de errores para evitar que siga el orquestador si falló el entrenamiento
if [ $? -ne 0 ]; then
    echo "ERROR: El proceso de entrenamiento ha fallado. Abortando orquestador."
    exit 1
fi
echo "Entrenamiento completado exitosamente."

# ==============================================================================
# 5. EVALUACIÓN Y MÉTRICAS OFICIALES
# ==============================================================================
echo -e "\n========================================"
echo "Iniciando Evaluación (Testing)"
echo "========================================"
if [ ! -f "test_model.py" ]; then
    echo "ERROR: No se encuentra el script de evaluación test_model.py"
    exit 1
fi

# Ejecutamos el módulo propio de evaluación
python test/test_model.py $CONFIG_FILE

echo "Orquestación finalizada."
