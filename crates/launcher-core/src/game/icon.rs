#[derive(Debug, Clone, PartialEq, Eq)]
pub enum VersionIcon {
    Grass, Forge, Fabric, Quilt, NeoForge, OptiFine, LegacyFabric, Cleanroom, Command, CraftTable, AprilFools, Chest, Furnace, Chicken, Terracotta,
}

impl VersionIcon {
    pub fn as_hmcl_name(&self) -> &'static str {
        match self {
            VersionIcon::Grass => "grass",
            VersionIcon::Forge => "forge",
            VersionIcon::Fabric => "fabric",
            VersionIcon::Quilt => "quilt",
            VersionIcon::NeoForge => "neoforge",
            VersionIcon::OptiFine => "optifine",
            VersionIcon::LegacyFabric => "legacyfabric",
            VersionIcon::Cleanroom => "cleanroom",
            VersionIcon::Command => "command",
            VersionIcon::CraftTable => "craft_table",
            VersionIcon::AprilFools => "april_fools",
            VersionIcon::Chest => "chest",
            VersionIcon::Furnace => "furnace",
            VersionIcon::Chicken => "chicken",
            VersionIcon::Terracotta => "terracotta",
        }
    }
}

pub fn icon_name_from_loader_text(value: &str) -> &'static str {
    let lower = value.to_ascii_lowercase();
    if lower.contains("neoforge") { "neoforge" }
    else if lower.contains("legacyfabric") { "legacyfabric" }
    else if lower.contains("fabric") { "fabric" }
    else if lower.contains("quilt") { "quilt" }
    else if lower.contains("cleanroom") { "cleanroom" }
    else if lower.contains("forge") { "forge" }
    else if lower.contains("optifine") { "optifine" }
    else { "grass" }
}
