#!/bin/bash

# Archivo de entrada y el nombre de salida base
input="audio.mp3"
output_base="audio_segment"

# Umbral y duración de silencio en dB y segundos
silence_threshold="-55.59999dB"
silence_duration="0.5"

# Detectar los silencios y guardar la salida en un archivo de texto
ffmpeg -i "$input" -af silencedetect=n=$silence_threshold:d=$silence_duration -f null - 2> silencios.txt

# Inicializar variables para almacenar las posiciones de los silencios
last_end=0
segment_count=1

# Leer el archivo de silencios línea por línea
while read -r line; do
    if [[ $line == *"silence_start"* ]]; then
        # Obtener el tiempo de inicio del silencio
        silence_start=$(echo $line | sed 's/.*silence_start: \([0-9]*\.[0-9]*\).*/\1/')
    elif [[ $line == *"silence_end"* ]]; then
        # Obtener el tiempo de fin del silencio y su duración
        silence_end=$(echo $line | sed 's/.*silence_end: \([0-9]*\.[0-9]*\).*/\1/')
        silence_duration=$(echo $line | sed 's/.*silence_duration: \([0-9]*\.[0-9]*\).*/\1/')

        # Extraer el segmento de audio entre el final del último silencio y el inicio del siguiente
        if (( $(echo "$silence_start > $last_end" | bc -l) )); then
            output_file="${output_base}_${segment_count}.mp3"
            ffmpeg -i "$input" -ss "$last_end" -to "$silence_start" -c copy "$output_file"
            echo "Segmento $segment_count guardado: $output_file"
            ((segment_count++))
        fi

        # Actualizar el último final de silencio
        last_end=$silence_end
    fi
done < silencios.txt

# Extraer el último segmento de audio si hay una parte final con sonido
if (( $(echo "$last_end < $(ffmpeg -i "$input" 2>&1 | grep "Duration" | sed 's/.*Duration: \([0-9]*\:[0-9]*\:[0-9]*\.[0-9]*\).*/\1/')" | bc -l) )); then
    output_file="${output_base}_${segment_count}.mp3"
    ffmpeg -i "$input" -ss "$last_end" -c copy "$output_file"
    echo "Último segmento guardado: $output_file"
fi

