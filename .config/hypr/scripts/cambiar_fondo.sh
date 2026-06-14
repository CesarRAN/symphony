#!/bin/bash

# Directorio donde están tus GIFs
DIR="/home/cesar/doc_2/Wallpaper/w"

# Selecciona un archivo aleatorio del directorio que termine en .gif o .GIF
WALLPAPER=$(find "$DIR" -maxdepth 1 -type f \( -iname "*.gif" -o -iname "*.png" -o -iname "*.jpg" \) | shuf -n 1)
    
# Aplica el fondo con una transición bonita
awww img "$WALLPAPER" --transition-type any --transition-step 30 --transition-fps 60
    



