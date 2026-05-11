#!/usr/bin/env bash

# --- PHOENIX-14T ---
download_phoenix() {
    echo -e "\n${GREEN}Descargando PHOENIX...${NC}"
    wget -c -P "$BASE_DIR/de" "https://www-i6.informatik.rwth-aachen.de/ftp/pub/rwth-phoenix/2016/phoenix-2014-T.v3.tar.gz"
    read -p "Enter..."
}
prepare_phoenix() {
    echo -e "\n${YELLOW}Listo (No requiere preparación).${NC}"; read -p "Enter..."
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
