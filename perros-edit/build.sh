#!/usr/bin/env bash
# Montaje "Perros vs. policía": 4 clips + música del video original de WhatsApp.
# Uso: SRC=/ruta/a/los/clips ./build.sh [preview|final]
# Los archivos fuente no se modifican; todo se lee en modo solo-lectura.
set -euo pipefail

SRC="${SRC:-/root/.claude/uploads/d3bd6078-41ba-5178-8c33-16b7f8f516e9}"
MODE="${1:-final}"
OUT_DIR="$(cd "$(dirname "$0")" && pwd)/out"
mkdir -p "$OUT_DIR"

C1="$SRC/0f02b0ca-Clip_1_Espera.mp4"       # 1080x1920 24fps – espera con luces policiales
C2="$SRC/5d8d8efd-Video_clip_2_1.mp4"      # 1280x720 (vertical con barras) – oficial pide documentos
C3="$SRC/4c32f91b-Video_Project.mp4"       # 1280x720 (vertical con barras) – entrega del fajo
C4="$SRC/0a88485e-Clip_3_Fuga.mp4"         # 720x1280 24fps – fuga con dinero volando
MUSIC="$SRC/8329b90f-WhatsApp_Video_2026-09-30_at_12.25.17_PM.mp4"  # video original (solo audio)

# Salida: 720x1280 (resolución nativa de la toma más baja), 24 fps.
W=720; H=1280; FPS=24

# Segmentos (segundos dentro de cada fuente). Duraciones múltiplos de 1/24.
S1_IN=5.5;   S1_LEN=4.000   # 96 f  -> línea de tiempo 0.000–4.000 (corte en golpe musical 4.02; 0–5 s descartado: el copiloto sale de cuadro)
S2_IN=0;     S2_LEN=1.6667  # 40 f  -> 4.000–5.667 (antes de 1.75 s, donde el oficial atraviesa la puerta)
S3_IN=0.9;   S3_LEN=2.625   # 63 f  -> 5.667–8.292 (la pata con el fajo toca la mano en el golpe 6.66)
S4_IN=0;     S4_LEN=3.6667  # 88 f  -> 8.292–11.958 (fuga sobre el clímax musical)
TOTAL=11.9583               # 287 f; la música original se detiene sola en 11.95 s

# Las tomas 2 y 3 son verticales con barras laterales dentro de 1280x720:
# el contenido útil está en x=438..842; se recorta un borde mínimo para evitar filos oscuros.
PILLAR="crop=400:711:440:4"
# Igualación de color: evaluada con signalstats en las uniones; no hizo falta.
EQ23="null"  # medido: sin ajuste el salto de luminancia es menor (54→56); no se corrige color

if [[ "$MODE" == "preview" ]]; then
  OUT="$OUT_DIR/prueba.mp4"; CRF=26; PRESET=veryfast
else
  OUT="$OUT_DIR/perros_final.mp4"; CRF=18; PRESET=slow
fi

ffmpeg -hide_banner -y \
  -ss "$S1_IN" -t "$S1_LEN" -i "$C1" \
  -ss "$S2_IN" -t "$S2_LEN" -i "$C2" \
  -ss "$S3_IN" -t "$S3_LEN" -i "$C3" \
  -ss "$S4_IN" -t "$S4_LEN" -i "$C4" \
  -i "$MUSIC" \
  -filter_complex "
    [0:v]scale=${W}:${H}:flags=lanczos,fps=${FPS},setsar=1,trim=end_frame=96,setpts=PTS-STARTPTS[v1];
    [1:v]${PILLAR},scale=${W}:${H}:flags=lanczos,${EQ23},fps=${FPS},setsar=1,trim=end_frame=40,setpts=PTS-STARTPTS[v2];
    [2:v]${PILLAR},scale=${W}:${H}:flags=lanczos,${EQ23},fps=${FPS},setsar=1,trim=end_frame=63,setpts=PTS-STARTPTS[v3];
    [3:v]scale=${W}:${H}:flags=lanczos,fps=${FPS},setsar=1,trim=end_frame=88,setpts=PTS-STARTPTS[v4];
    [v1][v2][v3][v4]concat=n=4:v=1:a=0,format=yuv420p[v];
    [4:a]atrim=0:${TOTAL},asetpts=PTS-STARTPTS,aresample=48000,afade=t=in:d=0.03,afade=t=out:st=11.80:d=0.15[a]
  " \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset "$PRESET" -crf "$CRF" -profile:v high -pix_fmt yuv420p -r $FPS \
  -c:a aac -b:a 192k -ar 48000 \
  -movflags +faststart -t "$TOTAL" "$OUT"

echo "Exportado: $OUT"
