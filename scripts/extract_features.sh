#!/usr/bin/env bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}   GESTOR DE DATASETS SLT                       ${NC}"
echo -e "${YELLOW}================================================${NC}"
echo ""

# Resolver dinámicamente el directorio base del proyecto
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATASETS_CONF="$BASE_DIR/data/datasets.conf"
if [ ! -f "$DATASETS_CONF" ]; then
    echo -e "${RED}ERROR: No se encuentra $DATASETS_CONF${NC}"
    exit 1
fi

echo -e "${CYAN}Selecciona el dataset para extraer características:${NC}"
declare -a DS_CODES
declare -a DS_NAMES
idx=1
while IFS='|' read -r id name code lang || [ -n "$id" ]; do
    [ -z "$id" ] && continue
    DS_CODES[$idx]="$code"
    DS_NAMES[$idx]="$name ($lang)"
    echo "  $idx) ${DS_NAMES[$idx]}"
    ((idx++))
done < "$DATASETS_CONF"

read -p "> " ds_choice
if [ -z "${DS_CODES[$ds_choice]}" ]; then
    echo -e "${RED}Selección inválida.${NC}"
    exit 1
fi
ds_code=${DS_CODES[$ds_choice]}
data_dir="$BASE_DIR/data/$ds_code"

if [ ! -d "$data_dir" ]; then
    echo -e "${RED}ERROR: No existe el directorio $data_dir${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}Selecciona los splits a extraer (puedes combinar números separados por espacio, ej: '1 2 3'):${NC}"
echo "  1) train"
echo "  2) dev"
echo "  3) test"
read -p "> " split_choices

splits=""
for choice in $split_choices; do
    case $choice in
        1) splits="$splits train" ;;
        2) splits="$splits dev" ;;
        3) splits="$splits test" ;;
        *) echo -e "${YELLOW}Opción de split inválida: $choice (ignorada)${NC}" ;;
    esac
done
# Eliminar espacios extra
splits=$(echo $splits | xargs)
if [ -z "$splits" ]; then
    echo -e "${RED}No se seleccionó ningún split válido.${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}Selecciona el modelo CNN extractor:${NC}"
echo "  1) efficientnet_b0"
echo "  2) resnet50"
echo "  3) inception_v3"
echo "  4) efficientnet_b7"
read -p "> " model_choice

case $model_choice in
    1) model_name="efficientnet_b0" ;;
    2) model_name="resnet50" ;;
    3) model_name="inception_v3" ;;
    4) model_name="efficientnet_b7" ;;
    *) echo -e "${RED}Modelo inválido.${NC}"; exit 1 ;;
esac

echo ""
echo -e "${CYAN}Tabla de recomendaciones de Batch Size para: ${BOLD}$model_name${NC}"
echo -e "-----------------------------------------------------------------------"
echo -e "Modelo            Tamaño Entrada   VRAM 8GB     VRAM 16GB    VRAM 24GB"
echo -e "-----------------------------------------------------------------------"
case $model_name in
    efficientnet_b0)
        echo -e "EfficientNet-B0   224 x 224        64 - 128     128 - 256    256 - 512"
        ;;
    resnet50)
        echo -e "ResNet50          224 x 224        32 - 64      64 - 128     128 - 256"
        ;;
    inception_v3)
        echo -e "Inception v3      299 x 299        16 - 32      32 - 64      64 - 128"
        ;;
    efficientnet_b7)
        echo -e "EfficientNet-B7   600 x 600        1 - 2*       4 - 8        8 - 16"
        ;;
esac
echo -e "-----------------------------------------------------------------------"

echo ""
read -p "¿Batch size para la extracción? [128]: " ext_batch
ext_batch=${ext_batch:-128}

read -p "¿Número de workers? (0 recomendado para WSL/Windows, 4 para Linux nativo) [0]: " num_workers
num_workers=${num_workers:-0}

echo ""
echo -e "${YELLOW}Iniciando extracción para $data_dir con el modelo $model_name...${NC}"

python "$BASE_DIR/scripts/extract_features.py" \
    --data_dir "$data_dir" \
    --split $splits \
    --model "$model_name" \
    --batch_size "$ext_batch" \
    --num_workers "$num_workers"

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}Extracción finalizada exitosamente.${NC}"
else
    echo -e "\n${RED}Hubo un error durante la extracción.${NC}"
fi

read -p "Presiona Enter para volver..."
