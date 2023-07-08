use crate::add_paths::AddPath;
use crate::config::ContainerOpts;
use crate::errors::Errcode;

use std::path::PathBuf;

// TODO    Set /host mountpoint as a constant / config var

use std::fs::create_dir_all;
pub fn create_directory(path: &PathBuf) -> Result<(), Errcode> {
    match create_dir_all(path) {
        Err(e) => {
            log::error!("Cannot create directory {}: {}", path.to_str().unwrap(), e);
            Err(Errcode::MountsError(2))
        }
        Ok(_) => Ok(()),
    }
}

pub fn mount_directory(
    path: Option<&PathBuf>,
    mount_point: &PathBuf,
    flags: Vec<MsFlags>,
) -> Result<(), Errcode> {
    let mut ms_flags = MsFlags::empty();
    for f in flags.iter() {
        ms_flags.insert(*f);
    }
    match mount::<PathBuf, PathBuf, PathBuf, PathBuf>(path, mount_point, None, ms_flags, None) {
        Ok(_) => Ok(()),
        Err(e) => {
            if let Some(p) = path {
                log::error!(
                    "Cannot mount {} to {}: {}",
                    p.to_str().unwrap(),
                    mount_point.to_str().unwrap(),
                    e
                );
            } else {
                log::error!("Cannot remount {}: {}", mount_point.to_str().unwrap(), e);
            }
            Err(Errcode::MountsError(3))
        }
    }
}

pub fn create_symlink(src: &PathBuf, dst: &PathBuf) -> Result<(), Errcode> {
    let src: PathBuf = if src.starts_with("/") {
        src.strip_prefix("/").unwrap().into()
    } else {
        src.clone()
    };
    let src = PathBuf::from("/host").join(&src);

    if dst.exists() {
        // TODO    Option to remove if exist
        panic!(
            "Unable to create symlink {dst:?} from {:?}, file exists",
            src
        );
    }
    if let Some(p) = dst.parent() {
        if let Err(e) = std::fs::create_dir_all(p) {
            log::error!("Unable to create parent directory: {e:?}");
            return Err(Errcode::MountsError(6));
        }
    }
    if let Err(e) = nix::unistd::symlinkat(&src, None, dst) {
        log::error!("Unable to create symlink: {e:?}");
        return Err(Errcode::MountsError(7));
    }
    Ok(())
}

use nix::mount::{mount, MsFlags};
use nix::unistd::{chdir, pivot_root};
pub fn setmountpoint(config: &ContainerOpts) -> Result<(), Errcode> {
    log::debug!("Setting mount points ...");
    mount_directory(
        None,
        &PathBuf::from("/"),
        vec![MsFlags::MS_REC, MsFlags::MS_PRIVATE],
    )?;

    log::debug!(
        "Mounting root mount point {:?} to new root {:?}",
        config.root_mount_point,
        config.new_root
    );
    create_directory(&config.new_root)?;
    create_directory(&config.root_mount_point)?;
    mount_directory(
        Some(&config.root_mount_point),
        &config.new_root,
        vec![MsFlags::MS_BIND, MsFlags::MS_PRIVATE],
    )?;

    create_directory(&config.new_root.join("home").join(&config.username))?;
    mount_directory(
        Some(&config.home_dir),
        &config.new_root.join("home").join(&config.username),
        vec![MsFlags::MS_BIND],
    )?;

    log::debug!("Mounting additionnal paths");
    for p in config.addpaths.iter() {
        p.add_to_root(&config.new_root)?;
    }

    let put_old = config.new_root.join("host");
    create_directory(&put_old)?;

    log::debug!(
        "Pivoting root to {:?}, putting old root in {put_old:?}",
        config.new_root
    );
    if let Err(e) = pivot_root(&config.new_root, &put_old) {
        log::error!("Error while pivoting root: {e:?}");
        return Err(Errcode::MountsError(4));
    }

    log::debug!("Unmounting old root");
    if chdir(&PathBuf::from("/")).is_err() {
        return Err(Errcode::MountsError(5));
    }
    Ok(())
}
