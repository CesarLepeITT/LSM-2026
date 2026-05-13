#!/usr/bin/env bash

# Colores
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN} Instalador de Dependencias para Ubuntu - LSM-2026 ${NC}"
echo -e "${CYAN}=================================================${NC}\n"

# 1. Actualizar repositorios e instalar paquetes base
echo -e "${YELLOW}1. Instalando paquetes del sistema (pv, wget, tar, etc)...${NC}"
sudo apt-get update
sudo apt-get install -y pv wget curl tar bzip2 ca-certificates git

# 2. Instalación de Miniconda (si no existe)
echo -e "\n${YELLOW}2. Verificando instalación de Conda...${NC}"
if command -v conda &> /dev/null || [ -d "$HOME/miniconda3" ] || [ -d "$HOME/anaconda3" ]; then
    echo -e "${GREEN}Conda ya parece estar instalado en el sistema.${NC}"
else
    echo -e "${CYAN}Conda no encontrado. Descargando e instalando Miniconda3...${NC}"
    mkdir -p ~/miniconda3
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
    bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm ~/miniconda3/miniconda.sh
    
    # Inicializar para bash (y zsh si lo hay)
    ~/miniconda3/bin/conda init bash
    ~/miniconda3/bin/conda init zsh > /dev/null 2>&1 || true
    echo -e "${GREEN}Miniconda instalado correctamente.${NC}"
fi

# 3. Instalación de Mamba (opcional pero recomendado para mayor velocidad)
echo -e "\n${YELLOW}3. Instalando Mamba (Gestor de entornos ultra-rápido)...${NC}"
if command -v mamba &> /dev/null; then
    echo -e "${GREEN}Mamba ya está instalado.${NC}"
else
    # Si conda acaba de ser instalado en esta sesión, el comando 'conda' podría no estar en el PATH aún
    CONDA_EXE="conda"
    [ -f ~/miniconda3/bin/conda ] && CONDA_EXE="~/miniconda3/bin/conda"
    [ -f ~/anaconda3/bin/conda ] && CONDA_EXE="~/anaconda3/bin/conda"
    
    eval "$CONDA_EXE install -y -n base -c conda-forge mamba" || echo -e "${RED}Hubo un error al instalar mamba, pero puedes continuar solo con conda.${NC}"
fi

echo -e "\n${CYAN}=================================================${NC}"
echo -e "${GREEN}¡Instalación de dependencias completada!${NC}"
echo -e "${CYAN}=================================================${NC}"
echo -e "${YELLOW}IMPORTANTE: Para que Conda funcione en esta terminal, debes recargarla.${NC}"
echo -e "Ejecuta el siguiente comando o abre una nueva terminal:"
echo -e "    ${GREEN}source ~/.bashrc${NC}"
echo -e "\nDespués de eso, podrás ejecutar sin problemas:"
echo -e "    ${GREEN}./run.sh${NC}"
