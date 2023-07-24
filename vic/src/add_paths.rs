use crate::errors::Errcode;
use crate::mounts::{create_directory, create_symlink, mount_directory};
use nix::mount::MsFlags;
use serde::{Deserialize, Serialize};
use std::os::unix::prelude::PermissionsExt;
use std::path::{Path, PathBuf};

const BASE_MNT_FLAGS: [MsFlags; 3] = [MsFlags::MS_PRIVATE, MsFlags::MS_BIND, MsFlags::MS_REC];

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FsInitType {
    Directory,
    File { content: String },
}

pub type FsInit = std::collections::HashMap<PathBuf, FsInitEntry>;

#[derive(Clone, Serialize, Deserialize)]
pub struct FsInitEntry {
    #[serde(rename = "type")]
    fs_init_type: FsInitType,
    perm: u32,
}

impl FsInitEntry {
    pub fn create(&self, root: &Path, dst: &PathBuf) -> Result<(), Errcode> {
        let dst = if dst.starts_with("/") {
            root.join(dst.strip_prefix("/").unwrap())
        } else {
            root.join(dst)
        };
        match &self.fs_init_type {
            FsInitType::Directory => std::fs::create_dir_all(&dst).unwrap(),
            FsInitType::File { content } => {
                if let Some(p) = dst.parent() {
                    std::fs::create_dir_all(p).unwrap();
                }
                std::fs::write(&dst, content).unwrap();
            }
        }
        let mode = u32::from_str_radix(format!("{}", self.perm).as_str(), 8).unwrap();
        std::fs::set_permissions(&dst, std::fs::Permissions::from_mode(mode)).unwrap();
        log::debug!(
            "Created FS entry {dst:?} with permission {:?}",
            std::fs::Permissions::from_mode(mode)
        );
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MountFlag {
    ReadOnly,
}

impl From<&MountFlag> for MsFlags {
    fn from(val: &MountFlag) -> Self {
        match val {
            MountFlag::ReadOnly => MsFlags::MS_RDONLY,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AddPathType {
    Mount {
        flags: Vec<MountFlag>,
        mount_type: Option<String>,
    },
    Symlink,
    SymlinkDirContent {
        exceptions: Vec<PathBuf>,
    },
    Copy,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddPath {
    pub src: PathBuf,
    pub dst: PathBuf,
    #[serde(rename = "type")]
    path_type: AddPathType,
}

impl AddPath {
    pub fn get_root_dst(&self, root: &Path) -> PathBuf {
        if self.dst.starts_with("/") {
            root.join(self.dst.strip_prefix("/").unwrap())
        } else {
            root.join(&self.dst)
        }
    }
    pub fn add_to_root(&self, root: &Path) -> Result<(), Errcode> {
        let dst = self.get_root_dst(root);
        match &self.path_type {
            AddPathType::Mount { flags, mount_type } => {
                let mut mnt_flags = Vec::from(BASE_MNT_FLAGS);
                for f in flags.iter() {
                    mnt_flags.push(f.into());
                }
                create_directory(&dst)?;
                mount_directory(Some(&self.src), &dst, mount_type, mnt_flags)?;
            }
            AddPathType::Symlink => {
                log::debug!("{:?} {:?} {:?}", self.src, self.dst, dst);
                if let Err(e) = create_symlink(&self.src, &dst) {
                    log::error!("Error creating symlink {:?} -> {dst:?}: {e:?}", self.src);
                }
            }
            AddPathType::SymlinkDirContent { exceptions } => {
                for path in std::fs::read_dir(&self.src).unwrap() {
                    let path = path.unwrap().path();
                    let fname = path.file_name().unwrap();
                    if exceptions.contains(&path) || exceptions.contains(&PathBuf::from(fname)) {
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
                if !dst.exists() {
                    std::fs::copy(&self.src, &dst).unwrap();
                } else {
                    log::info!("{dst:?} file exists, won't erase with a copy from host");
                }
            }
        }
        Ok(())
    }

    pub fn clean(&self, root: &Path) -> Result<(), Errcode> {
        let dst = self.get_root_dst(root);
        match self.path_type {
            AddPathType::Symlink => {
                if dst.is_symlink() {
                    std::fs::remove_file(dst).unwrap();
                } else {
                    log::warn!("Unable to clean symlink {dst:?}, skipping ...");
                }
            }
            AddPathType::SymlinkDirContent { .. } => {
                if !dst.is_dir() {
                    log::warn!("Unable to clean symlinked-content, {dst:?} is not a directory");
                    return Ok(());
                }
                for path in std::fs::read_dir(&dst).unwrap() {
                    let path = path.unwrap().path();
                    if path.is_symlink() {
                        std::fs::remove_file(path).unwrap();
                    }
                }
            }
            _ => {}
        }
        Ok(())
    }
}
