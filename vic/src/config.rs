use crate::errors::Errcode;
use crate::add_paths::AddPath;
use serde::{Serialize, Deserialize};
use std::path::PathBuf;

#[derive(Clone, Serialize, Deserialize)]
pub struct ContainerOpts {
    #[serde(skip)]
    pub script: PathBuf,
    pub hostname: String,
    pub mount_dir: PathBuf,

    //    TODO    Pass a struct with complementary options
    //    TODO    If destination path got a starting "/", remove it
    pub addpaths: Vec<AddPath>,
}

impl ContainerOpts {
    pub fn from_file(f: &std::path::PathBuf) -> Result<ContainerOpts, Errcode> {
        Ok(serde_json::from_str(std::fs::read_to_string(f).map_err(|e| Errcode::LoadConfigFile(format!("IO error {e:?}")))?.as_str()).map_err(|e| Errcode::LoadConfigFile(format!("Json load error {e:?}")))?)
    }

    pub fn validate(&self) -> Result<(), Errcode> {
        if !self.mount_dir.exists() || !self.mount_dir.is_dir() {
            return Err(Errcode::InvalidConfig("mount dir doesn't exist"));
        }

        for p in self.addpaths.iter() {
            if !p.src.exists() {
                return Err(Errcode::InvalidConfig("addpath doesn't exist"));
            }
        }

        if !self.script.exists() {
            return Err(Errcode::InvalidConfig("script doesn't exist"));
        }

        Ok(())
    }
}
