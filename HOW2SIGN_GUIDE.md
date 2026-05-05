# Guía Técnica: Adaptación de Sign Language Transformers (SLT) para How2Sign

Esta guía documenta los pasos exhaustivos para adaptar el repositorio `neccam/slt` para entrenar modelos de traducción de lenguaje de señas con el dataset **How2Sign**, optimizado para un entorno con severas restricciones de memoria VRAM (GPU Nvidia GeForce MX330 ~2GB VRAM).

---

## 1. Configuración del Entorno Virtual

El repositorio original fue construido con versiones muy antiguas de PyTorch (1.4.0) y TorchText (0.5.0). Para aprovechar la compatibilidad de CUDA en la MX330 (arquitectura Pascal) sin romper la estructura interna del repositorio (que depende fuertemente de clases obsoletas de torchtext), actualizaremos a versiones intermedias que aún conservan el módulo legacy.

Crea un archivo `requirements.txt` actualizado en la raíz del repositorio:

```text
# requirements.txt actualizado para compatibilidad legacy y CUDA
torch==1.8.1
torchvision==0.9.1
torchtext==0.9.1
numpy==1.26.2
PyYAML==6.0.1
tensorboard==2.15.1
sacrebleu==2.4.0
scikit-learn==1.3.2
tqdm==4.66.1
```

Instálalo en tu entorno virtual:
```bash
pip install -r requirements.txt
```

---

## 2. Especificación General del Formato de Datos

El DataLoader nativo del repositorio (diseñado inicialmente para el dataset PHOENIX14T) espera un archivo serializado y comprimido.

*   **Formato de Compresión / Serialización:** Archivo `.gzip` que contiene un objeto Python empaquetado con `pickle`.
*   **Estructura Interna:** Una lista (`List`) de diccionarios (`Dict`), donde cada diccionario representa un único video/secuencia.

### Plantilla Universal de Características (Obligatorias):
Cada diccionario en la lista iterada debe contener **exactamente** las siguientes claves:

| Clave | Tipo de Dato | Descripción y Dimensiones Esperadas |
| :--- | :--- | :--- |
| `name` | `str` | Identificador único de la secuencia de video (ej. `"how2sign_vid_001"`). |
| `signer` | `str` | Identificador único del intérprete de señas (ej. `"signer_12"`). |
| `gloss` | `str` | Transcripción de las glosas en lenguaje de señas, separadas por espacios. |
| `text` | `str` | Traducción al idioma hablado (inglés para How2Sign). |
| `sign` | `torch.Tensor` | Tensor 2D de características visuales. <br>**Dimensión:** `[num_frames, feature_dim]`. <br>*(Ej: 100 frames y 150 dimensiones = Tensor de tamaño `[100, 150]` de tipo `float32`)*. |

---

## 3. Gestión de Almacenamiento y Datasets

Debido al espacio limitado del disco y al gran tamaño de los datasets multimodales, hemos creado una herramienta interactiva para gestionar el almacenamiento y separar organizativamente los idiomas.

Se implementó el script `data/manage_datasets.sh`, el cual proporciona un menú para:
1. **Descargar PHOENIX-14T**: Descarga directamente los archivos a la nueva carpeta `data/de/`.
2. **Preparar How2Sign**: Prepara la ruta de salida en `data/en/` para los archivos preprocesados del idioma inglés.
3. **Eliminar Datasets**: Permite borrar con seguridad cualquiera de las carpetas de idiomas de forma individual (`data/de/*` o `data/en/*`) para liberar el disco NVMe y alternar proyectos sin problemas.

Para utilizarlo, simplemente dale permisos de ejecución y lánzalo:
```bash
chmod +x data/manage_datasets.sh
./data/manage_datasets.sh
```

---

## 4. Adaptación y Preprocesamiento de Datos (How2Sign)

### Estrategia de Preprocesamiento para Hardware Limitado
Dado que la MX330 tiene solo ~2GB de VRAM, extraer características mediante Redes Neuronales Convolucionales (CNN) por cada frame de video crudo resultará inmediatamente en un error de `CUDA Out of Memory`. 

