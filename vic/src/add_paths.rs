use crate::{errors::Errcode, mounts::{create_directory, mount_directory, create_symlink, unmount_path}};
use nix::mount::MsFlags;
use serde::{Serialize, Deserialize};
use std::path::PathBuf;

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MountFlag {
    // TODO    Mount flags
    ReadOnly,
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
    pub fn add_to_root(&self, root: &PathBuf) -> Result<(), Errcode> {
        // TODO    Trim the "/" prefix in dst to join
        let dst = if self.dst.starts_with("/") {
            root.join(self.dst.strip_prefix("/").unwrap())
        } else {
            root.join(&self.dst)
        };
        match &self.path_type {
            AddPathType::Mount { flags} => {
                create_directory(&dst)?;
                mount_directory(
                    Some(&self.src),
                    &dst,
                    // TODO    Get flags from MountFlag Vec
                    vec![MsFlags::MS_PRIVATE, MsFlags::MS_BIND],
                )?;
            },
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
            },
            AddPathType::Copy => { std::fs::copy(&self.src, &dst).unwrap(); },
        }
        Ok(())
    }

    // TODO    Clean safely here
    pub fn clean(&self) -> Result<(), Errcode> {
        match &self.path_type {
            AddPathType::Mount { .. } => {
            }
            _ => {},
        }
        Ok(())
    }
}

