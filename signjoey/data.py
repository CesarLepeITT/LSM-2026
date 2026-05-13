# coding: utf-8
"""
Data module - Modernized (native PyTorch DataLoader, no torchtext.legacy)
"""
import os
import sys
import random

import torch
from torch.utils.data import DataLoader, Dataset
from signjoey.dataset import SignTranslationDataset
from signjoey.vocabulary import (
    build_vocab,
    Vocabulary,
    UNK_TOKEN,
    EOS_TOKEN,
    BOS_TOKEN,
    PAD_TOKEN,
)


def load_data(data_cfg: dict) -> tuple:
    """
    Load train, dev and optionally test data as specified in configuration.
    Vocabularies are created from the training set with a limit of `voc_limit`
    tokens and a minimum token frequency of `voc_min_freq`
    (specified in the configuration dictionary).

    :param data_cfg: configuration dictionary for data
        ("data" part of configuration file)
    :return:
        - train_data: training dataset
        - dev_data: development dataset
        - test_data: test dataset if given, otherwise None
        - gls_vocab: gloss vocabulary extracted from training data
        - txt_vocab: spoken text vocabulary extracted from training data
    """

    data_path = data_cfg.get("data_path", "./data")
    annotation_format = data_cfg.get("annotation_format", "pami0")
    features_dir = data_cfg.get("features_dir", None)

    if isinstance(data_cfg["train"], list):
        train_paths = [os.path.join(data_path, x) for x in data_cfg["train"]]
        dev_paths = [os.path.join(data_path, x) for x in data_cfg["dev"]]
        test_paths = [os.path.join(data_path, x) for x in data_cfg["test"]]
        pad_feature_size = sum(data_cfg["feature_size"])
    else:
        train_paths = os.path.join(data_path, data_cfg["train"])
        dev_paths = os.path.join(data_path, data_cfg["dev"])
        test_paths = os.path.join(data_path, data_cfg["test"])
        pad_feature_size = data_cfg["feature_size"]

    level = data_cfg["level"]
    txt_lowercase = data_cfg["txt_lowercase"]
    max_sent_length = data_cfg["max_sent_length"]

    def filter_pred(sample):
        """Filter by max sequence length."""
        sign = sample["sign"]
        # Handle both (1, T, D) and (T, D) shapes
        if sign.dim() == 3:
            sign_len = sign.shape[1]
        else:
            sign_len = sign.shape[0]
        text_len = len(sample["text"].split())
        return sign_len <= max_sent_length and text_len <= max_sent_length

    train_data = SignTranslationDataset(
        path=train_paths,
        filter_pred=filter_pred,
        annotation_format=annotation_format,
        features_dir=features_dir,
    )

    gls_max_size = data_cfg.get("gls_voc_limit", sys.maxsize)
    gls_min_freq = data_cfg.get("gls_voc_min_freq", 1)
    txt_max_size = data_cfg.get("txt_voc_limit", sys.maxsize)
    txt_min_freq = data_cfg.get("txt_voc_min_freq", 1)

    gls_vocab_file = data_cfg.get("gls_vocab", None)
    txt_vocab_file = data_cfg.get("txt_vocab", None)

    gls_vocab = build_vocab(
        field="gls",
        min_freq=gls_min_freq,
        max_size=gls_max_size,
        dataset=train_data,
        vocab_file=gls_vocab_file,
    )
    txt_vocab = build_vocab(
        field="txt",
        min_freq=txt_min_freq,
        max_size=txt_max_size,
        dataset=train_data,
        vocab_file=txt_vocab_file,
    )

    random_train_subset = data_cfg.get("random_train_subset", -1)
    if random_train_subset > -1:
        # select this many training examples randomly and discard the rest
        indices = list(range(len(train_data)))
        random.shuffle(indices)
        train_data.samples = [train_data.samples[i] for i in indices[:random_train_subset]]

    dev_data = SignTranslationDataset(
        path=dev_paths,
        annotation_format=annotation_format,
        features_dir=features_dir,
    )
    random_dev_subset = data_cfg.get("random_dev_subset", -1)
    if random_dev_subset > -1:
        indices = list(range(len(dev_data)))
        random.shuffle(indices)
        dev_data.samples = [dev_data.samples[i] for i in indices[:random_dev_subset]]

    test_data = SignTranslationDataset(
        path=test_paths,
        annotation_format=annotation_format,
        features_dir=features_dir,
    )

    return train_data, dev_data, test_data, gls_vocab, txt_vocab