**La solución es extraer características ligeras usando Keypoints 3D**. Si How2Sign provee pose estimable (por ejemplo de MediaPipe o OpenPose), usaremos las coordenadas `(x, y, z)` de las manos, pose y cara. Si seleccionamos 50 keypoints, el `feature_dim` por frame será `50 * 3 = 150` dimensiones, lo cual es extremadamente ligero para el Transformer.

### Script de Empaquetado (`preprocess_how2sign.py`)
Guarda este script en la carpeta `data/` y ejecútalo para generar el archivo de entrenamiento compatible, asegurándote de exportarlo a la nueva carpeta `data/en/` creada por la herramienta de gestión:

```python
import pickle
import gzip
import torch
import json
import numpy as np

def extract_features(how2sign_data_path, output_path):
    dataset_formateado = []
    
    # Supongamos que lees un JSON con las anotaciones de How2Sign
    with open(how2sign_data_path, 'r') as f:
        how2sign_data = json.load(f)
        
    for item in how2sign_data:
        # Extraer keypoints 3D [num_frames, num_keypoints, 3 coords]
        # Esto reemplaza el procesamiento pesado de imágenes
        keypoints = np.array(item['keypoints'], dtype=np.float32)
        frames, num_keypoints, coords = keypoints.shape
        
        # Aplanar los keypoints espaciales para que cada frame sea un vector 1D
        # Dimensión resultante: [num_frames, num_keypoints * 3]
        sign_features = torch.tensor(keypoints.reshape(frames, -1))
        
        sample = {
            "name": item["video_id"],
            "signer": item["signer_id"],
            "gloss": item["gloss_sequence"],
            "text": item["english_translation"],
            "sign": sign_features
        }
        dataset_formateado.append(sample)
        
    # Guardar en el formato requerido por el DataLoader (.gzip + pickle)
    with gzip.open(output_path, 'wb') as f:
        pickle.dump(dataset_formateado, f)

    print(f"Dataset de How2Sign empaquetado exitosamente en {output_path}")

# Ejecución de ejemplo apuntando a la nueva estructura:
# extract_features('how2sign_annotations.json', 'data/en/how2sign_train.gzip')
```

---

## 5. Modificaciones en el Código Fuente (`neccam/slt`)

Para evitar reescribir completamente la canalización de datos debido a la deprecación de las clases `Field` y `BucketIterator` en versiones recientes de TorchText, aplicaremos una solución de compatibilidad utilizando el módulo `torchtext.legacy`.

### A. Modificar importaciones en `signjoey/dataset.py`, `signjoey/data.py` y `signjoey/vocabulary.py`
Debes buscar en la cabecera de estos tres archivos cualquier importación de `torchtext.data` y cambiarla estrictamente a `torchtext.legacy.data`. 

Por ejemplo, en **`signjoey/dataset.py`** (aprox. línea 5):
```python
# Elimina o comenta esto:
# from torchtext import data
# from torchtext.data import Field, RawField

# Reemplaza por:
from torchtext.legacy import data
from torchtext.legacy.data import Field, RawField
```

En **`signjoey/data.py`** (aprox. línea 10):
```python
# Elimina o comenta esto:
# from torchtext import data
# from torchtext.data import Dataset, Iterator

# Reemplaza por:
from torchtext.legacy import data
from torchtext.legacy.data import Dataset, Iterator
```

En **`signjoey/vocabulary.py`** (aprox. línea 6):
```python
# Elimina o comenta esto:
# from torchtext.data import Dataset

# Reemplaza por:
from torchtext.legacy.data import Dataset
```

Con estas simples modificaciones en las importaciones, el repositorio volverá a ser funcional manteniendo su infraestructura original intacta bajo PyTorch 1.8.1.

### B. Modificar `signjoey/training.py` (Activando FP16 - Mixed Precision)
Para evitar los OOM (Out of Memory) en la MX330, usaremos el `autocast` nativo de PyTorch, que reduce el tamaño de las activaciones a la mitad (16 bits) durante el forward pass.

1. Al inicio del archivo, importa los módulos necesarios:
```python
from torch.cuda.amp import autocast, GradScaler
```

