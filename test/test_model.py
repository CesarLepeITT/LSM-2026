"""
Model evaluation script - Modernized (no torchtext dependency)
"""
import sys
import torch
from signjoey.data import load_data
from signjoey.model import build_model
from signjoey.helpers import load_config, get_latest_checkpoint, load_checkpoint
from signjoey.prediction import validate_on_data
from signjoey.vocabulary import PAD_TOKEN, SIL_TOKEN
from signjoey.loss import XentLoss

import jiwer
from rouge_score import rouge_scorer
import sacrebleu

def evaluate_model(cfg_file):
    print(f"Cargando configuración desde {cfg_file}...")
    try:
        cfg = load_config(cfg_file)
    except Exception as e:
        print(f"Error cargando config: {e}")
        sys.exit(1)
        
    model_dir = cfg["training"]["model_dir"]
    ckpt = get_latest_checkpoint(model_dir)
    if ckpt is None:
        print(f"Error: No se encontró ningún checkpoint en {model_dir}")
        sys.exit(1)
        
    print(f"Cargando checkpoint: {ckpt}")
    use_cuda = cfg["training"].get("use_cuda", False)
    model_checkpoint = load_checkpoint(ckpt, use_cuda=use_cuda)
    
    _, _, test_data, gls_vocab, txt_vocab = load_data(data_cfg=cfg["data"])
    
    do_recognition = cfg["training"].get("recognition_loss_weight", 1.0) > 0.0
    do_translation = cfg["training"].get("translation_loss_weight", 1.0) > 0.0
    
    sgn_dim = sum(cfg["data"]["feature_size"]) if isinstance(cfg["data"]["feature_size"], list) else cfg["data"]["feature_size"]
    
    model = build_model(
        cfg=cfg["model"],
        gls_vocab=gls_vocab,
        txt_vocab=txt_vocab,
        sgn_dim=sgn_dim,
        do_recognition=do_recognition,
        do_translation=do_translation,
    )
    model.load_state_dict(model_checkpoint["model_state"])
    if use_cuda:
        model.cuda()
        
    batch_size = cfg["training"]["batch_size"]
    batch_type = cfg["training"].get("batch_type", "sentence")
    level = cfg["data"]["level"]
    dataset_version = cfg["data"].get("version", "how2sign")
    
    print("Iniciando inferencia sobre la partición de prueba...")
    
    # Loss functions required for API compatibility
    recognition_loss_function = torch.nn.CTCLoss(blank=model.gls_vocab.stoi[SIL_TOKEN], zero_infinity=True) if do_recognition else None
    translation_loss_function = XentLoss(pad_index=txt_vocab.stoi[PAD_TOKEN], smoothing=0.0) if do_translation else None
    
    if use_cuda:
        if recognition_loss_function: recognition_loss_function.cuda()
        if translation_loss_function: translation_loss_function.cuda()

    results = validate_on_data(
        model=model,
        data=test_data,
        batch_size=batch_size,
        use_cuda=use_cuda,
        sgn_dim=sgn_dim,
        do_recognition=do_recognition,
        recognition_loss_function=recognition_loss_function,
        recognition_loss_weight=1 if do_recognition else 0,
        do_translation=do_translation,
        translation_loss_function=translation_loss_function,
        translation_loss_weight=1 if do_translation else 0,
        translation_max_output_length=cfg["training"].get("translation_max_output_length", None),
        level=level,
        txt_pad_index=txt_vocab.stoi[PAD_TOKEN],
        recognition_beam_size=1,
        translation_beam_size=1,
        translation_beam_alpha=-1,
        batch_type=batch_type,
        dataset_version=dataset_version,
    )
    
    print("\n" + "="*43)
    print("RESULTADOS DE EVALUACIÓN (Sign Language Transformers)")
    print("="*43)
    
    if do_recognition:
        gls_ref = results["gls_ref"]
        gls_hyp = results["gls_hyp"]
        # Filtrado para robustez contra arrays vacíos en jiwer
        gls_ref_clean = [r if r.strip() else "EMPTY" for r in gls_ref]
        gls_hyp_clean = [h if h.strip() else "EMPTY" for h in gls_hyp]
        
        wer_score = jiwer.wer(gls_ref_clean, gls_hyp_clean) * 100
        print("[Reconocimiento de Glosas]")
        print(f"WER (Word Error Rate): {wer_score:.2f} %\n")
        
    if do_translation:
        txt_ref = results["txt_ref"]
        txt_hyp = results["txt_hyp"]
        
        bleu_scores = sacrebleu.corpus_bleu(txt_hyp, [txt_ref])
        
        scorer = rouge_scorer.RougeScorer(['rougeL'], use_stemmer=True)
        rouge_scores = [scorer.score(r, h)['rougeL'].fmeasure for r, h in zip(txt_ref, txt_hyp)]
        rouge_l_score = (sum(rouge_scores) / len(rouge_scores)) * 100 if rouge_scores else 0.0
        
        print("[Traducción de Texto]")
        print(f"BLEU-1: {bleu_scores.precisions[0]:.2f}")
        print(f"BLEU-2: {bleu_scores.precisions[1]:.2f}")
        print(f"BLEU-3: {bleu_scores.precisions[2]:.2f}")
        print(f"BLEU-4: {bleu_scores.precisions[3]:.2f}")
        print(f"ROUGE-L: {rouge_l_score:.2f}")
        
    print("="*43)

if __name__ == "__main__":
    evaluate_model(sys.argv[1])
