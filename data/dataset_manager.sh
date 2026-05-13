#!/usr/bin/env bash

# --- PHOENIX-14T ---
download_phoenix() {
    echo -e "\n${GREEN}Descargando PHOENIX...${NC}"
    wget -c -P "$BASE_DIR/de" "https://www-i6.informatik.rwth-aachen.de/ftp/pub/rwth-phoenix/2016/phoenix-2014-T.v3.tar.gz"
    read -p "Enter..."
}
prepare_phoenix() {
    echo -e "\n${YELLOW}Extrayendo PHOENIX-14T (Archivo de 39GB)...${NC}"
    
    # Rutas corregidas basadas en el interior del archivo tar
    local P1="PHOENIX-2014-T-release-v3/PHOENIX-2014-T/annotations"
    local P2="PHOENIX-2014-T-release-v3/PHOENIX-2014-T/evaluation"
    local P3="PHOENIX-2014-T-release-v3/PHOENIX-2014-T/features/fullFrame-210x260px"
    
    echo -e "${CYAN}Extrayendo archivos...${NC}"
    pv "$BASE_DIR/de/phoenix-2014-T.v3.tar.gz" | tar -xz -C "$BASE_DIR/de" "$P1" "$P2" "$P3"
        
    echo -e "\n\n${GREEN}Extracción completada. Organizando archivos...${NC}"
    mv "$BASE_DIR/de/$P1" "$BASE_DIR/de/"
    mv "$BASE_DIR/de/$P2" "$BASE_DIR/de/"
    mv "$BASE_DIR/de/$P3/dev" "$BASE_DIR/de/"
    mv "$BASE_DIR/de/$P3/test" "$BASE_DIR/de/"
    mv "$BASE_DIR/de/$P3/train" "$BASE_DIR/de/"
    
    rm -rf "$BASE_DIR/de/PHOENIX-2014-T-release-v3"
    echo -e "${GREEN}¡Preparación finalizada exitosamente!${NC}"
    
    echo -e "\n${YELLOW}El archivo comprimido pesa ~39GB.${NC}"
    read -p "¿Deseas eliminar el archivo .tar.gz para liberar espacio? (s/N): " del_tar
    if [[ "$del_tar" =~ ^[sS](i|í)?$ ]]; then
        echo -e "${RED}Eliminando archivo comprimido...${NC}"
        rm -f "$BASE_DIR/de/phoenix-2014-T.v3.tar.gz"
        echo -e "${GREEN}Archivo eliminado.${NC}"
    else
        echo -e "${CYAN}Conservando el archivo comprimido.${NC}"
    fi
    
    read -p "Presiona Enter para continuar..."
}
delete_data_phoenix() {
    echo -e "\n${RED}Borrando archivos en de/ ...${NC}"
    rm -rf "$BASE_DIR/de"/*; read -p "Enter..."
}
delete_full_phoenix() {
    echo -e "\n${RED}Eliminando carpeta de/ completamente...${NC}"
    rm -rf "$BASE_DIR/de"; read -p "Enter..."
}

# --- HOW2SIGN ---
download_how2sign() {
    echo -e "\n${YELLOW}Descarga manual en how2sign.github.io${NC}"; read -p "Enter..."
}
prepare_how2sign() {
    echo -e "\n${GREEN}Procesando How2Sign...${NC}"; read -p "Enter..."
}
delete_data_how2sign() {
    echo -e "\n${RED}Borrando archivos en en/ ...${NC}"
    rm -rf "$BASE_DIR/en"/*; read -p "Enter..."
}
delete_full_how2sign() {
    echo -e "\n${RED}Eliminando carpeta en/ completamente...${NC}"
    rm -rf "$BASE_DIR/en"; read -p "Enter..."
}


# --- Funciones para a ---
download_a() {
    echo -e "\n${YELLOW}[NO IMPLEMENTADO]${NC} Edita /home/gallobota/LSM-2026/data/dataset_manager.sh"; read -p "Enter..."
}
prepare_a() {
    echo -e "\n${YELLOW}[NO IMPLEMENTADO]${NC} Edita /home/gallobota/LSM-2026/data/dataset_manager.sh"; read -p "Enter..."
}
delete_data_a() {
    echo -e "\n${RED}Vaciando carpeta a/...${NC}"
    rm -rf "/home/gallobota/LSM-2026/data/a"/*
    read -p "Datos borrados. Enter..."
}
delete_full_a() {
    echo -e "\n${RED}Eliminando carpeta a/ completamente...${NC}"
    rm -rf "/home/gallobota/LSM-2026/data/a"
}
