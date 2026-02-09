# RAG Test Model (Optional)

This folder contains the non-weight files for the `sentence-transformers/all-MiniLM-L6-v2` test
embedding model.

The model weights (`model.safetensors`) are intentionally **not** tracked in git (or Git LFS) to
keep the open source repository lightweight.

To run the RAG tests that require embeddings, download the weights into this folder:

```sh
bash RAG/Tests/all-MiniLM-L6-v2/download.sh
```

