import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader
import pandas as pd
import re
import os

csv_path = "questions.csv"
if not os.path.exists(csv_path):
    raise FileNotFoundError(f"{csv_path} not found.")
data = pd.read_csv(csv_path)
def tokenize(text):
    return re.findall(r'\b\w+\b', str(text).lower())
embeds = {}
def get_embedding(text):
    tokens = tokenize(text)
    vecs = []
    for tok in tokens:
        if tok not in embeds:
            torch.manual_seed(abs(hash(tok)) % (2**32))
            embeds[tok] = torch.randn(300)
        vecs.append(embeds[tok])
    if not vecs:
        vecs = [torch.zeros(300)]
    return torch.stack(vecs).mean(dim=0)
q1Embeds = [get_embedding(q) for q in data['question1'].astype(str)]
q2Embeds = [get_embedding(q) for q in data['question2'].astype(str)]
labels = data['is_duplicate'].astype(float).tolist()
q1_embeds = torch.stack(q1Embeds)
q2_embeds = torch.stack(q2Embeds)
labels = torch.tensor(labels, dtype=torch.float32)
class QuoraDataset(Dataset):
    def __init__(self, q1_embeds, q2_embeds, labels):
        self.q1 = q1_embeds
        self.q2 = q2_embeds
        self.labels = labels

    def __len__(self):
        return len(self.labels)

    def __getitem__(self, idx):
        return self.q1[idx], self.q2[idx], self.labels[idx]
dataset = QuoraDataset(q1_embeds, q2_embeds, labels)
loader = DataLoader(dataset, batch_size=64, shuffle=True)
class Model(nn.Module):
    def __init__(self):
        super().__init__()
        self.hidden1 = nn.Linear(300, 256)
        self.hidden2 = nn.Linear(256, 256)
        self.hidden3 = nn.Linear(256, 256)
        self.output = nn.Linear(256, 128)
        self.final = nn.Linear(128, 1)

    def forward_once(self, x):
        x = F.relu(self.hidden1(x))
        x = F.relu(self.hidden2(x))
        x = F.relu(self.hidden3(x))
        x = self.output(x)
        return x

    def forward(self, x1, x2):
        o1 = self.forward_once(x1)
        o2 = self.forward_once(x2)
        combined = torch.abs(o1 - o2)
        return torch.sigmoid(self.final(combined))

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("Using device:", device)
network = Model().to(device)
criterion = nn.BCELoss()
optimizer = torch.optim.Adam(network.parameters(), lr=0.005)
saved_file = "moodel.pt"
if os.path.exists(saved_file):
    print(f"Loading saved model {saved_file}")
    network.load_state_dict(torch.load(saved_file, map_location=device))
else:
    print("No saved model file found")
    quit()
network.train()
epochs = int(input("Epochs: "))
for epoch in range(epochs):
    total_loss = 0
    for d1, d2, labels in loader:
        d1 = d1.to(device)
        d2 = d2.to(device)
        labels = labels.to(device)

        preds = network(d1, d2).squeeze()
        loss = criterion(preds, labels)
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
    print(f"Epoch {epoch+1}/{epochs}, Loss: {total_loss:.4f}")
torch.save(network.state_dict(), saved_file)
print(f"Model saved to {saved_file}")
