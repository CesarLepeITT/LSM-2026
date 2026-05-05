#!/usr/bin/env bash

# --- PHOENIX-14T ---
download_phoenix() {
    echo -e "\n${GREEN}Descargando PHOENIX...${NC}"
    wget -c -P "$BASE_DIR/de" "http://cihancamgoz.com/files/cvpr2020/phoenix14t.pami0.train"
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
# --- Funciones para cesar ---
download_cesar() {
    echo -e "\n${YELLOW}[NO IMPLEMENTADO]${NC} Edita /home/gallobota/LSM-2026/data/dataset_manager.sh"; read -p "Enter..."
}
prepare_cesar() {
    echo -e "\n${YELLOW}[NO IMPLEMENTADO]${NC} Edita /home/gallobota/LSM-2026/data/dataset_manager.sh"; read -p "Enter..."
}
delete_data_cesar() {
    echo -e "\n${RED}Vaciando carpeta cs/...${NC}"
    rm -rf "/home/gallobota/LSM-2026/data/cs"/*
    read -p "Datos borrados. Enter..."
}
delete_full_cesar() {
    echo -e "\n${RED}Eliminando carpeta cs/ y funciones...${NC}"
    rm -rf "/home/gallobota/LSM-2026/data/cs"
    # Nota: Las funciones se quedan en el .sh pero el ID ya no existirá en .conf
}
