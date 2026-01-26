Collecting workspace information# Implementation Differences Between QwenAdapter, QwenOFT, and QwenGR00T

Based on the code analysis, here are the key architectural and implementation differences:

## 1. **QwenAdapter** (QwenAdapter.py)

### Core Approach: **Learnable Action Query Tokens + Multi-layer Adapter**

**Key Components:**
- **Action Query Mechanism**: Uses learnable `action_query` parameters (default 64 tokens) that are injected into the VLM embeddings via a forward hook
- **Multi-layer Feature Extraction**: Extracts hidden states from ALL layers of Qwen-VL, concatenates vision tokens + action query tokens across layers
- **Action Head**: Uses `L1RegressionActionHead` with cross-attention and self-attention mechanisms
- **Proprioception Support**: Optional proprio projector to incorporate robot state

**Forward Flow:**
```python
# 1. Inject learnable action queries at the end of input sequence
qwen_inputs['input_ids'] += dummy_ids  # Append placeholder tokens
# Hook replaces dummy embeddings with learnable queries

# 2. Extract multi-layer features [B, num_layers, L_total, D]
for layer in qwenvl_outputs.hidden_states:
    concat([vision_tokens, action_query_tokens])

# 3. Predict actions via adapter head
predicted_actions = action_model(multi_layer_hidden_states, proprio)
```

**Loss**: Direct L1 loss on predicted vs. ground truth actions

---

## 2. **QwenOFT** (QwenOFT.py)

### Core Approach: **Special Token Insertion + Single-layer MLP**

**Key Components:**
- **Action Token Insertion**: Appends special emoji token `🔍` repeated `chunk_len` times to the instruction text
- **Single-layer Feature**: Uses only the LAST hidden layer from Qwen-VL (`hidden_states[-1]`)
- **Token Gathering**: Vectorized extraction of action token embeddings using `_gather_action_token_embeddings`
- **Action Head**: Simple MLP-based `get_action_model` (not flow-matching)

**Forward Flow:**
```python
# 1. Modify instruction with action tokens
instruction += f" Please predict the next {chunk_len} robot actions: <action>🔍🔍🔍...<action>."

# 2. Forward through Qwen-VL
qwenvl_outputs = qwen_vl_interface(qwen_inputs)
last_hidden = qwenvl_outputs.hidden_states[-1]  # [B, L, H]

# 3. Gather embeddings corresponding to action tokens
action_queries = _gather_action_token_embeddings(last_hidden, input_ids, action_token_id)

# 4. Direct regression
pred_actions = action_model.predict_action(action_queries)
```

**Loss**: L1 loss on the last `chunk_len` actions

**Note**: Requires pre-adding special tokens to the VLM vocabulary (see `add_qwen_special_tokens`)

---

## 3. **QwenGR00T** (QwenGR00T.py)

### Core Approach: **Flow-Matching Diffusion Head**

**Key Components:**
- **Last-layer Features**: Uses only the final hidden layer like QwenOFT
- **Flow-Matching Head**: Uses `FlowmatchingActionHead` with DiT architecture (inspired by GR00T N1.5)
- **Repeated Diffusion Steps**: Repeats inputs `repeated_diffusion_steps` times for efficient training (default 4x)
- **State Support**: Can incorporate robot proprioceptive state

**Forward Flow:**
```python
# 1. Extract last layer features
qwenvl_outputs = qwen_vl_interface(qwen_inputs)
last_hidden = qwenvl_outputs.hidden_states[-1]  # [B, L, H]

# 2. Repeat for efficient diffusion training
repeated_diffusion_steps = 4
last_hidden_repeated = last_hidden.repeat(repeated_diffusion_steps, 1, 1)
actions_target_repeated = actions_target.repeat(repeated_diffusion_steps, 1, 1)

# 3. Flow-matching loss (not direct regression)
action_loss = action_model(last_hidden_repeated, actions_target_repeated, state)
```

**Loss**: Flow-matching loss (continuous normalizing flow between noise and action distributions)

**Prediction**: Uses iterative sampling/ODE solving (not direct forward pass)

---

## Summary Comparison Table

| Aspect | QwenAdapter | QwenOFT | QwenGR00T |
|--------|-------------|---------|-----------|
| **Feature Source** | All layers (multi-layer) | Last layer only | Last layer only |
| **Action Representation** | Learnable query tokens | Special text tokens | Hidden states directly |
| **Action Head** | Cross-attention adapter | Simple MLP | DiT + Flow-matching |
| **VLM Modification** | None (hook injection) | Requires special tokens | None |
| **Loss Type** | L1 regression | L1 regression | Flow-matching loss |
| **Inference** | Single forward pass | Single forward pass | Iterative sampling |
| **Proprioception** | Optional projector | Not implemented | Optional concat |
| **Computational Cost** | Highest (all layers) | Lowest | Medium (diffusion steps) |
| **Best Use Case** | Max expressiveness | Fast inference | High quality actions |

---

## Architectural Inspirations

- **QwenAdapter**: Based on [VLA-Adapter](https://github.com/zcczhang/VLA-Adapter) architecture
- **QwenOFT**: Inspired by [OpenVLA-OFT](https://openvla.github.io/) (Output Feature Tuning)
- **QwenGR00T**: Adopts [GR00T N1.5](https://github.com/NVIDIA/GR00T) flow-matching approach with DiT backbone

Each framework trades off between **computational efficiency**, **action quality**, and **implementation complexity** for different robotics deployment scenarios.