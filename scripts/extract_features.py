#!/usr/bin/env python3
"""
Feature Extraction Script for Sign Language Translation
Extracts CNN features from raw PNG frames and saves as .pt files.

Uses EfficientNet-B0 by default (or InceptionV3 as in Camgöz et al.)
to convert video frames into feature vectors for the Transformer encoder.

Usage:
    python scripts/extract_features.py \
        --data_dir data/de \
        --split train \
        --model efficientnet_b0 \
        --batch_size 64

Output:
    data/de/features/{split}/{video_id}.pt
    Each .pt file contains a tensor of shape (T, feature_dim)
    where T = number of frames, feature_dim = model output size
"""

import os
import sys
import argparse
from pathlib import Path
from tqdm import tqdm
from natsort import natsorted

import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms, models
from PIL import Image
import pandas as pd


class FrameDataset(Dataset):
    """Loads all PNG frames from a single video folder."""

    def __init__(self, frame_paths, transform):
        self.frame_paths = frame_paths
        self.transform = transform

    def __len__(self):
        return len(self.frame_paths)

    def __getitem__(self, idx):
        img = Image.open(self.frame_paths[idx]).convert("RGB")
        return self.transform(img)


def build_feature_extractor(model_name: str, device: torch.device):
    """
    Build a CNN feature extractor (removes classification head).

    :param model_name: one of 'efficientnet_b0', 'resnet50', 'inception_v3'
    :param device: torch device
    :return: (model, feature_dim, input_size)
    """
    if model_name == "efficientnet_b0":
        weights = models.EfficientNet_B0_Weights.DEFAULT
        model = models.efficientnet_b0(weights=weights)
        feature_dim = model.classifier[1].in_features
        model.classifier = nn.Identity()
        input_size = 224
    elif model_name == "efficientnet_b7":
        weights = models.EfficientNet_B7_Weights.DEFAULT
        model = models.efficientnet_b7(weights=weights)
        feature_dim = model.classifier[1].in_features
        model.classifier = nn.Identity()
        input_size = 600
    elif model_name == "resnet50":
        weights = models.ResNet50_Weights.DEFAULT
        model = models.resnet50(weights=weights)
        feature_dim = model.fc.in_features
        model.fc = nn.Identity()
        input_size = 224
    elif model_name == "inception_v3":
        weights = models.Inception_V3_Weights.DEFAULT
        model = models.inception_v3(weights=weights)
        model.aux_logits = False
        feature_dim = model.fc.in_features
        model.fc = nn.Identity()
        input_size = 299
    else:
        raise ValueError(f"Unknown model: {model_name}")

    model = model.to(device)
    model.eval()

    return model, feature_dim, input_size


def get_transform(input_size: int):
    """Standard ImageNet preprocessing transform."""
    return transforms.Compose([
        transforms.Resize((input_size, input_size)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225],
        ),
    ])