def sign_collate_fn(batch, txt_vocab, gls_vocab, txt_lowercase=False, level="word"):
    """
    Custom collate function for sign language translation batches.
    Pads sign features, numericalizes and pads gloss/text sequences.

    :param batch: list of sample dicts from SignTranslationDataset
    :param txt_vocab: text vocabulary for numericalization
    :param gls_vocab: gloss vocabulary for numericalization
    :param txt_lowercase: whether to lowercase text
    :param level: tokenization level ("word", "bpe", "char")
    :return: dict with padded tensors
    """

    def tokenize_text(text):
        if level == "char":
            return list(text)
        else:
            return text.split()

    sequences = []
    signers = []
    sgn_list = []
    sgn_lengths = []
    gls_list = []
    gls_lengths = []
    txt_list = []
    txt_lengths = []

    for sample in batch:
        sequences.append(sample["name"])
        signers.append(sample["signer"])

        # Process sign features
        sign = sample["sign"]
        if sign.dim() == 3:
            sign = sign.squeeze(0)  # (1, T, D) -> (T, D)
        sgn_list.append(sign)
        sgn_lengths.append(sign.shape[0])

        # Process glosses
        gls_tokens = tokenize_text(sample["gloss"])
        gls_indices = [gls_vocab.stoi[t] for t in gls_tokens]
        gls_list.append(torch.tensor(gls_indices, dtype=torch.long))
        gls_lengths.append(len(gls_indices))

        # Process text
        text = sample["text"]
        if txt_lowercase:
            text = text.lower()
        txt_tokens = tokenize_text(text)
        # Add BOS and EOS
        txt_indices = (
            [txt_vocab.stoi[BOS_TOKEN]]
            + [txt_vocab.stoi[t] for t in txt_tokens]
            + [txt_vocab.stoi[EOS_TOKEN]]
        )
        txt_list.append(torch.tensor(txt_indices, dtype=torch.long))
        txt_lengths.append(len(txt_indices))

    # Pad sign features
    max_sgn_len = max(sgn_lengths)
    sgn_dim = sgn_list[0].shape[-1]
    sgn_padded = torch.zeros(len(batch), max_sgn_len, sgn_dim)
    for i, (sgn, length) in enumerate(zip(sgn_list, sgn_lengths)):
        sgn_padded[i, :length] = sgn

    # Pad glosses
    gls_pad_idx = gls_vocab.stoi[PAD_TOKEN]
    max_gls_len = max(gls_lengths) if gls_lengths else 1
    gls_padded = torch.full((len(batch), max_gls_len), gls_pad_idx, dtype=torch.long)
    for i, (gls, length) in enumerate(zip(gls_list, gls_lengths)):
        gls_padded[i, :length] = gls

    # Pad text
    txt_pad_idx = txt_vocab.stoi[PAD_TOKEN]
    max_txt_len = max(txt_lengths) if txt_lengths else 1
    txt_padded = torch.full((len(batch), max_txt_len), txt_pad_idx, dtype=torch.long)
    for i, (txt, length) in enumerate(zip(txt_list, txt_lengths)):
        txt_padded[i, :length] = txt

    return {
        "sequence": sequences,
        "signer": signers,
        "sgn": sgn_padded,
        "sgn_lengths": torch.tensor(sgn_lengths, dtype=torch.float32),
        "gls": gls_padded,
        "gls_lengths": torch.tensor(gls_lengths, dtype=torch.long),
        "txt": txt_padded,
        "txt_lengths": torch.tensor(txt_lengths, dtype=torch.long),
    }


def make_data_iter(
    dataset: Dataset,
    batch_size: int,
    batch_type: str = "sentence",
    train: bool = False,
    shuffle: bool = False,
    txt_vocab=None,
    gls_vocab=None,
    txt_lowercase: bool = False,
    level: str = "word",
) -> DataLoader:
    """
    Returns a DataLoader for a SignTranslationDataset.

    :param dataset: SignTranslationDataset
    :param batch_size: size of the batches the iterator prepares
    :param batch_type: measure batch size by sentence count or by token count
    :param train: whether it's training time
    :param shuffle: whether to shuffle the data before each epoch
    :param txt_vocab: text vocabulary for collation
    :param gls_vocab: gloss vocabulary for collation
    :param txt_lowercase: whether to lowercase text
    :param level: tokenization level
    :return: DataLoader
    """
    from functools import partial

    collate_fn = partial(
        sign_collate_fn,
        txt_vocab=txt_vocab,
        gls_vocab=gls_vocab,
        txt_lowercase=txt_lowercase,
        level=level,
    )

    data_loader = DataLoader(
        dataset=dataset,
        batch_size=batch_size,
        shuffle=shuffle if train else False,
        collate_fn=collate_fn,
        num_workers=0,  # Sign data is already in memory from __init__
        pin_memory=True,
        drop_last=False,
    )

    return data_loader
