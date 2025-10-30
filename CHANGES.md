CHANGES
=======

2025-10-30 - TP-Link onboarding and model handling
-------------------------------------------------
- Added documentation files:
  - docs/AGREGAR_TPLINK.md
  - docs/AGREGAR_TPLINK_VARIANTES.md
- Added local model for TP-Link to prevent gem overwrites:
  - models/tplink.rb (copied from the modified gem file)
- Updated Oxidized runtime config to use local models directory:
  - `models_dir: /root/Proxmox/Oxidized-Backup/models` added to `/var/lib/oxidized/.config/oxidized/config` (runtime)
- Rationale: avoid manual edits inside gem and keep custom models versioned in the repo.

Notes:
- If the Oxidized gem is updated, the gem's `tplink.rb` may change; keep `models/tplink.rb` in this repo as the authoritative customized model.
- To revert to gem model, remove or rename `models/tplink.rb` and restart Oxidized.
