## Voxy VR Backport Feasibility Notes

Source issue: https://github.com/MCRcortex/voxy/issues/519
Related duplicate/history: https://github.com/MCRcortex/voxy/issues/375
Repo: https://github.com/MCRcortex/voxy

### Observed current dev branch facts

- Default branch: `dev`.
- Current `gradle.properties` targets `minecraft_version=26.1.2`.
- Fabric loader target is `loader_version=0.18.6`.
- Loom target is `loom_version=1.15-SNAPSHOT`.
- Fabric API target is `fabric_api_version=0.148.0+26.1.2`.
- Current dependency surface includes Sodium, Iris, Lithium, Vivecraft, Flashback, Chunky, and optional Nvidium entries.
- Current Vivecraft entry is `vivecraft_version=26.1.1-1.3.7-b2-fabric`.
- Shader sources include GLSL 330, 450, and 460 paths.

### Why this should be a feasibility sprint first

The buyer asks for a 1.20.1 Fabric/Forge path that works with Vivecraft, shaders, and distant LODs. The public repo currently targets a newer Fabric stack, includes VR render-pass logic, and has shader/GPU code paths that are likely version-sensitive. A direct "promise a full backport" offer would be too broad and risky without maintainer acceptance and a reproducible test matrix.

### Diagnostic deliverable

1. Version matrix: current dev target versus requested 1.20.1 target.
2. Dependency matrix: Fabric loader, Loom, Fabric API, Sodium, Iris, Vivecraft, and shader requirements.
3. Backport blockers: Minecraft API changes, Fabric loader/API changes, Sodium/Iris compatibility, VR render pass behavior, shader version/GPU assumptions, and Forge feasibility.
4. First local test plan: build-only, launch-only, flat-screen render, VR no-shader render, VR shader render, and performance capture.
5. Recommended milestone plan: diagnostic, Fabric-only prototype, VR render validation, shader validation, packaging, and optional Forge research.

### Non-goals

- No private modpack files.
- No paid mod jars.
- No account credentials.
- No guaranteed upstream merge.
- No claim that a working 1.20.1 build exists before paid diagnostic work and buyer-provided acceptance details.
