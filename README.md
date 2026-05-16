# mkdocs-blog
Blog using mkdocs

## Dependencies:

- pip install mkdocs
- pip install mkdocs-material

## How to run

### Local
```bash
mkdocs serve --livereload
```

### Container (Podman) — any machine, no local Python needed

The repo includes a `Containerfile` and a `run.sh` that work on both **Fedora** and **macOS**.

SSH agent forwarding is used so your private key never enters the container or the image.

**1. Clone the repo**
```bash
git clone git@github.com:you/notes.git
cd notes
```

**2. Build the image (once per machine)**
```bash
podman build -t mkdocs .
```

**3. Load your SSH key on the host**
```bash
ssh-add ~/.ssh/$publicsshkey
```

**4. Run**
```bash
./run.sh
```

MkDocs will be available at `http://localhost:8000`. Files are served from the host directory — edits are reflected live. Git commands (`add`, `commit`, `push`) work inside the container using your host SSH agent.

> **macOS only:** make sure Podman Machine is running before step 4.
> ```bash
> podman machine start
> ```

## References:

- [ICONS/EMOJIS](https://squidfunk.github.io/mkdocs-material/reference/icons-emojis/?h=emo#search)
