#!/usr/bin/env bash

# Colores para la interfaz
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Directorios base
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DE_DIR="$BASE_DIR/de"
EN_DIR="$BASE_DIR/en"

# Crear directorios organizados por idioma
mkdir -p "$DE_DIR"
mkdir -p "$EN_DIR"

show_menu() {
    clear
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}   Gestión de Datasets (SLT)                    ${NC}"
    echo -e "${YELLOW}================================================${NC}"
    echo "Espacio en disco: $(df -h "$BASE_DIR" | awk 'NR==2 {print $4}') libres en la partición actual."
    echo "------------------------------------------------"
    echo "1. Descargar Dataset PHOENIX-14T (Alemán -> data/de/)"
    echo "2. Preparar Dataset How2Sign (Inglés -> data/en/)"
    echo "3. Eliminar Dataset PHOENIX-14T (Liberar espacio)"
    echo "4. Eliminar Dataset How2Sign (Liberar espacio)"
    echo "5. Salir"
    echo -e "${YELLOW}================================================${NC}"
}

download_phoenix() {
    echo -e "\n${GREEN}Descargando PHOENIX-14T (Alemán) en $DE_DIR...${NC}"
    wget -c -P "$DE_DIR" "http://cihancamgoz.com/files/cvpr2020/phoenix14t.pami0.train"
    wget -c -P "$DE_DIR" "http://cihancamgoz.com/files/cvpr2020/phoenix14t.pami0.dev"
    wget -c -P "$DE_DIR" "http://cihancamgoz.com/files/cvpr2020/phoenix14t.pami0.test"
    echo -e "${GREEN}Descarga completa.${NC}"
    read -p "Presiona Enter para continuar..."
}

download_how2sign() {
    echo -e "\n${GREEN}Preparando entorno para How2Sign (Inglés) en $EN_DIR...${NC}"
    echo -e "El dataset How2Sign es multimodal y requiere procesamiento manual inicial."
    echo -e "Pasos requeridos:"
    echo -e "1. Descarga el dataset crudo desde how2sign.github.io"
    echo -e "2. Extrae las anotaciones y los keypoints 3D a un almacenamiento externo temporal."
    echo -e "3. Ejecuta el script 'preprocess_how2sign.py' para generar el archivo ligero (.gzip)."
    echo -e "4. El script automáticamente debe exportar el resultado final a: $EN_DIR"
    echo -e "\n${YELLOW}Los directorios de destino ya están preparados.${NC}"
    read -p "Presiona Enter para continuar..."
}

delete_phoenix() {
    echo -e "\n${RED}Eliminando archivos de PHOENIX-14T (data/de/*)...${NC}"
    rm -rf "$DE_DIR"/*
    echo -e "Archivos eliminados. Espacio liberado exitosamente."
    read -p "Presiona Enter para continuar..."
}

delete_how2sign() {
    echo -e "\n${RED}Eliminando archivos de How2Sign (data/en/*)...${NC}"
    rm -rf "$EN_DIR"/*
    echo -e "Archivos eliminados. Espacio liberado exitosamente."
    read -p "Presiona Enter para continuar..."
}

while true; do
    show_menu
    read -p "Selecciona una opción [1-5]: " choice
    case $choice in
        1) download_phoenix ;;
        2) download_how2sign ;;
        3) delete_phoenix ;;
        4) delete_how2sign ;;
        5) echo "Saliendo..."; exit 0 ;;
        *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
    esac
done
