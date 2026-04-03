#!/usr/bin/env python3

import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
import time

print("PyTorch version:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
if hasattr(torch.backends, "mps"):
    print("MPS available:", torch.backends.mps.is_available())

# Load MNIST dataset
transform = transforms.Compose(
    [
        transforms.ToTensor(),  # This automatically normalizes to [0, 1]
    ]
)

print("\nDownloading/Loading MNIST dataset...")
train_dataset = datasets.MNIST(
    root="./data", train=True, download=True, transform=transform
)
test_dataset = datasets.MNIST(
    root="./data", train=False, download=True, transform=transform
)

train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True)
test_loader = DataLoader(test_dataset, batch_size=32, shuffle=False)


def run_mnist(device_name):
    device = torch.device(device_name)
    print(f"\n========== Running on {device} ==========")

    # Define the model
    model = nn.Sequential(
        nn.Flatten(),
        nn.Linear(28 * 28, 128),
        nn.ReLU(),
        nn.Dropout(0.2),
        nn.Linear(128, 10),
    ).to(device)

    # Loss and optimizer
    criterion = nn.CrossEntropyLoss()  # Combines softmax and negative log likelihood
    optimizer = optim.Adam(model.parameters())

    # Training loop
    epochs = 5
    start_time = time.time()

    for epoch in range(epochs):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0

        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.to(device), target.to(device)

            # Zero the gradients
            optimizer.zero_grad()

            # Forward pass
            output = model(data)
            loss = criterion(output, target)

            # Backward pass and optimize
            loss.backward()
            optimizer.step()

            # Statistics
            running_loss += loss.item()
            _, predicted = torch.max(output.data, 1)
            total += target.size(0)
            correct += (predicted == target).sum().item()

        accuracy = 100 * correct / total
        avg_loss = running_loss / len(train_loader)
        print(
            f"Epoch {epoch + 1}/{epochs} - Loss: {avg_loss:.4f}, Accuracy: {accuracy:.2f}%"
        )

    end_time = time.time()
    print(f"-> Total Training Time: {end_time - start_time:.4f} seconds")

    # Evaluation
    model.eval()
    correct = 0
    total = 0

    eval_start = time.time()
    with torch.no_grad():
        for data, target in test_loader:
            data, target = data.to(device), target.to(device)
            output = model(data)
            _, predicted = torch.max(output.data, 1)
            total += target.size(0)
            correct += (predicted == target).sum().item()

    eval_end = time.time()
    test_accuracy = 100 * correct / total
    print(
        f"-> Test Accuracy: {test_accuracy:.2f}% (Eval Time: {eval_end - eval_start:.4f} seconds)"
    )

    # Get probabilities for first 5 test samples
    with torch.no_grad():
        test_data, _ = next(iter(test_loader))
        test_data = test_data[:5].to(device)
        logits = model(test_data)
        probabilities = torch.softmax(logits, dim=1)
        print("\nProbabilities for first 5 test samples:")
        print(probabilities)


# Run CPU
run_mnist("cpu")

# Determine and run accelerated device
if torch.cuda.is_available():
    run_mnist("cuda:0")
elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
    run_mnist("mps")
else:
    print("\nNo accelerated device (CUDA/MPS) found. Skipping accelerated run.")
