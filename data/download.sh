#!/usr/bin/env bash

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE="$BASE_DIR/datasets.conf"
MANAGER_FILE="$BASE_DIR/dataset_manager.sh"

# Inicialización
if [ ! -f "$CONFIG_FILE" ]; then
    echo "phoenix|PHOENIX-14T|de|Alemán" > "$CONFIG_FILE"
    echo "how2sign|How2Sign|en|Inglés" >> "$CONFIG_FILE"
fi

[ -f "$MANAGER_FILE" ] && source "$MANAGER_FILE"

delete_menu() {
    local id="$1" name="$2" code="$3"
    while true; do
        clear
        echo -e "${RED}================================================${NC}"
        echo -e "${RED} OPCIONES DE ELIMINACIÓN: $name ${NC}"
        echo -e "${RED}================================================${NC}"
        echo "1. Eliminar datos (Vaciar carpeta $code/)"
        echo "2. Eliminar completamente (Quitar del sistema y borrar carpeta)"
        echo "3. Cancelar"
        echo -e "${RED}================================================${NC}"
        read -p "Selecciona una opción [1-3]: " del_opt

        case $del_opt in
            1) "delete_data_$id" ; return ;;
            2) 
                read -p "¿Estás seguro de eliminar TODO rastro de $name? [s/N]: " confirm
                if [[ "$confirm" =~ ^[sS]$ ]]; then
                    # Borrar datos físicos
                    "delete_full_$id"
                    # Borrar del archivo de configuración
                    sed -i "/^$id|/d" "$CONFIG_FILE"
                    echo -e "${GREEN}Dataset eliminado del registro.${NC}"
                    sleep 2
                    return 2 # Código especial para salir al menú principal
                fi
                ;;
            3) return ;;
            *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
        esac
    done
}

dataset_submenu() {
    local id="$1" name="$2" code="$3" lang="$4"
    while true; do
        clear
        echo -e "${CYAN}================================================${NC}"
        echo -e "${CYAN} Dataset: $name ($lang) ${NC}"
        echo -e "${CYAN}================================================${NC}"
        echo "Ruta: $BASE_DIR/$code/"
        echo "------------------------------------------------"
        echo "1. Descargar dataset"
        echo "2. Preparar dataset"
        echo "3. Eliminar..."
        echo "4. Volver al menú principal"
        echo -e "${CYAN}================================================${NC}"
        read -p "Opción [1-4]: " opt

        case $opt in
            1) "download_$id" ;;
            2) "prepare_$id" ;;
            3) 
                delete_menu "$id" "$name" "$code"
                [ $? -eq 2 ] && return # Si se eliminó completo, volver al inicio
                ;;
            4) return ;;
            *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
        esac
    done
}

add_new_dataset() {
    clear
    echo -e "${YELLOW}================================================${NC}"
    read -p "Nombre del Dataset: " new_name
    read -p "Idioma: " new_lang
    read -p "Código carpeta (ej. es): " new_code
    read -p "ID interno (ej. lsq): " new_id

    [[ ! "$new_id" =~ ^[a-zA-Z0-9_]+$ ]] && { echo "ID inválido."; sleep 2; return; }
    echo "$new_id|$new_name|$new_code|$new_lang" >> "$CONFIG_FILE"
    mkdir -p "$BASE_DIR/$new_code"

    cat <<EOF >> "$MANAGER_FILE"

# --- Funciones para $new_name ---
download_${new_id}() {
    echo -e "\\n\${YELLOW}[NO IMPLEMENTADO]\${NC} Edita $MANAGER_FILE"; read -p "Enter..."
}
prepare_${new_id}() {
    echo -e "\\n\${YELLOW}[NO IMPLEMENTADO]\${NC} Edita $MANAGER_FILE"; read -p "Enter..."
}
delete_data_${new_id}() {
    echo -e "\\n\${RED}Vaciando carpeta $new_code/...\${NC}"
    rm -rf "$BASE_DIR/$new_code"/*
    read -p "Datos borrados. Enter..."
}
delete_full_${new_id}() {
    echo -e "\\n\${RED}Eliminando carpeta $new_code/ y funciones...\${NC}"
    rm -rf "$BASE_DIR/$new_code"
    # Nota: Las funciones se quedan en el .sh pero el ID ya no existirá en .conf
}
EOF
    source "$MANAGER_FILE"
    echo -e "${GREEN}Dataset añadido.${NC}"; sleep 2
}

while true; do
    clear
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}   GESTOR DE DATASETS SLT                       ${NC}"
    echo -e "${YELLOW}================================================${NC}"
    echo "Espacio libre: $(df -h "$BASE_DIR" | awk 'NR==2 {print $4}')"
    echo "------------------------------------------------"
    datasets=(); i=1
    while IFS='|' read -r id name code lang || [ -n "$id" ]; do
        [ -z "$id" ] && continue
        datasets+=("$id|$name|$code|$lang")
        echo "$i. $name ($lang)"
        ((i++))
    done < "$CONFIG_FILE"
    echo "------------------------------------------------"
    echo "$i. Añadir nuevo dataset"
    echo "$((i+1)). Salir"
    read -p "Selección: " choice
    if [[ $choice -ge 1 && $choice -le ${#datasets[@]} ]]; then
        IFS='|' read -r id name code lang <<< "${datasets[$((choice-1))]}"
        dataset_submenu "$id" "$name" "$code" "$lang"
    elif [[ $choice -eq $i ]]; then add_new_dataset
    elif [[ $choice -eq $((i+1)) ]]; then exit 0
    fi
done