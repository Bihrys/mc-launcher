pub mod cleanroom;
pub mod fabric;
pub mod forge;
pub mod legacyfabric;
pub mod neoforge;
pub mod optifine;
pub mod quilt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LoaderKind { Fabric, Forge, NeoForge, Quilt, OptiFine, LegacyFabric, Cleanroom }
