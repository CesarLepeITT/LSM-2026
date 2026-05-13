# coding: utf-8
"""
Dataset module - Modernized (pure PyTorch, no torchtext.legacy)
Supports both legacy .pami0 (pickle+gzip) files and CSV annotations.
"""
import os
import pickle
import gzip
import torch
from torch.utils.data import Dataset
from typing import List, Tuple, Dict, Optional


def load_dataset_file(filename):
    """Load a gzipped pickle dataset file (legacy .pami0 format)."""
    with gzip.open(filename, "rb") as f:
        loaded_object = pickle.load(f)
        return loaded_object


class SignTranslationDataset(Dataset):
    """
    Dataset for Sign Language Translation.
    Supports two annotation formats:
      1. Legacy .pami0 (pickle+gzip) files containing pre-extracted features
      2. CSV annotations with pre-extracted .npy/.pt feature files
    """

    def __init__(
        self,
        path,
        filter_pred=None,
        annotation_format: str = "pami0",
        features_dir: str = None,
    ):
        """
        Create a SignTranslationDataset.

        :param path: path(s) to annotation file(s)
        :param filter_pred: optional filter predicate function
        :param annotation_format: "pami0" for legacy pickle+gzip, "csv" for CSV files
        :param features_dir: directory containing pre-extracted features (for CSV format)
        """
        if not isinstance(path, list):
            path = [path]

        self.samples = []

        if annotation_format == "pami0":
            self._load_pami0(path)
        elif annotation_format == "csv":
            self._load_csv(path, features_dir)
        else:
            raise ValueError(f"Unknown annotation format: {annotation_format}")

        # Apply filter if provided
        if filter_pred is not None:
            self.samples = [s for s in self.samples if filter_pred(s)]

    def _load_pami0(self, paths: List[str]):
        """Load from legacy pickle+gzip format."""
        merged = {}
        for annotation_file in paths:
            tmp = load_dataset_file(annotation_file)
            for s in tmp:
                seq_id = s["name"]
                if seq_id in merged:
                    assert merged[seq_id]["name"] == s["name"]
                    assert merged[seq_id]["signer"] == s["signer"]
                    assert merged[seq_id]["gloss"] == s["gloss"]
                    assert merged[seq_id]["text"] == s["text"]
                    merged[seq_id]["sign"] = torch.cat(
                        [merged[seq_id]["sign"], s["sign"]], axis=1
                    )
                else:
                    merged[seq_id] = {
                        "name": s["name"],
                        "signer": s["signer"],
                        "gloss": s["gloss"],
                        "text": s["text"],
                        "sign": s["sign"],
                    }

        for s in merged.values():
            self.samples.append({
                "name": s["name"],
                "signer": s["signer"],
                # Add small epsilon for numerical stability (matching original)
                "sign": s["sign"] + 1e-8,
                "gloss": s["gloss"].strip(),
                "text": s["text"].strip(),
            })

    def _load_csv(self, paths: List[str], features_dir: Optional[str]):
        """Load from CSV annotation format with pre-extracted features."""
        import pandas as pd

        for annotation_file in paths:
            df = pd.read_csv(annotation_file, delimiter='|')
            for _, row in df.iterrows():
                name = row["name"]
                # Try loading pre-extracted features
                sign = self._load_features(name, features_dir)
                if sign is not None:
                    self.samples.append({
                        "name": name,
                        "signer": row.get("speaker", "unknown"),
                        "sign": sign + 1e-8,
                        "gloss": str(row["orth"]).strip(),
                        "text": str(row["translation"]).strip(),
                    })

    def _load_features(self, name: str, features_dir: Optional[str]) -> Optional[torch.Tensor]:
        """Load pre-extracted features for a given sample name.
        Searches in features_dir directly, then in split subdirs (train/dev/test).
        """
        if features_dir is None:
            return None

        # Search paths in priority order
        search_paths = [
            os.path.join(features_dir, f"{name}.pt"),
            os.path.join(features_dir, f"{name}.npy"),
        ]
        # Also search in split subdirectories
        for split in ["train", "dev", "test"]:
            search_paths.append(os.path.join(features_dir, split, f"{name}.pt"))
            search_paths.append(os.path.join(features_dir, split, f"{name}.npy"))

        for path in search_paths:
            if os.path.exists(path):
                if path.endswith(".pt"):
                    return torch.load(path, map_location="cpu", weights_only=True)
                else:
                    import numpy as np
                    return torch.from_numpy(np.load(path)).float()

        return None

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx) -> Dict:
        """
        Returns a sample dict with keys:
          - name: str
          - signer: str
          - sign: Tensor of shape (1, T, feature_dim) or (T, feature_dim)
          - gloss: str
          - text: str
        """
        return self.samples[idx]

    @property
    def sequence(self):
        """Compatibility property: yields sequence names."""
        return [s["name"] for s in self.samples]

    @property
    def gls(self):
        """Compatibility property: yields tokenized glosses."""
        return [s["gloss"].split() for s in self.samples]

    @property
    def txt(self):
        """Compatibility property: yields tokenized text."""
        return [s["text"].split() for s in self.samples]
