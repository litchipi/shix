use crate::errors::Errcode;
use crate::mounts::{create_directory, create_symlink, mount_directory};
use nix::mount::MsFlags;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

const BASE_MNT_FLAGS: [MsFlags; 2] = [MsFlags::MS_PRIVATE, MsFlags::MS_BIND];

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MountFlag {
    ReadOnly,
}

impl Into<MsFlags> for &MountFlag {
    fn into(self) -> MsFlags {
        match self {
            MountFlag::ReadOnly => MsFlags::MS_RDONLY,
        }
    }
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AddPathType {
    Mount { flags: Vec<MountFlag> },
    Symlink,
    SymlinkDirContent { exceptions: Vec<PathBuf> },
    Copy,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct AddPath {
    pub src: PathBuf,
    pub dst: PathBuf,
    #[serde(rename = "type")]
    path_type: AddPathType,
}

impl AddPath {
    pub fn get_root_dst(&self, root: &PathBuf) -> PathBuf {
        if self.dst.starts_with("/") {
            root.join(self.dst.strip_prefix("/").unwrap())
        } else {
            root.join(&self.dst)
        }
    }
    pub fn add_to_root(&self, root: &PathBuf) -> Result<(), Errcode> {
        let dst = self.get_root_dst(root);
        match &self.path_type {
            AddPathType::Mount { flags } => {
                let mut mnt_flags = Vec::from(BASE_MNT_FLAGS);
                for f in flags.iter() {
                    mnt_flags.push(f.into());
                }
                create_directory(&dst)?;
                mount_directory(Some(&self.src), &dst, mnt_flags)?;
            }
            AddPathType::Symlink => create_symlink(&self.src, &self.dst)?,
            AddPathType::SymlinkDirContent { exceptions } => {
                for path in std::fs::read_dir(&self.src).unwrap() {
                    let path = path.unwrap().path();
                    let fname = path.file_name().unwrap();
                    if exceptions.contains(&path) {
                        continue;
                    }
                    let dst = if path.is_symlink() {
                        dst.join(fname)
                    } else {
                        dst.join(path.strip_prefix(&self.src).unwrap())
                    };
                    create_symlink(&path, &dst)?;
                }
            }
            AddPathType::Copy => {
                std::fs::copy(&self.src, &dst).unwrap();
            }
        }
        Ok(())
    }

    pub fn clean(&self, root: &PathBuf) -> Result<(), Errcode> {
        let dst = self.get_root_dst(root);
        match self.path_type {
            AddPathType::Mount { .. } => {
                // remove_empty_dir_tree(&dst)?;
            }
            AddPathType::Symlink => {
                if dst.is_symlink() {
                    std::fs::remove_file(dst).unwrap();
                } else {
                    log::warn!("Unable to clean symlink {dst:?}, skipping ...");
                }
            }
            AddPathType::SymlinkDirContent { .. } => {
                if !dst.is_dir() {
                    log::warn!("Unable to clean symlinked-content dir {dst:?}, skipping ...");
                    return Ok(());
                }
                for path in std::fs::read_dir(&dst).unwrap() {
                    let path = path.unwrap().path();
                    if path.is_symlink() {
                        std::fs::remove_file(path).unwrap();
                    }
                }
            }
            AddPathType::Copy => {
                if !dst.is_file() {
                    log::warn!("Unable to clean copied file {dst:?}, skipping ...");
                } else {
                    std::fs::remove_file(dst).unwrap();
                }
            }
        }
        Ok(())
    }
}
