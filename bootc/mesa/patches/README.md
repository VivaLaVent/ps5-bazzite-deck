# RADV patches

Applied in order on Mesa 26.2.6 (`pins.env`, the `mesa-26.2.6` tag of a GitHub mirror of gitlab.freedesktop.org/mesa/mesa):

- `0001` to `0003`: Terra's Mesa patches, as in Bazzite's `mesa-vulkan-drivers` (OpenGamingCollective/mesa, tag 26.2.6)
- `0004`: RADV support for the PS5 Pro's int8 matrix instructions and its compute queue, Borchev/mesa_viola_support @ 7da6e50 (MIT)
- `0005`: the compute queue on the base PS5 and Slim too, after DryhoppedIPA's BC-250 finding (bc250-gfx1013-fix)

When Bazzite's Mesa moves to a new version, move `pins.env` and these patches with it.

## DirectMesh, the second driver

`build-radv.sh` also builds [DirectMesh](https://github.com/lonewolf0622/Mesh-Shaders-for-Rdna-1-) (MIT, as Mesa), which adds
`VK_EXT_mesh_shader` to RADV on GFX1013, the chip family of the BC-250 and of the original PS5 and Slim. It is built from
its own tree at the commit in `pins.env` (Mesa 26.2.1 with its changes), with `0001` to `0003` and `../directmesh/`, and
installed beside the system driver in `/usr/lib64/directmesh/`. `ps5-directmesh %command%` selects it for one game.

- **Not merged into the system driver:** its patch doesn't apply to 26.2.6 (seven files conflict), and it changes how
  every GFX1013 draw is submitted and where buffers go, with or without Mesh shaders.
- **v1.4, not the newest:** v1.4.1 is withdrawn upstream for GPU hangs on a BC-250. Move the pin only to a version its
  author's installer uses.
- `0004` isn't applied (PS5 Pro only, a chip DirectMesh doesn't cover), nor `0005` (DirectMesh opens the compute queue itself).
- Its source asks for a kernel with the GFX1013 PASID TLB invalidation (ours: `patches/ps5-gpu.patch`) and "compute GFXOFF
  fixes" made for the BC-250; whether the PS5 needs the latter is not known.