def extract_features_for_split(
    data_dir: str,
    split: str,
    model_name: str,
    batch_size: int = 64,
    num_workers: int = 4,
    device: torch.device = None,
    annotation_file: str = None,
):
    """
    Extract features for all videos in a split.

    :param data_dir: root data directory (e.g., data/de)
    :param split: one of 'train', 'dev', 'test'
    :param model_name: CNN backbone name
    :param batch_size: batch size for frame processing
    :param num_workers: DataLoader workers
    :param device: torch device
    :param annotation_file: optional path to annotation CSV to get video list
    """
    if device is None:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    print(f"\n{'='*60}")
    print(f"Extrayendo features: {split} | Modelo: {model_name} | Device: {device}")
    print(f"{'='*60}")

    # Build model
    model, feature_dim, input_size = build_feature_extractor(model_name, device)
    transform = get_transform(input_size)

    print(f"Feature dimension: {feature_dim}")

    # Output directory
    out_dir = Path(data_dir) / "features" / split
    out_dir.mkdir(parents=True, exist_ok=True)

    # Get list of video directories
    split_dir = Path(data_dir) / split
    if not split_dir.exists():
        print(f"ERROR: Split directory not found: {split_dir}")
        return

    video_dirs = sorted([d for d in split_dir.iterdir() if d.is_dir()])

    if annotation_file:
        # If annotation file provided, only process videos that appear in it
        df = pd.read_csv(annotation_file, delimiter='|')
        video_names = set(df['name'].tolist())
        video_dirs = [d for d in video_dirs if d.name in video_names]

    print(f"Videos a procesar: {len(video_dirs)}")

    skipped = 0
    processed = 0

    with torch.no_grad():
        for video_dir in tqdm(video_dirs, desc=f"Extracting {split}"):
            out_path = out_dir / f"{video_dir.name}.pt"

            # Skip if already extracted
            if out_path.exists():
                skipped += 1
                continue

            # Find all PNG frames, sorted naturally
            frame_paths = natsorted(list(video_dir.glob("*.png")))

            if len(frame_paths) == 0:
                continue

            # Create dataset and dataloader for this video's frames
            frame_dataset = FrameDataset(frame_paths, transform)
            frame_loader = DataLoader(
                frame_dataset,
                batch_size=batch_size,
                shuffle=False,
                num_workers=num_workers,
                pin_memory=True,
            )

            # Extract features batch by batch
            all_features = []
            for batch_frames in frame_loader:
                batch_frames = batch_frames.to(device)
                features = model(batch_frames)
                all_features.append(features.cpu())

            # Concatenate all frame features: (T, feature_dim)
            video_features = torch.cat(all_features, dim=0)

            # Save as .pt
            torch.save(video_features, out_path)
            processed += 1

    print(f"\nCompletado: {processed} procesados, {skipped} ya existían")
    print(f"Features guardados en: {out_dir}")
    print(f"Dimensión de features: {feature_dim}")

    return feature_dim


def main():
    parser = argparse.ArgumentParser("Feature Extraction for Sign Language Translation")
    parser.add_argument("--data_dir", type=str, required=True,
                        help="Root data directory (e.g., data/de)")
    parser.add_argument("--split", type=str, nargs="+", default=["train", "dev", "test"],
                        help="Splits to process")
    parser.add_argument("--model", type=str, default="efficientnet_b0",
                        choices=["efficientnet_b0", "efficientnet_b7", "resnet50", "inception_v3"],
                        help="CNN backbone for feature extraction")
    parser.add_argument("--batch_size", type=int, default=64,
                        help="Batch size for frame processing")
    parser.add_argument("--num_workers", type=int, default=4,
                        help="DataLoader workers")
    parser.add_argument("--gpu_id", type=str, default="0",
                        help="GPU to use")

    args = parser.parse_args()

    os.environ["CUDA_VISIBLE_DEVICES"] = args.gpu_id
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    # Map splits to annotation files
    annotation_map = {
        "train": "PHOENIX-2014-T.train.corpus.csv",
        "dev": "PHOENIX-2014-T.dev.corpus.csv",
        "test": "PHOENIX-2014-T.test.corpus.csv",
    }

    feature_dim = None
    for split in args.split:
        ann_file = os.path.join(args.data_dir, "annotations", "manual",
                                annotation_map.get(split, f"PHOENIX-2014-T.{split}.corpus.csv"))
        if not os.path.exists(ann_file):
            ann_file = None

        feature_dim = extract_features_for_split(
            data_dir=args.data_dir,
            split=split,
            model_name=args.model,
            batch_size=args.batch_size,
            num_workers=args.num_workers,
            device=device,
            annotation_file=ann_file,
        )

    if feature_dim:
        print(f"\n{'='*60}")
        print(f"¡EXTRACCIÓN COMPLETA!")
        print(f"{'='*60}")
        print(f"Actualiza tu config YAML con:")
        print(f"  feature_size: {feature_dim}")
        print(f"  annotation_format: csv")
        print(f"  features_dir: {args.data_dir}/features")


if __name__ == "__main__":
    main()
