# -*- coding: utf-8 -*-

import torch
import math
import time


def run_polynomial_regression(device_name):
    device = torch.device(device_name)
    print(f"\n========== Running on {device} ==========")
    dtype = torch.float

    # Create random input and output data
    x = torch.linspace(-math.pi, math.pi, 2000, device=device, dtype=dtype)
    y = torch.sin(x)

    # Randomly initialize weights
    a = torch.randn((), device=device, dtype=dtype)
    b = torch.randn((), device=device, dtype=dtype)
    c = torch.randn((), device=device, dtype=dtype)
    d = torch.randn((), device=device, dtype=dtype)

    learning_rate = 1e-6

    start_time = time.time()
    for _t in range(2000):
        # Forward pass: compute predicted y
        y_pred = a + b * x + c * x**2 + d * x**3

        # Compute and print loss
        loss = (y_pred - y).pow(2).sum().item()

        # Backprop to compute gradients of a, b, c, d with respect to loss
        grad_y_pred = 2.0 * (y_pred - y)
        grad_a = grad_y_pred.sum()
        grad_b = (grad_y_pred * x).sum()
        grad_c = (grad_y_pred * x**2).sum()
        grad_d = (grad_y_pred * x**3).sum()

        # Update weights using gradient descent
        a -= learning_rate * grad_a
        b -= learning_rate * grad_b
        c -= learning_rate * grad_c
        d -= learning_rate * grad_d

    end_time = time.time()

    print(f"Time taken:  {end_time - start_time:.4f} seconds")
    print(f"Final loss:  {loss:.4f}")
    print(
        f"Result eq:   y = {a.item():.4f} + {b.item():.4f} x + {c.item():.4f} x^2 + {d.item():.4f} x^3"
    )


def main():
    print(f"PyTorch version: {torch.__version__}")

    # Always run CPU first
    run_polynomial_regression("cpu")

    # Determine and run accelerated device
    if torch.cuda.is_available():
        print(f"\nFound CUDA: {torch.cuda.get_device_name(0)}")
        run_polynomial_regression("cuda:0")
    elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        print("\nFound Apple Metal Performance Shaders (MPS)")
        run_polynomial_regression("mps")
    else:
        print("\nNo accelerated device (CUDA/MPS) found. Skipping accelerated run.")


if __name__ == "__main__":
    main()
