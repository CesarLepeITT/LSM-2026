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

if __name__ == '__main__':
    # Ejecución de ejemplo apuntando a la nueva estructura:
    # extract_features('how2sign_annotations.json', 'data/en/how2sign_train.gzip')
    pass
