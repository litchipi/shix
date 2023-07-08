use crate::utils::random_tmp_dir;
use crate::{errors::Errcode, cli::Args};
use crate::add_paths::AddPath;
use serde::{Serialize, Deserialize};
use std::path::PathBuf;

#[derive(Clone, Serialize, Deserialize)]
pub struct ContainerOpts {
    #[serde(skip)]
    pub script: PathBuf,
    pub hostname: String,
    pub home_dir: PathBuf,

    //    TODO    Pass a struct with complementary options
    //    TODO    If destination path got a starting "/", remove it
    pub addpaths: Vec<AddPath>,

    // Generated config
    #[serde(skip)]
    pub new_root:  PathBuf,
    #[serde(skip)]
    pub root_mount_point: PathBuf,

}

impl ContainerOpts {
    pub fn from_file(f: &std::path::PathBuf) -> Result<ContainerOpts, Errcode> {
        Ok(serde_json::from_str(std::fs::read_to_string(f).map_err(|e| Errcode::LoadConfigFile(format!("IO error {e:?}")))?.as_str()).map_err(|e| Errcode::LoadConfigFile(format!("Json load error {e:?}")))?)
    }

    pub fn prepare_and_validate(&mut self, args: &Args) -> Result<(), Errcode> {
        if !self.home_dir.exists() || !self.home_dir.is_dir() {
            return Err(Errcode::InvalidConfig("mount dir doesn't exist"));
        }
        self.home_dir = self.home_dir.canonicalize().unwrap();

        for p in self.addpaths.iter() {
            if !p.src.exists() {
                return Err(Errcode::InvalidConfig("addpath doesn't exist"));
            }
        }

        if !args.script.exists() {
            return Err(Errcode::InvalidConfig("script doesn't exist"));
        }
        self.script = args.script.canonicalize().unwrap();

        self.new_root = random_tmp_dir();
        self.root_mount_point = random_tmp_dir();
        Ok(())
    }
}
