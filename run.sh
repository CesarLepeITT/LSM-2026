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
echo "========================================"
echo "Verificando entorno Conda: $ENV_NAME"
echo "========================================"

# Obtener la ruta base de Conda para activarlo correctamente en scripts Bash
source $(conda info --base)/etc/profile.d/conda.sh

if conda info --envs | grep -q "^$ENV_NAME "; then
    echo "El entorno '$ENV_NAME' ya existe. Activando..."
    conda activate $ENV_NAME
else
    echo "Creando el entorno '$ENV_NAME' con Python $PYTHON_VERSION..."
    conda create -y -n $ENV_NAME python=$PYTHON_VERSION
    conda activate $ENV_NAME
    
    if [ ! -f "requirements.txt" ]; then
        echo "ERROR: No se encuentra el archivo requirements.txt"
        exit 1
    fi
    echo "Instalando dependencias desde requirements.txt..."
    pip install -r requirements.txt
fi

# ==============================================================================
# 2. GESTIÓN DE DATOS
# ==============================================================================
echo -e "\n========================================"
echo "Verificando Datos"
echo "========================================"
# Validamos si al menos una de las carpetas generadas por manage_datasets existe.
if [ ! -d "data/en" ] && [ ! -d "data/de" ]; then
    echo "AVISO: No se encontraron directorios de datos."
    echo "Lanzando herramienta de gestión de datasets (manage_datasets.sh)..."
    chmod +x data/manage_datasets.sh
    ./data/manage_datasets.sh
else
    echo "Carpetas de datos (data/en o data/de) detectadas. Continuando."
fi

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
