#!/usr/bin/env bash
# run.sh - Orquestador Principal para Sign Language Transformers (SLT)
# Modernizado: Soporte multilenguaje, PyTorch 2.x, Python 3.10

# ==============================================================================
# CONFIGURACIÓN GENERAL
# ==============================================================================
ENV_NAME="slt_env"
PYTHON_VERSION="3.10"

# Colores para la terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ==============================================================================
# 1. GESTIÓN DEL ENTORNO CONDA
# ==============================================================================
echo -e "\n${BOLD}========================================${NC}"
echo -e "Verificando entorno Conda: ${CYAN}$ENV_NAME${NC}"
echo -e "${BOLD}========================================${NC}"

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

DATASETS_CONF="data/datasets.conf"
DOWNLOAD_SCRIPT="data/download.sh"

check_data_integrity() {
    local datasets_found=0
    if [ -f "$DATASETS_CONF" ]; then
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
        done < "$DATASETS_CONF"
    fi
    return "$datasets_found"
}

while true; do
    echo -e "\n${BOLD}========================================${NC}"
    echo -e "       ${MAGENTA}CONTROL DE DATASETS SLT${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo "1) Abrir Gestor de Datasets (Descargar/Preparar)"
    echo "2) Comprobar integridad de datos actuales"
    echo "3) Continuar con el entrenamiento"
    echo -e "${BOLD}========================================${NC}\n"
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
            echo -e "\nVerificando carpetas según $DATASETS_CONF..."
            check_data_integrity
            read -p "Presiona Enter para volver..."
            ;;
        3)
            echo -e "\nValidando requisitos para continuar..."
            check_data_integrity
            valid_count=$?
            
            if [ "$valid_count" -gt 0 ]; then
                echo -e "\n${GREEN}Validación exitosa. Continuando...${NC}"
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
# 3. SELECCIÓN DE DATASET/IDIOMA PARA ENTRENAMIENTO
# ==============================================================================
echo -e "\n${BOLD}========================================${NC}"
echo -e "    ${CYAN}SELECCIÓN DE DATASET / IDIOMA${NC}"
echo -e "${BOLD}========================================${NC}"

# Leer datasets disponibles del archivo de configuración
declare -a DS_IDS
declare -a DS_NAMES
declare -a DS_CODES
declare -a DS_LANGS
ds_idx=0

while IFS='|' read -r id name code lang || [ -n "$id" ]; do
    [ -z "$id" ] && continue
    DS_IDS[$ds_idx]="$id"
    DS_NAMES[$ds_idx]="$name"
    DS_CODES[$ds_idx]="$code"
    DS_LANGS[$ds_idx]="$lang"
    ((ds_idx++))
done < "$DATASETS_CONF"

# Mostrar opciones
for i in "${!DS_IDS[@]}"; do
    config_path="configs/${DS_IDS[$i]}.yaml"
    if [ -f "configs/sign.yaml" ] && [ "${DS_IDS[$i]}" == "phoenix" ]; then
        config_path="configs/sign.yaml"
    fi
    if [ -f "configs/how2sign.yaml" ] && [ "${DS_IDS[$i]}" == "how2sign" ]; then
        config_path="configs/how2sign.yaml"
    fi
    
    status="${RED}Sin config${NC}"
    [ -f "$config_path" ] && status="${GREEN}Config OK${NC}"
    echo -e "  $((i+1))) ${BOLD}${DS_NAMES[$i]}${NC} [${DS_LANGS[$i]}] - [$status]"
done

echo ""
read -p "Selecciona el dataset para entrenar [1-${#DS_IDS[@]}]: " ds_choice
ds_choice=$((ds_choice - 1))

if [ "$ds_choice" -lt 0 ] || [ "$ds_choice" -ge "${#DS_IDS[@]}" ]; then
    echo -e "${RED}Selección inválida.${NC}"
    exit 1
fi

SELECTED_ID="${DS_IDS[$ds_choice]}"
SELECTED_NAME="${DS_NAMES[$ds_choice]}"
SELECTED_CODE="${DS_CODES[$ds_choice]}"
SELECTED_LANG="${DS_LANGS[$ds_choice]}"

# Buscar config asociada
if [ "$SELECTED_ID" == "phoenix" ]; then
    TRAIN_CONFIG="configs/sign.yaml"
elif [ "$SELECTED_ID" == "how2sign" ]; then
    TRAIN_CONFIG="configs/how2sign.yaml"
else
    TRAIN_CONFIG="configs/${SELECTED_ID}.yaml"
fi