2. Dentro del constructor `__init__` de la clase `TrainManager`, inicializa el scaler:
```python
        # Inicializar Mixed Precision GradScaler (alrededor de la línea 170)
        self.scaler = GradScaler()
```

3. Modifica la función `_train_batch` (aprox. línea 729) para envolver el cálculo del loss y la actualización:
```python
    def _train_batch(self, batch: Batch, update: bool = True) -> (Tensor, Tensor):
        # 1. Envolver el forward pass y el cálculo del loss en autocast
        with autocast():
            recognition_loss, translation_loss = self.model.get_loss_for_batch(
                batch=batch,
                recognition_loss_function=self.recognition_loss_function if self.do_recognition else None,
                translation_loss_function=self.translation_loss_function if self.do_translation else None,
                recognition_loss_weight=self.recognition_loss_weight if self.do_recognition else None,
                translation_loss_weight=self.translation_loss_weight if self.do_translation else None,
            )

            # Normalizaciones... (mantén el código existente para normalizar el loss)
            normalized_translation_loss = translation_loss / (batch.num_seqs * self.batch_multiplier)
            normalized_recognition_loss = recognition_loss / self.batch_multiplier
            total_loss = normalized_recognition_loss + normalized_translation_loss

        # 2. Computar gradientes escalados
        self.scaler.scale(total_loss).backward()

        if self.clip_grad_fun is not None:
            # Desescalar antes del clipping
            self.scaler.unscale_(self.optimizer)
            self.clip_grad_fun(params=self.model.parameters())

        if update:
            # 3. Step y actualización del Scaler
            self.scaler.step(self.optimizer)
            self.scaler.update()
            self.optimizer.zero_grad()
            self.steps += 1
```

---

## 6. Configuración de Entrenamiento (`sign.yaml`) (Optimización VRAM y Rutas)

Para garantizar que el entrenamiento se ejecute en la MX330 de 2GB de VRAM, **es imperativo** aplicar una configuración estricta. Además, ahora debemos apuntar a la carpeta del idioma correspondiente.

Crea un archivo `configs/how2sign.yaml` con esta configuración:

```yaml
data:
    # IMPORTANTE: Apuntar a la carpeta del idioma (data/en/ para How2Sign o data/de/ para PHOENIX)
    data_path: data/en/
    version: how2sign
    # Ajusta esto según el tamaño de tu vector de keypoints (ej. 50 * 3)
    feature_size: 150 
    level: word
    txt_lowercase: true
    max_sent_length: 200 # Reducir sentencias extremadamente largas

training:
    use_cuda: true
    # VRAM STRICT OPTIMIZATION: 
    batch_size: 2             # Un batch diminuto cabe en 2GB VRAM
    batch_multiplier: 16      # Gradient Accumulation: Simula un batch real de 32 (2 * 16)
    epochs: 100
    learning_rate: 0.001
    eval_batch_size: 2
    recognition_loss_weight: 1.0
    translation_loss_weight: 1.0

model:
    encoder:
        type: transformer
        hidden_size: 128     # Reducido drásticamente (original era 512)
        num_layers: 2        # Reducido (original 3)
        num_heads: 4         # Reducido (original 8)
    decoder:
        type: transformer
        hidden_size: 128     # Reducido drásticamente
        num_layers: 2        # Reducido
        num_heads: 4         # Reducido
```

### Resumen de Prevención contra Errores OOM:
1. **Extracción ligera de features:** El uso de Keypoints espaciales (1D) elimina la carga de cargar y procesar imágenes RGB enteras.
2. **`batch_size: 2`**: Asegura que el pase de red hacia adelante ocupe mínima VRAM.
3. **`batch_multiplier: 16`**: Permite al modelo converger como si entrenara en GPU con 32+ GB, acumulando gradientes en la RAM convencional antes del update.
4. **Mixed Precision (`autocast`)**: Corta el espacio en memoria de los tensores casi a la mitad (16-bit Float en lugar de 32-bit Float) y acelera la matriz de cómputo CUDA.
5. **Reducción Estructural**: Bajar `hidden_size` a 128 recorta drásticamente el peso paramétrico de las matrices de la capa Transformer.
