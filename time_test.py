import time
import torch
from torchvision import transforms, models
from PIL import Image
from pathlib import Path

device = torch.device('cuda')
model = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT).to(device)
model.eval()

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

video_dir = Path("data/de/train/01April_2010_Thursday_heute-6694")
frames = list(video_dir.glob("*.png"))

print(f"Testing with {len(frames)} frames")

# Time loading
t0 = time.time()
images = [transform(Image.open(p).convert("RGB")) for p in frames]
t1 = time.time()
print(f"Image loading & processing time: {t1-t0:.4f}s")

# Time inference
batch = torch.stack(images).to(device)
t2 = time.time()
with torch.no_grad():
    out = model(batch)
t3 = time.time()
print(f"Inference time: {t3-t2:.4f}s")