if [ ! -f "$TRAIN_CONFIG" ]; then
    echo -e "${RED}ERROR: No se encuentra el archivo de configuración: $TRAIN_CONFIG${NC}"
    echo -e "Crea un archivo YAML en configs/ para el dataset '${SELECTED_ID}'."
    exit 1
fi

echo -e "\n${GREEN}Dataset seleccionado: ${BOLD}${SELECTED_NAME}${NC} ${GREEN}(${SELECTED_LANG})${NC}"
echo -e "Config: ${CYAN}${TRAIN_CONFIG}${NC}"

# ==============================================================================
# 4. LECTURA DE CONFIGURACIÓN Y VALIDACIÓN
# ==============================================================================
echo -e "\n${BOLD}========================================${NC}"
echo -e "       Configuración de Entrenamiento"
echo -e "${BOLD}========================================${NC}"

# Extraer parámetros clave para validación en consola
BATCH_SIZE=$(grep "batch_size:" "$TRAIN_CONFIG" | head -n 1 | awk '{print $2}')
BATCH_MULTIPLIER=$(grep "batch_multiplier:" "$TRAIN_CONFIG" | head -n 1 | awk '{print $2}')
HIDDEN_SIZE=$(grep "hidden_size:" "$TRAIN_CONFIG" | head -n 1 | awk '{print $2}')
LEARNING_RATE=$(grep "learning_rate:" "$TRAIN_CONFIG" | head -n 1 | awk '{print $2}')
MODEL_DIR=$(grep "model_dir:" "$TRAIN_CONFIG" | head -n 1 | awk '{print $2}' | tr -d '"')

echo "Archivo de Config: $TRAIN_CONFIG"
echo "  - Dataset: $SELECTED_NAME ($SELECTED_LANG)"
echo "  - Batch Size: ${BATCH_SIZE:-N/A}"
echo "  - Batch Multiplier: ${BATCH_MULTIPLIER:-1}"
echo "  - Hidden Size: ${HIDDEN_SIZE:-N/A}"
echo "  - Learning Rate: ${LEARNING_RATE:-N/A}"
echo "  - Model Dir: ${MODEL_DIR:-N/A}"
echo -e "${BOLD}========================================${NC}"

# Mostrar info de GPU si CUDA está disponible
python -c "
import torch
if torch.cuda.is_available():
    gpu = torch.cuda.get_device_name(0)
    vram = torch.cuda.get_device_properties(0).total_mem / (1024**3)
    bf16 = torch.cuda.is_bf16_supported()
    print(f'  GPU: {gpu}')
    print(f'  VRAM: {vram:.1f} GB')
    print(f'  BF16: {\"✓\" if bf16 else \"✗\"}')
    print(f'  FlashAttention: {\"✓\" if hasattr(torch.nn.functional, \"scaled_dot_product_attention\") else \"✗\"}')
else:
    print('  GPU: No CUDA disponible (modo CPU)')
" 2>/dev/null

echo -e "\nEl entrenamiento iniciará en 3 segundos..."
sleep 3

# ==============================================================================
# 5. EJECUCIÓN DEL ENTRENAMIENTO
# ==============================================================================
echo -e "\n${BOLD}========================================${NC}"
echo -e "    ${GREEN}Iniciando Entrenamiento${NC}"
echo -e "    ${CYAN}${SELECTED_NAME} (${SELECTED_LANG})${NC}"
echo -e "${BOLD}========================================${NC}"

# Ejecutar entrenamiento con el config seleccionado
python -m signjoey train "$TRAIN_CONFIG"

# Control de errores para evitar que siga el orquestador si falló el entrenamiento
if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: El proceso de entrenamiento ha fallado. Abortando orquestador.${NC}"
    exit 1
fi
echo -e "${GREEN}Entrenamiento completado exitosamente.${NC}"

# ==============================================================================
# 6. EVALUACIÓN Y MÉTRICAS OFICIALES
# ==============================================================================
echo -e "\n${BOLD}========================================${NC}"
echo -e "    ${CYAN}Iniciando Evaluación (Testing)${NC}"
echo -e "    ${MAGENTA}${SELECTED_NAME} (${SELECTED_LANG})${NC}"
echo -e "${BOLD}========================================${NC}"

if [ ! -f "test/test_model.py" ]; then
    echo -e "${YELLOW}AVISO: No se encuentra test/test_model.py. Saltando evaluación.${NC}"
else
    # Ejecutamos el módulo propio de evaluación
    python test/test_model.py "$TRAIN_CONFIG"
fi

echo -e "\n${GREEN}${BOLD}Orquestación finalizada.${NC}"
echo -e "Modelo guardado en: ${CYAN}${MODEL_DIR:-models/}${NC}"
