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
C2="$SRC/96758c6b-gemini_generated_video_bdeee69a.mp4"  # 720x1280 24fps – oficial pide documentos (sin atravesar la puerta)
# (Antes: 5d8d8efd-Video_clip_2_1.mp4, descartado: desde 1.75 s el oficial atraviesa la puerta.)
C3="$SRC/4c32f91b-Video_Project.mp4"       # 1280x720 (vertical con barras) – entrega del fajo
C4="$SRC/0a88485e-Clip_3_Fuga.mp4"         # 720x1280 24fps – fuga con dinero volando
MUSIC="$SRC/8329b90f-WhatsApp_Video_2026-09-30_at_12.25.17_PM.mp4"  # video original (solo audio)

# Salida: 720x1280 (resolución nativa de la toma más baja), 24 fps.
W=720; H=1280; FPS=24

# Segmentos (segundos dentro de cada fuente). Duraciones múltiplos de 1/24.
S1_IN=5.8333; S1_LEN=4.000  # 96 f  -> línea de tiempo 0.000–4.000 (corte en golpe musical 4.02). Termina cuando
                            # la cámara se acerca al conductor y él mira a su ventana: el corte al oficial responde a esa mirada.
S2_IN=0.9583; S2_LEN=2.625  # 63 f  -> 4.000–6.625 (llega a la ventana y extiende la palma; corte en el golpe 6.66)
                            # Sincronía labial: su 1.ª sílaba (1.36 s del clip) cae en 4.40 s, donde la pista dice "what the" (4.41 s).
S3_IN=1.0;   S3_LEN=2.3333  # 56 f  -> 6.625–8.958 (palma abierta + fajo: el gesto empalma con la toma anterior)
S4_IN=0;     S4_LEN=3.000   # 72 f  -> 8.958–11.958 (fuga desde el golpe 8.96 hasta que la música se detiene)
TOTAL=11.9583               # 287 f; la música original se detiene sola en 11.95 s

# La toma 3 (Video_Project) es vertical con barras laterales dentro de 1280x720:
# el contenido útil está en x=438..842; se recorta un borde mínimo para evitar filos oscuros.
PILLAR="crop=400:711:440:4"
# Igualación de color: evaluada con signalstats en las uniones; no hizo falta.
EQ23="null"  # medido: sin ajuste el salto de luminancia es menor (54→56); no se corrige color
# La toma 3 se amplía 1.8x y queda más blanda que las demás: enfoque suave solo en luminancia (sin halos ni ruido de color).
SHARP23="unsharp=5:5:0.75:5:5:0"

if [[ "$MODE" == "preview" ]]; then
  OUT="$OUT_DIR/prueba_v4.mp4"; CRF=26; PRESET=veryfast
else
  OUT="$OUT_DIR/perros_final_v4.mp4"; CRF=18; PRESET=slow
fi

ffmpeg -hide_banner -y \
  -ss "$S1_IN" -t "$S1_LEN" -i "$C1" \
  -ss "$S2_IN" -t "$S2_LEN" -i "$C2" \
  -ss "$S3_IN" -t "$S3_LEN" -i "$C3" \
  -ss "$S4_IN" -t "$S4_LEN" -i "$C4" \
  -i "$MUSIC" \
  -filter_complex "
    [0:v]scale=${W}:${H}:flags=lanczos,fps=${FPS},setsar=1,trim=end_frame=96,setpts=PTS-STARTPTS[v1];
    [1:v]scale=${W}:${H}:flags=lanczos,fps=${FPS},setsar=1,trim=end_frame=63,setpts=PTS-STARTPTS[v2];
    [2:v]${PILLAR},scale=${W}:${H}:flags=lanczos,${EQ23},${SHARP23},fps=${FPS},setsar=1,trim=end_frame=56,setpts=PTS-STARTPTS[v3];
    [3:v]scale=${W}:${H}:flags=lanczos,fps=${FPS},setsar=1,trim=end_frame=72,setpts=PTS-STARTPTS[v4];
    [v1][v2][v3][v4]concat=n=4:v=1:a=0,format=yuv420p[v];
    [4:a]atrim=0:${TOTAL},asetpts=PTS-STARTPTS,aresample=48000,afade=t=in:d=0.03,afade=t=out:st=11.80:d=0.15[a]
  " \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset "$PRESET" -crf "$CRF" -profile:v high -pix_fmt yuv420p -r $FPS \
  -c:a aac -b:a 192k -ar 48000 \
  -movflags +faststart -t "$TOTAL" "$OUT"

echo "Exportado: $OUT"
