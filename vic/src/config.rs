use crate::add_paths::{AddPath, FsInit};
use crate::utils::random_tmp_dir;
use crate::{cli::Args, errors::Errcode};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Clone, Serialize, Deserialize)]
pub struct ContainerOpts {
    // TODO    Do not use the username, get the username from UID
    pub username: String,
    pub hostname: String,
    pub root_mount_point: PathBuf,
    pub addpaths: Vec<AddPath>,
    pub fs_init: FsInit,

    // Got from args
    #[serde(skip)]
    pub script: PathBuf,
    #[serde(skip)]
    pub uid_gid: (u32, u32),

    // Generated config
    #[serde(skip)]
    pub new_root: PathBuf,
}

impl ContainerOpts {
    pub fn from_file(f: &std::path::PathBuf) -> Result<ContainerOpts, Errcode> {
        serde_json::from_str(
            std::fs::read_to_string(f)
                .map_err(|e| Errcode::LoadConfigFile(format!("IO error {e:?}")))?
                .as_str(),
        )
        .map_err(|e| Errcode::LoadConfigFile(format!("Json load error {e:?}")))
    }

    pub fn prepare_and_validate(&mut self, args: &Args) -> Result<(), Errcode> {
        if !self.root_mount_point.exists() || !self.root_mount_point.is_dir() {
            std::fs::create_dir_all(&self.root_mount_point).unwrap();
        }
        self.root_mount_point = self.root_mount_point.canonicalize().unwrap();

        for p in self.addpaths.iter() {
            if !p.src.exists() {
                log::error!("AddPath {p:?} doesn't exist");
                return Err(Errcode::InvalidConfig("addpath doesn't exist"));
            }
        }

        self.uid_gid = (args.uid, args.gid);

        if !args.script.exists() {
            return Err(Errcode::InvalidConfig("script doesn't exist"));
        }
        self.script = args.script.canonicalize().unwrap();

        self.new_root = random_tmp_dir();
        Ok(())
    }
}
